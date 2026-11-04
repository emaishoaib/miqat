import base64
import io
import json
import struct
from pathlib import Path

import pytest
from claude_reader import TimetableError
from miqat_host import Dependencies, main, read_message, write_message
from miqat_server import UploadError

PAGE_URL = "https://masjid.example/times"
SCREENSHOT = b"\x89PNG screenshot"
PDF = b"%PDF-1.7 timetable"
JPEG = b"\xff\xd8 timetable"
TIMETABLE = {
    "days": [
        {
            "date": "2026-11-01",
            "times": {
                "fajr": {"begins": "05:52", "jamaat": "06:30"},
                "dhuhr": {"begins": "12:49"},
                "asr": {"begins": "15:14"},
                "maghrib": {"begins": "17:50"},
                "isha": {"begins": "19:21"},
            },
        }
    ],
    "problems": [],
}


def framed(message: dict) -> bytes:
    body = json.dumps(message).encode()
    return struct.pack("=I", len(body)) + body


def fake_web(files: dict[str, tuple[bytes, str]]):
    def fetch(url: str) -> tuple[bytes, str]:
        if url not in files:
            raise OSError(f"404 for {url}")
        return files[url]

    return fetch


NO_WEB = fake_web({})


def reads_nothing(folder: Path, rejections: list) -> dict:
    raise AssertionError("Claude shouldn't be asked")


def uploads_nothing(place_id: str, days: list) -> dict:
    raise AssertionError("The server shouldn't be asked")


@pytest.fixture
def captures(tmp_path) -> Path:
    return tmp_path / "captures"


def replies_to(
    *messages: dict,
    captures: Path,
    fetch=NO_WEB,
    read_timetable=reads_nothing,
    upload=uploads_nothing,
) -> list[dict]:
    stdin = io.BytesIO(b"".join(framed(message) for message in messages))
    stdout = io.BytesIO()
    dependencies = Dependencies(
        fetch=fetch, read_timetable=read_timetable, upload=upload, captures=captures
    )
    main(stdin, stdout, dependencies)
    stdout.seek(0)
    replies = []
    while (reply := read_message(stdout)) is not None:
        replies.append(reply)
    return replies


def capture(pdfs: list[str] = (), images: list[str] = ()) -> dict:
    return {
        "type": "capture",
        "placeId": "ChIJ123abc",
        "capture": {
            "url": PAGE_URL,
            "title": "Prayer times",
            "text": "Fajr 05:30",
            "screenshot": "data:image/png;base64,"
            + base64.b64encode(SCREENSHOT).decode(),
            "pdfs": [{"url": url, "label": "Timetable"} for url in pdfs],
            "images": list(images),
        },
    }


def test_answers_a_ping_with_a_pong(captures):
    assert replies_to({"type": "ping"}, captures=captures) == [{"type": "pong"}]


def test_answers_every_message_until_chrome_closes_the_input(captures):
    assert replies_to({"type": "ping"}, {"type": "ping"}, captures=captures) == [
        {"type": "pong"},
        {"type": "pong"},
    ]


def test_reports_a_message_type_it_does_not_know(captures):
    assert replies_to({"type": "dance"}, captures=captures) == [
        {"type": "error", "error": "Unknown message type 'dance'."}
    ]


def test_writes_the_length_before_the_message():
    stdout = io.BytesIO()

    write_message(stdout, {"type": "pong"})

    assert stdout.getvalue() == framed({"type": "pong"})


def test_saves_the_page_text_and_screenshot_in_a_new_folder(captures):
    [reply] = replies_to(capture(), captures=captures)

    folder = Path(reply["folder"])
    assert folder.parent == captures
    assert reply == {
        "type": "captured",
        "id": folder.name,
        "folder": str(folder),
        "files": ["page.txt", "screenshot.png"],
        "failed": [],
    }
    assert (folder / "page.txt").read_text() == "Fajr 05:30"
    assert (folder / "screenshot.png").read_bytes() == SCREENSHOT


def test_downloads_the_linked_pdfs_and_large_images(captures):
    web = fake_web(
        {
            "https://masjid.example/november.pdf": (PDF, "application/pdf"),
            "https://masjid.example/november.jpg": (JPEG, "image/jpeg"),
        }
    )

    [reply] = replies_to(
        capture(
            pdfs=["https://masjid.example/november.pdf"],
            images=["https://masjid.example/november.jpg"],
        ),
        captures=captures,
        fetch=web,
    )

    folder = Path(reply["folder"])
    assert reply["files"] == ["page.txt", "screenshot.png", "pdf-1.pdf", "image-1.jpg"]
    assert (folder / "pdf-1.pdf").read_bytes() == PDF
    assert (folder / "image-1.jpg").read_bytes() == JPEG


def test_records_where_each_file_came_from(captures):
    web = fake_web({"https://masjid.example/november.pdf": (PDF, "application/pdf")})

    [reply] = replies_to(
        capture(pdfs=["https://masjid.example/november.pdf"]),
        captures=captures,
        fetch=web,
    )

    assert json.loads((Path(reply["folder"]) / "capture.json").read_text()) == {
        "place_id": "ChIJ123abc",
        "url": PAGE_URL,
        "title": "Prayer times",
        "sources": {
            "page.txt": PAGE_URL,
            "screenshot.png": PAGE_URL,
            "pdf-1.pdf": "https://masjid.example/november.pdf",
        },
    }


