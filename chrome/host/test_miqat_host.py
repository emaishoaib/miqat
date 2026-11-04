import base64
import io
import json
import struct
from pathlib import Path

from miqat_host import main, read_message, write_message

PAGE_URL = "https://masjid.example/times"
SCREENSHOT = b"\x89PNG screenshot"
PDF = b"%PDF-1.7 timetable"
JPEG = b"\xff\xd8 timetable"


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


def replies_to(*messages: dict, fetch=NO_WEB, folder: Path | None = None) -> list[dict]:
    stdin = io.BytesIO(b"".join(framed(message) for message in messages))
    stdout = io.BytesIO()
    main(stdin, stdout, fetch=fetch, new_folder=lambda: folder)
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


def test_answers_a_ping_with_a_pong():
    assert replies_to({"type": "ping"}) == [{"type": "pong"}]


def test_answers_every_message_until_chrome_closes_the_input():
    assert replies_to({"type": "ping"}, {"type": "ping"}) == [
        {"type": "pong"},
        {"type": "pong"},
    ]


def test_reports_a_message_type_it_does_not_know():
    assert replies_to({"type": "dance"}) == [
        {"type": "error", "error": "Unknown message type 'dance'."}
    ]


def test_writes_the_length_before_the_message():
    stdout = io.BytesIO()

    write_message(stdout, {"type": "pong"})

    assert stdout.getvalue() == framed({"type": "pong"})


def test_saves_the_page_text_and_screenshot(tmp_path):
    [reply] = replies_to(capture(), folder=tmp_path)

    assert reply == {
        "type": "captured",
        "folder": str(tmp_path),
        "files": ["page.txt", "screenshot.png"],
        "failed": [],
    }
    assert (tmp_path / "page.txt").read_text() == "Fajr 05:30"
    assert (tmp_path / "screenshot.png").read_bytes() == SCREENSHOT


def test_downloads_the_linked_pdfs_and_large_images(tmp_path):
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
        fetch=web,
        folder=tmp_path,
    )

    assert reply["files"] == ["page.txt", "screenshot.png", "pdf-1.pdf", "image-1.jpg"]
    assert (tmp_path / "pdf-1.pdf").read_bytes() == PDF
    assert (tmp_path / "image-1.jpg").read_bytes() == JPEG


def test_records_where_each_file_came_from(tmp_path):
    web = fake_web({"https://masjid.example/november.pdf": (PDF, "application/pdf")})

    replies_to(
        capture(pdfs=["https://masjid.example/november.pdf"]),
        fetch=web,
        folder=tmp_path,
    )

    assert json.loads((tmp_path / "capture.json").read_text()) == {
        "place_id": "ChIJ123abc",
        "url": PAGE_URL,
        "title": "Prayer times",
        "sources": {
            "page.txt": PAGE_URL,
            "screenshot.png": PAGE_URL,
            "pdf-1.pdf": "https://masjid.example/november.pdf",
        },
    }


def test_reports_downloads_that_fail_or_are_not_what_they_claim(tmp_path):
    web = fake_web({"https://masjid.example/fake.pdf": (b"<html>", "text/html")})

    [reply] = replies_to(
        capture(
            pdfs=[
                "https://masjid.example/missing.pdf",
                "https://masjid.example/fake.pdf",
            ],
            images=["https://masjid.example/missing.png"],
        ),
        fetch=web,
        folder=tmp_path,
    )

    assert reply["files"] == ["page.txt", "screenshot.png"]
    assert reply["failed"] == [
        "https://masjid.example/missing.pdf",
        "https://masjid.example/fake.pdf",
        "https://masjid.example/missing.png",
    ]


def test_skips_addresses_that_are_not_on_the_web(tmp_path):
    [reply] = replies_to(
        capture(images=["data:image/png;base64,AAAA"]), folder=tmp_path
    )

    assert reply["files"] == ["page.txt", "screenshot.png"]
    assert reply["failed"] == []


def test_reports_an_incomplete_capture(tmp_path):
    [reply] = replies_to(
        {"type": "capture", "placeId": "ChIJ123abc", "capture": {}}, folder=tmp_path
    )

    assert reply == {"type": "error", "error": "The capture was incomplete: 'text'."}
