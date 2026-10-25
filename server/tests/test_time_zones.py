import httpx
import pytest

from app.time_zones import TimeZoneClient, TimeZoneLookupError


def client_returning(body, requests=None):
    def handle(request):
        if requests is not None:
            requests.append(request)
        return httpx.Response(200, json=body)

    return TimeZoneClient(
        "test-key", http=httpx.Client(transport=httpx.MockTransport(handle))
    )


def test_returns_the_time_zone_name():
    client = client_returning({"status": "OK", "timeZoneId": "Europe/London"})

    assert client.time_zone_at(52.4118, -1.7776) == "Europe/London"


def test_asks_google_about_the_location_with_the_key():
    requests = []
    client_returning(
        {"status": "OK", "timeZoneId": "Africa/Cairo"}, requests
    ).time_zone_at(30.0444, 31.2357)

    params = requests[0].url.params
    assert params["location"] == "30.0444,31.2357"
    assert params["key"] == "test-key"


def test_raises_when_google_cannot_find_a_time_zone():
    with pytest.raises(TimeZoneLookupError):
        client_returning({"status": "ZERO_RESULTS"}).time_zone_at(0.0, 0.0)
