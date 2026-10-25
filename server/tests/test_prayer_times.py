import datetime

import pytest
from fastapi.testclient import TestClient

from app.dependencies import get_now, get_places_client, get_session
from app.main import app
from app.models import Mosque, Prayer
from app.places import NearbyMosque
from app.timetables import save_timetable

NOW = datetime.datetime(2027, 6, 1, 9, 0, tzinfo=datetime.UTC)
TODAY = datetime.date(2027, 6, 1)
SOLIHULL = {"latitude": 52.4128, "longitude": -1.7781}

DAY: dict = {
    Prayer.FAJR: (datetime.time(3, 0), datetime.time(3, 30)),
    Prayer.SUNRISE: (datetime.time(4, 50), None),
    Prayer.DHUHR: (datetime.time(13, 5), datetime.time(13, 30)),
    Prayer.ASR: (datetime.time(17, 20), datetime.time(17, 45)),
    Prayer.MAGHRIB: (datetime.time(21, 20), datetime.time(21, 25)),
    Prayer.ISHA: (datetime.time(22, 50), datetime.time(23, 0)),
}


class FakePlaces:
    def __init__(self, place_ids):
        self.place_ids = place_ids

    def nearest_mosques(self, latitude, longitude):
        return [
            NearbyMosque(place_id, place_id, "", 52.4118, -1.7776)
            for place_id in self.place_ids
        ]


def add_mosque(session, place_id, days):
    mosque = Mosque(
        place_id=place_id,
        name=f"Masjid {place_id}",
        address="Solihull",
        latitude=52.4118,
        longitude=-1.7776,
        time_zone="Europe/London",
    )
    session.add(mosque)
    if days:
        save_timetable(session, mosque, days)
    session.commit()
    return mosque


@pytest.fixture
def client(session):
    def use(place_ids):
        app.dependency_overrides[get_session] = lambda: session
        app.dependency_overrides[get_places_client] = lambda: FakePlaces(place_ids)
        app.dependency_overrides[get_now] = lambda: NOW
        return TestClient(app)

    yield use
    app.dependency_overrides.clear()


def test_returns_the_nearest_mosque_that_has_times(session, client):
    add_mosque(session, "no-times", {})
    add_mosque(session, "has-times", {TODAY: DAY})

    response = client(["unknown", "no-times", "has-times"]).get(
        "/prayer-times", params=SOLIHULL
    )

    assert response.status_code == 200
    assert response.json()["mosque"]["id"] == "has-times"


def test_skips_mosques_whose_times_are_all_in_the_past(session, client):
    add_mosque(session, "old", {TODAY - datetime.timedelta(days=1): DAY})
    add_mosque(session, "current", {TODAY: DAY})

    response = client(["old", "current"]).get("/prayer-times", params=SOLIHULL)

    assert response.json()["mosque"]["id"] == "current"


def test_returns_404_when_no_nearby_mosque_has_times(session, client):
    add_mosque(session, "no-times", {})

    response = client(["no-times", "unknown"]).get("/prayer-times", params=SOLIHULL)

    assert response.status_code == 404


def test_returns_every_upcoming_day_with_times_in_local_time(session, client):
    tomorrow = TODAY + datetime.timedelta(days=1)
    add_mosque(
        session,
        "masjid",
        {TODAY - datetime.timedelta(days=1): DAY, TODAY: DAY, tomorrow: DAY},
    )

    body = client(["masjid"]).get("/prayer-times", params=SOLIHULL).json()

    assert [day["date"] for day in body["days"]] == ["2027-06-01", "2027-06-02"]
    first = body["days"][0]["times"][0]
    assert first == {
        "prayer": "fajr",
        "begins": "2027-06-01T03:00:00+01:00",
        "jamaat": "2027-06-01T03:30:00+01:00",
    }
    assert [time["prayer"] for time in body["days"][0]["times"]] == [
        prayer.value for prayer in Prayer
    ]


def test_replies_not_modified_when_the_version_matches(session, client):
    add_mosque(session, "masjid", {TODAY: DAY})
    api = client(["masjid"])
    etag = api.get("/prayer-times", params=SOLIHULL).headers["ETag"]

    response = api.get(
        "/prayer-times", params=SOLIHULL, headers={"If-None-Match": etag}
    )

    assert response.status_code == 304
    assert response.content == b""


def test_sends_the_new_timetable_after_it_changes(session, client):
    mosque = add_mosque(session, "masjid", {TODAY: DAY})
    api = client(["masjid"])
    etag = api.get("/prayer-times", params=SOLIHULL).headers["ETag"]

    save_timetable(session, mosque, {TODAY: DAY})
    session.commit()
    response = api.get(
        "/prayer-times", params=SOLIHULL, headers={"If-None-Match": etag}
    )

    assert response.status_code == 200
    assert response.json()["version"] == "masjid:2"
    assert response.headers["ETag"] != etag