def test_reports_downloads_that_fail_or_are_not_what_they_claim(captures):
    web = fake_web({"https://masjid.example/fake.pdf": (b"<html>", "text/html")})

    [reply] = replies_to(
        capture(
            pdfs=[
                "https://masjid.example/missing.pdf",
                "https://masjid.example/fake.pdf",
            ],
            images=["https://masjid.example/missing.png"],
        ),
        captures=captures,
        fetch=web,
    )

    assert reply["files"] == ["page.txt", "screenshot.png"]
    assert reply["failed"] == [
        "https://masjid.example/missing.pdf",
        "https://masjid.example/fake.pdf",
        "https://masjid.example/missing.png",
    ]


def test_skips_addresses_that_are_not_on_the_web(captures):
    [reply] = replies_to(
        capture(images=["data:image/png;base64,AAAA"]), captures=captures
    )

    assert reply["files"] == ["page.txt", "screenshot.png"]
    assert reply["failed"] == []


def test_reports_an_incomplete_capture(captures):
    [reply] = replies_to(
        {"type": "capture", "placeId": "ChIJ123abc", "capture": {}}, captures=captures
    )

    assert reply == {"type": "error", "error": "The capture was incomplete: 'text'."}


def test_reads_the_timetable_from_a_capture(captures):
    folders = []

    def read_timetable(folder: Path, rejections: list) -> dict:
        folders.append(folder)
        return TIMETABLE

    [captured] = replies_to(capture(), captures=captures)
    [reply] = replies_to(
        {"type": "read", "captureId": captured["id"]},
        captures=captures,
        read_timetable=read_timetable,
    )

    assert reply == {
        "type": "timetable",
        "source": {"placeId": "ChIJ123abc", "url": PAGE_URL, "title": "Prayer times"},
        **TIMETABLE,
    }
    assert folders == [Path(captured["folder"]).resolve()]


def test_reports_when_claude_cannot_read_the_timetable(captures):
    def read_timetable(folder: Path, rejections: list) -> dict:
        raise TimetableError("Claude took longer than 300 seconds.")

    [captured] = replies_to(capture(), captures=captures)
    [reply] = replies_to(
        {"type": "read", "captureId": captured["id"]},
        captures=captures,
        read_timetable=read_timetable,
    )

    assert reply == {"type": "error", "error": "Claude took longer than 300 seconds."}


@pytest.mark.parametrize("capture_id", ["", ".", "..", "../elsewhere", "missing"])
def test_reads_only_folders_it_captured(captures, capture_id):
    replies_to(capture(), captures=captures)

    [reply] = replies_to({"type": "read", "captureId": capture_id}, captures=captures)

    assert reply == {"type": "error", "error": f"There is no capture {capture_id!r}."}


def test_uploads_the_days_for_the_captured_mosque(captures):
    uploads = []

    def upload(place_id: str, days: list) -> dict:
        uploads.append((place_id, days))
        return {"type": "uploaded", "daysSaved": len(days)}

    [captured] = replies_to(capture(), captures=captures)
    [reply] = replies_to(
        {"type": "upload", "captureId": captured["id"], "days": TIMETABLE["days"]},
        captures=captures,
        upload=upload,
    )

    assert reply == {"type": "uploaded", "daysSaved": 1}
    assert uploads == [("ChIJ123abc", TIMETABLE["days"])]


def test_removes_the_capture_once_its_days_are_uploaded(captures):
    [captured] = replies_to(capture(), captures=captures)

    replies_to(
        {"type": "upload", "captureId": captured["id"], "days": []},
        captures=captures,
        upload=lambda place_id, days: {"type": "uploaded", "daysSaved": 0},
    )

    assert not Path(captured["folder"]).exists()


def test_keeps_the_capture_when_the_server_rejects_the_days(captures):
    rejection = {"type": "rejected", "problems": ["2026-11-02 is missing."]}

    [captured] = replies_to(capture(), captures=captures)
    [reply] = replies_to(
        {"type": "upload", "captureId": captured["id"], "days": []},
        captures=captures,
        upload=lambda place_id, days: rejection,
    )

    assert reply == rejection
    assert Path(captured["folder"]).exists()


def test_reports_when_the_upload_cannot_be_sent(captures):
    def upload(place_id: str, days: list) -> dict:
        raise UploadError("Couldn't find the gcloud command.")

    [captured] = replies_to(capture(), captures=captures)
    [reply] = replies_to(
        {"type": "upload", "captureId": captured["id"], "days": []},
        captures=captures,
        upload=upload,
    )

    assert reply == {"type": "error", "error": "Couldn't find the gcloud command."}


def test_uploads_only_folders_it_captured(captures):
    [reply] = replies_to(
        {"type": "upload", "captureId": "..", "days": []}, captures=captures
    )

    assert reply == {"type": "error", "error": "There is no capture '..'."}


def test_keeps_claudes_answer_with_the_capture(captures):
    [captured] = replies_to(capture(), captures=captures)

    replies_to(
        {"type": "read", "captureId": captured["id"]},
        captures=captures,
        read_timetable=lambda folder, rejections: TIMETABLE,
    )

    answer = Path(captured["folder"]) / "answer.json"
    assert json.loads(answer.read_text()) == TIMETABLE


def test_passes_the_server_rejection_on_to_claude(captures):
    asked = []

    def read_timetable(folder: Path, rejections: list) -> dict:
        asked.append(rejections)
        return TIMETABLE

    [captured] = replies_to(capture(), captures=captures)
    replies_to(
        {
            "type": "read",
            "captureId": captured["id"],
            "rejections": ["Days are missing between 2026-11-01 and 2026-11-03."],
        },
        captures=captures,
        read_timetable=read_timetable,
    )

    assert asked == [["Days are missing between 2026-11-01 and 2026-11-03."]]
