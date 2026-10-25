import datetime

import pytest
from fastapi.testclient import TestClient

from app.dependencies import get_admin_token, get_now, get_places_client, get_session
from app.main import app
from app.models import Mosque, Prayer
from app.places import NearbyMosque
from app.timetables import save_timetable

TOKEN = "test-admin-token"
AUTH = {"Authorization": f"Bearer {TOKEN}"}
NOW = datetime.datetime(2026, 11, 1, 9, 0, tzinfo=datetime.UTC)
TODAY = datetime.date(2026, 11, 1)
UPDATED = datetime.datetime(2026, 10, 20, tzinfo=datetime.UTC)

DAY = {
    Prayer.FAJR: (datetime.time(5, 52), datetime.time(6, 30)),
    Prayer.SUNRISE: (datetime.time(7, 48), None),
    Prayer.DHUHR: (datetime.time(12, 49), datetime.time(13, 30)),
    Prayer.ASR: (datetime.time(15, 14), datetime.time(15, 45)),
    Prayer.MAGHRIB: (datetime.time(17, 50), datetime.time(17, 55)),
    Prayer.ISHA: (datetime.time(19, 21), datetime.time(19, 45)),
}


class FakePlaces:
    def nearest_mosques(self, latitude, longitude):
        return [
            NearbyMosque("covered", "Green Lane Masjid", "", 52.4120, -1.7780),
            NearbyMosque("empty", "Solihull Mosque", "", 52.4150, -1.7800),
            NearbyMosque("unknown", "Unknown Masjid", "", 52.4200, -1.7900),
        ]


def add_mosque(session, place_id, name, days=0):
    mosque = Mosque(
        place_id=place_id,
        name=name,
        address="Solihull",
        latitude=52.4118,
        longitude=-1.7776,
        time_zone="Europe/London",
    )
    session.add(mosque)
    if days:
        save_timetable(
            session,
            mosque,
            {TODAY + datetime.timedelta(days=offset): DAY for offset in range(days)},
            now=UPDATED,
        )
    session.commit()


@pytest.fixture
def api(session):
    add_mosque(session, "covered", "Green Lane Masjid", days=30)
    add_mosque(session, "empty", "Solihull Mosque")
    app.dependency_overrides[get_session] = lambda: session
    app.dependency_overrides[get_admin_token] = lambda: TOKEN
    app.dependency_overrides[get_places_client] = lambda: FakePlaces()
    app.dependency_overrides[get_now] = lambda: NOW
    yield TestClient(app, headers=AUTH)
    app.dependency_overrides.clear()


@pytest.mark.parametrize(
    "path",
    [
        "/admin/mosques?search=masjid",
        "/admin/mosques/nearby?latitude=52.4&longitude=-1.7",
        "/admin/mosques/needing-times",
        "/admin/mosques/covered",
        "/admin/mosques/covered/timetable",
    ],
)
def test_every_read_needs_the_admin_token(api, path):
    assert api.get(path, headers={"Authorization": ""}).status_code == 401


def test_finds_mosques_by_part_of_their_name(api):
    response = api.get("/admin/mosques", params={"search": "green"})

    assert [mosque["id"] for mosque in response.json()] == ["covered"]


def test_summarises_the_days_a_mosque_has_times_for(api):
    body = api.get("/admin/mosques/covered").json()

    assert body["first_day"] == "2026-11-01"
    assert body["last_day"] == "2026-11-30"
    assert body["timetable_version"] == 1
    assert body["timetable_updated_at"].startswith("2026-10-20")


def test_summary_of_an_unknown_mosque_is_not_found(api):
    assert api.get("/admin/mosques/unknown").status_code == 404


def test_reads_todays_times_by_default(api):
    body = api.get("/admin/mosques/covered/timetable").json()

    assert [day["date"] for day in body["days"]] == ["2026-11-01"]
    assert body["days"][0]["times"]["fajr"] == {
        "begins": "05:52:00",
        "jamaat": "06:30:00",
    }


def test_reads_a_range_of_days(api):
    body = api.get(
        "/admin/mosques/covered/timetable",
        params={"from": "2026-11-10", "to": "2026-11-30"},
    ).json()

    assert len(body["days"]) == 21
    assert body["days"][-1]["date"] == "2026-11-30"


def test_rejects_a_range_that_ends_before_it_starts(api):
    response = api.get(
        "/admin/mosques/covered/timetable",
        params={"from": "2026-11-10", "to": "2026-11-01"},
    )

    assert response.status_code == 422


def test_marks_which_nearby_mosques_have_times(api):
    body = api.get(
        "/admin/mosques/nearby", params={"latitude": 52.4128, "longitude": -1.7781}
    ).json()

    assert [
        (mosque["id"], mosque["in_database"], mosque["last_day"]) for mosque in body
    ] == [
        ("covered", True, "2026-11-30"),
        ("empty", True, None),
        ("unknown", False, None),
    ]
    assert body[0]["distance_meters"] < body[2]["distance_meters"]


def test_lists_mosques_needing_times(api):
    body = api.get("/admin/mosques/needing-times").json()

    assert [mosque["id"] for mosque in body] == ["empty"]
