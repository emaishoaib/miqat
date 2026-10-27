import datetime

import httpx
import pytest

from app.aladhan import AlAdhanClient
from app.calculation import Method, School
from app.models import Prayer


def aladhan_day(date, fajr):
    return {
        "timings": {
            "Fajr": f"{fajr} (GMT)",
            "Sunrise": "07:03 (GMT)",
            "Dhuhr": "11:51 (GMT)",
            "Asr": "14:49 (GMT)",
            "Sunset": "16:38 (GMT)",
            "Maghrib": "16:38 (GMT)",
            "Isha": "18:05 (GMT)",
            "Imsak": "05:16 (GMT)",
            "Midnight": "23:50 (GMT)",
        },
        "date": {"gregorian": {"date": date, "format": "DD-MM-YYYY"}},
        "meta": {"timezone": "Europe/London"},
    }


ALADHAN_RESPONSE = {
    "code": 200,
    "status": "OK",
    "data": [aladhan_day("01-11-2026", "05:26"), aladhan_day("02-11-2026", "05:28")],
}


def client_returning(body, status_code=200, requests=None):
    def handle(request):
        if requests is not None:
            requests.append(request)
        return httpx.Response(status_code, json=body)

    return AlAdhanClient(http=httpx.Client(transport=httpx.MockTransport(handle)))


def month_from(client):
    return client.month_at(
        52.4128, -1.7781, 2026, 11, Method.MOONSIGHTING_COMMITTEE, School.HANAFI
    )


def test_returns_each_day_of_the_month_with_its_prayer_times_and_time_zone():
    month = month_from(client_returning(ALADHAN_RESPONSE))

    assert month.time_zone == "Europe/London"
    assert list(month.days) == [datetime.date(2026, 11, 1), datetime.date(2026, 11, 2)]
    assert month.days[datetime.date(2026, 11, 2)] == {
        Prayer.FAJR: datetime.time(5, 28),
        Prayer.SUNRISE: datetime.time(7, 3),
        Prayer.DHUHR: datetime.time(11, 51),
        Prayer.ASR: datetime.time(14, 49),
        Prayer.MAGHRIB: datetime.time(16, 38),
        Prayer.ISHA: datetime.time(18, 5),
    }


def test_asks_for_the_month_at_the_location_with_the_method_and_school():
    requests = []
    month_from(client_returning(ALADHAN_RESPONSE, requests=requests))

    url = requests[0].url
    assert url.path == "/v1/calendar/2026/11"
    assert url.params["latitude"] == "52.4128"
    assert url.params["longitude"] == "-1.7781"
    assert url.params["method"] == "15"
    assert url.params["school"] == "1"


def test_raises_when_aladhan_rejects_the_request():
    body = {"code": 400, "status": "BAD_REQUEST", "data": "Invalid coordinates."}

    with pytest.raises(httpx.HTTPStatusError):
        month_from(client_returning(body, status_code=400))
