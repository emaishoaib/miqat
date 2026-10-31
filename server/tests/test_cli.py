import io
import json

import httpx
import pytest

from app.cli import main


@pytest.fixture
def server(monkeypatch):
    monkeypatch.setenv("MIQAT_ADMIN_TOKEN", "test-admin-token")
    monkeypatch.setenv("MIQAT_SERVER_URL", "http://miqat.test")
    requests = []

    def respond(status_code=200, body=None):
        def handle(request):
            requests.append(request)
            return httpx.Response(status_code, json=body if body is not None else {})

        return httpx.MockTransport(handle)

    return requests, respond


def test_sends_the_token_to_the_configured_server(server):
    requests, respond = server

    main(["mosque", "masjid"], transport=respond())

    assert str(requests[0].url) == "http://miqat.test/admin/mosques/masjid"
    assert requests[0].headers["Authorization"] == "Bearer test-admin-token"


def test_asks_for_nearby_mosques_at_a_location(server):
    requests, respond = server

    main(["nearby", "52.4128", "-1.7781"], transport=respond(body=[]))

    assert requests[0].url.path == "/admin/mosques/nearby"
    assert requests[0].url.params["longitude"] == "-1.7781"


def test_reads_times_for_a_range_of_days(server):
    requests, respond = server

    main(
        ["times", "masjid", "--from", "2026-11-01", "--to", "2026-11-30"],
        transport=respond(),
    )

    assert requests[0].url.path == "/admin/mosques/masjid/timetable"
    assert dict(requests[0].url.params) == {"from": "2026-11-01", "to": "2026-11-30"}


def test_sets_a_mosques_website(server):
    requests, respond = server

    main(["website", "masjid", "https://example.org/"], transport=respond())

    assert requests[0].method == "PUT"
    assert requests[0].url.path == "/admin/mosques/masjid/website"
    assert json.loads(requests[0].content) == {"website": "https://example.org/"}


def test_uploads_a_timetable_from_a_file(server, tmp_path):
    requests, respond = server
    timetable = {
        "days": [{"date": "2026-11-01", "times": {"fajr": {"begins": "05:52"}}}]
    }
    path = tmp_path / "timetable.json"
    path.write_text(json.dumps(timetable))

    main(["upload", "masjid", str(path)], transport=respond())

    assert requests[0].method == "PUT"
    assert json.loads(requests[0].content) == timetable


def test_prints_the_reply_and_succeeds(server, capsys):
    _, respond = server

    code = main(["mosque", "masjid"], transport=respond(body={"id": "masjid"}))

    assert code == 0
    assert json.loads(capsys.readouterr().out) == {"id": "masjid"}


def test_prints_the_servers_problems_and_fails(server, capsys, monkeypatch):
    _, respond = server
    problems = {"detail": ["2026-11-01: asr is missing."]}
    monkeypatch.setattr("sys.stdin", io.StringIO('{"days": []}'))

    code = main(["upload", "masjid", "-"], transport=respond(422, problems))

    assert code == 1
    assert json.loads(capsys.readouterr().err) == problems


def test_refuses_to_run_without_a_token(monkeypatch, capsys):
    monkeypatch.delenv("MIQAT_ADMIN_TOKEN", raising=False)

    assert main(["mosque", "masjid"]) == 1
    assert "MIQAT_ADMIN_TOKEN" in capsys.readouterr().err
