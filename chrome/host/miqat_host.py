#!/usr/bin/env python3
"""The Miqat helper, which the Chrome extension talks to through native messaging.

Chrome starts it and exchanges JSON messages with it over stdin and stdout, each
one preceded by its length as a 4-byte integer. It runs on the Mac's own
Python 3.9, because Chrome starts it without the shell's PATH.
"""

from __future__ import annotations

import json
import struct
import sys
from typing import BinaryIO

LENGTH_FORMAT = "=I"
LENGTH_SIZE_BYTES = struct.calcsize(LENGTH_FORMAT)


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


def reply_to(message: dict) -> dict:
    if message.get("type") == "ping":
        return {"type": "pong"}
    return {"type": "error", "error": f"Unknown message type {message.get('type')!r}."}


def main(stdin: BinaryIO, stdout: BinaryIO) -> None:
    while True:
        message = read_message(stdin)
        if message is None:
            return
        write_message(stdout, reply_to(message))


if __name__ == "__main__":
    main(sys.stdin.buffer, sys.stdout.buffer)
