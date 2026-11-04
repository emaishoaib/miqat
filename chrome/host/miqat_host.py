#!/usr/bin/env python3
"""The Miqat helper, which the Chrome extension talks to through native messaging.

Chrome starts it and exchanges JSON messages with it over stdin and stdout, each
one preceded by its length as a 4-byte integer. It runs on the Mac's own
Python 3.9, because Chrome starts it without the shell's PATH.
"""

from __future__ import annotations

import base64
import json
import struct
import sys
import tempfile
import urllib.request
from collections.abc import Callable
from pathlib import Path
from typing import BinaryIO

LENGTH_FORMAT = "=I"
LENGTH_SIZE_BYTES = struct.calcsize(LENGTH_FORMAT)
MAX_DOWNLOADS = 6
MAX_DOWNLOAD_BYTES = 20 * 1024 * 1024
DOWNLOAD_TIMEOUT_SECONDS = 20
USER_AGENT = "Mozilla/5.0 (Macintosh) MiqatHelper"
IMAGE_SUFFIXES = {
    "image/png": ".png",
    "image/jpeg": ".jpg",
    "image/webp": ".webp",
    "image/gif": ".gif",
}

Fetch = Callable[[str], tuple[bytes, str]]
NewFolder = Callable[[], Path]


def read_message(stream: BinaryIO) -> dict | None:
    header = stream.read(LENGTH_SIZE_BYTES)
    if len(header) < LENGTH_SIZE_BYTES:
        return None
    (length,) = struct.unpack(LENGTH_FORMAT, header)
    return json.loads(stream.read(length))


def write_message(stream: BinaryIO, message: dict) -> None:
    body = json.dumps(message).encode()
    stream.write(struct.pack(LENGTH_FORMAT, len(body)) + body)
    stream.flush()


def fetch_from_web(url: str) -> tuple[bytes, str]:
    request = urllib.request.Request(url, headers={"User-Agent": USER_AGENT})
    with urllib.request.urlopen(request, timeout=DOWNLOAD_TIMEOUT_SECONDS) as response:
        body = response.read(MAX_DOWNLOAD_BYTES + 1)
        content_type = response.headers.get_content_type()
    if len(body) > MAX_DOWNLOAD_BYTES:
        raise ValueError(f"{url} is larger than {MAX_DOWNLOAD_BYTES} bytes")
    return body, content_type


def new_capture_folder() -> Path:
    return Path(tempfile.mkdtemp(prefix="miqat-capture-"))


def is_web_url(url: str) -> bool:
    return url.startswith(("http://", "https://"))


def download(url: str, fetch: Fetch) -> tuple[bytes, str] | None:
    try:
        return fetch(url)
    except (OSError, ValueError):
        return None


def screenshot_bytes(data_url: str) -> bytes:
    _, _, encoded = data_url.partition(",")
    return base64.b64decode(encoded, validate=True)


def pdf_suffix(body: bytes, content_type: str) -> str | None:
    return ".pdf" if body.startswith(b"%PDF") else None


def image_suffix(body: bytes, content_type: str) -> str | None:
    return IMAGE_SUFFIXES.get(content_type)


def save_downloads(
    urls: list[str],
    prefix: str,
    suffix_for: Callable[[bytes, str], str | None],
    folder: Path,
    fetch: Fetch,
) -> tuple[dict[str, str], list[str]]:
    saved: dict[str, str] = {}
    failed: list[str] = []
    for url in [url for url in urls if is_web_url(url)][:MAX_DOWNLOADS]:
        downloaded = download(url, fetch)
        suffix = suffix_for(*downloaded) if downloaded is not None else None
        if suffix is None:
            failed.append(url)
            continue
        name = f"{prefix}-{len(saved) + 1}{suffix}"
        (folder / name).write_bytes(downloaded[0])
        saved[name] = url
    return saved, failed


def save_capture(place_id: str, capture: dict, folder: Path, fetch: Fetch) -> dict:
    (folder / "page.txt").write_text(capture["text"])
    (folder / "screenshot.png").write_bytes(screenshot_bytes(capture["screenshot"]))
    pdfs, failed_pdfs = save_downloads(
        [pdf["url"] for pdf in capture["pdfs"]], "pdf", pdf_suffix, folder, fetch
    )
    images, failed_images = save_downloads(
        capture["images"], "image", image_suffix, folder, fetch
    )
    sources = {
        "page.txt": capture["url"],
        "screenshot.png": capture["url"],
        **pdfs,
        **images,
    }

    details = {
        "place_id": place_id,
        "url": capture["url"],
        "title": capture["title"],
        "sources": sources,
    }
    (folder / "capture.json").write_text(json.dumps(details, indent=2))
    return {
        "type": "captured",
        "folder": str(folder),
        "files": list(sources),
        "failed": failed_pdfs + failed_images,
    }


def reply_to(message: dict, fetch: Fetch, new_folder: NewFolder) -> dict:
    kind = message.get("type")
    if kind == "ping":
        return {"type": "pong"}
    if kind == "capture":
        try:
            return save_capture(
                message["placeId"], message["capture"], new_folder(), fetch
            )
        except (KeyError, ValueError) as error:
            return {"type": "error", "error": f"The capture was incomplete: {error}."}
    return {"type": "error", "error": f"Unknown message type {kind!r}."}


def main(
    stdin: BinaryIO,
    stdout: BinaryIO,
    fetch: Fetch = fetch_from_web,
    new_folder: NewFolder = new_capture_folder,
) -> None:
    while True:
        message = read_message(stdin)
        if message is None:
            return
        write_message(stdout, reply_to(message, fetch, new_folder))


if __name__ == "__main__":
    main(sys.stdin.buffer, sys.stdout.buffer)
