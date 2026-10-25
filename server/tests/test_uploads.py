import datetime

import pytest
from fastapi.testclient import TestClient
from sqlalchemy import select

from app.dependencies import get_admin_token, get_session
from app.main import app
from app.models import Mosque, PrayerTime

TOKEN = "test-admin-token"
AUTH = {"Authorization": f"Bearer {TOKEN}"}

DAY = {
    "fajr": {"begins": "05:52", "jamaat": "06:30"},
    "sunrise": {"begins": "07:48"},
    "dhuhr": {"begins": "12:49", "jamaat": "13:30"},
    "asr": {"begins": "15:14", "jamaat": "15:45"},
    "maghrib": {"begins": "17:50", "jamaat": "17:55"},
    "isha": {"begins": "19:21", "jamaat": "19:45"},
}


def days(*dates, times=DAY):
    return {"days": [{"date": date, "times": times} for date in dates]}


@pytest.fixture
def client(session):
    session.add(
        Mosque(
            place_id="masjid",
            name="Masjid",
            address="Solihull",
            latitude=52.4118,
            longitude=-1.7776,
            time_zone="Europe/London",
        )
    )
    session.commit()

    def use(admin_token=TOKEN):
        app.dependency_overrides[get_session] = lambda: session
        app.dependency_overrides[get_admin_token] = lambda: admin_token
        return TestClient(app)

    yield use
    app.dependency_overrides.clear()


def upload(api, body, headers=AUTH, place_id="masjid"):
    return api.put(f"/admin/mosques/{place_id}/timetable", json=body, headers=headers)


def saved_times(session):
    return session.scalars(select(PrayerTime)).all()


def test_saves_the_timetable_and_bumps_the_version(session, client):
    response = upload(client(), days("2026-11-01", "2026-11-02"))

    assert response.status_code == 200
    assert response.json() == {"version": "masjid:1", "days_saved": 2}
    assert len(saved_times(session)) == 12
    assert session.get(Mosque, "masjid").timetable_updated_at is not None


def test_stores_begin_and_jamaat_times(session, client):
    upload(client(), days("2026-11-01"))

    fajr = next(time for time in saved_times(session) if time.prayer == "fajr")
    assert fajr.date == datetime.date(2026, 11, 1)
    assert fajr.begins == datetime.time(5, 52)
    assert fajr.jamaat == datetime.time(6, 30)


@pytest.mark.parametrize(
    "headers",
    [{}, {"Authorization": "Bearer wrong-token"}, {"Authorization": TOKEN}],
)
def test_rejects_uploads_without_the_right_token(session, client, headers):
    response = upload(client(), days("2026-11-01"), headers=headers)

    assert response.status_code == 401
    assert saved_times(session) == []


def test_rejects_every_upload_when_no_token_is_configured(session, client):
    response = upload(client(admin_token=None), days("2026-11-01"))

    assert response.status_code == 401


def test_rejects_unknown_mosques(client):
    response = upload(client(), days("2026-11-01"), place_id="unknown")

    assert response.status_code == 404


@pytest.mark.parametrize(
    ("body", "problem"),
    [
        (
            days("2026-11-01", times={k: v for k, v in DAY.items() if k != "asr"}),
            "2026-11-01: asr is missing.",
        ),
        (
            days("2026-11-01", times={**DAY, "asr": {"begins": "12:00"}}),
            "2026-11-01: asr begins before or with dhuhr.",
        ),
        (
            days(
                "2026-11-01",
                times={**DAY, "isha": {"begins": "19:21", "jamaat": "19:00"}},
            ),
            "2026-11-01: isha jamaat is before it begins.",
        ),
        (days("2026-11-01", "2026-11-01"), "2026-11-01 appears more than once."),
        (
            days("2026-11-01", "2026-11-04"),
            "Days are missing between 2026-11-01 and 2026-11-04.",
        ),
        ({"days": []}, "The timetable has no days."),
    ],
)
def test_rejects_timetables_that_fail_a_check(session, client, body, problem):
    response = upload(client(), body)

    assert response.status_code == 422
    assert problem in response.json()["detail"]
    assert saved_times(session) == []


def test_allows_a_timetable_without_sunrise(session, client):
    times = {k: v for k, v in DAY.items() if k != "sunrise"}

    response = upload(client(), days("2026-11-01", times=times))

    assert response.status_code == 200
