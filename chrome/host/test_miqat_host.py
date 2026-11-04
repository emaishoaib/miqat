import io
import json
import struct

from miqat_host import main, read_message, write_message


def framed(message: dict) -> bytes:
    body = json.dumps(message).encode()
    return struct.pack("=I", len(body)) + body


def replies_to(*messages: dict) -> list[dict]:
    stdin = io.BytesIO(b"".join(framed(message) for message in messages))
    stdout = io.BytesIO()
    main(stdin, stdout)
    stdout.seek(0)
    replies = []
    while (reply := read_message(stdout)) is not None:
        replies.append(reply)
    return replies


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
