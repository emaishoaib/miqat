import calendar
import datetime

import httpx
import pytest
from fastapi.testclient import TestClient
from sqlalchemy import select

from app.aladhan import CalculatedMonth
from app.calculation import Method, School
from app.dependencies import (
    get_aladhan_client,
    get_geocoding_client,
    get_now,
    get_places_client,
    get_session,
    get_time_zone_client,
)
from app.main import app
from app.geocoding import GeocodedCity, GeocodingError
from app.models import City, Mosque, Prayer
from app.places import NearbyMosque
from app.time_zones import TimeZoneLookupError
from app.timetables import save_timetable

NOW = datetime.datetime(2027, 6, 1, 9, 0, tzinfo=datetime.UTC)
TODAY = datetime.date(2027, 6, 1)
SOLIHULL = {"latitude": 52.4128, "longitude": -1.7781}
SOLIHULL_CITY = GeocodedCity("place-solihull", "Solihull", "GB", 52.4118, -1.7776)

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


class FakeTimeZones:
    def __init__(self, fails=False):
        self.fails = fails

    def time_zone_at(self, latitude, longitude):
        if self.fails:
            raise TimeZoneLookupError("UNKNOWN_ERROR")
        return "Europe/London"


class FakeGeocoding:
    def __init__(self, city=None, fails=False):
        self.city = city
        self.fails = fails

    def city_at(self, latitude, longitude):
        if self.fails:
            raise GeocodingError("REQUEST_DENIED")
        return self.city


class FakeAlAdhan:
    def __init__(self, fails=False):
        self.fails = fails
        self.requests = []

    def month_at(self, latitude, longitude, year, month, method, school):
        self.requests.append((year, month, method, school))
        if self.fails:
            raise httpx.ConnectError("AlAdhan is down")
        return CalculatedMonth(
            time_zone="Europe/London",
            days={
                datetime.date(year, month, day): {
                    prayer: begins for prayer, (begins, _) in DAY.items()
                }
                for day in range(1, calendar.monthrange(year, month)[1] + 1)
            },
        )


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
    def use(
        place_ids,
        time_zones_fail=False,
        geocoding=None,
        aladhan=None,
        now=NOW,
    ):
        app.dependency_overrides[get_session] = lambda: session
        app.dependency_overrides[get_places_client] = lambda: FakePlaces(place_ids)
        app.dependency_overrides[get_time_zone_client] = lambda: FakeTimeZones(
            time_zones_fail
        )
        app.dependency_overrides[get_geocoding_client] = lambda: (
            geocoding or FakeGeocoding()
        )
        app.dependency_overrides[get_aladhan_client] = lambda: aladhan or FakeAlAdhan()
        app.dependency_overrides[get_now] = lambda: now
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


def test_returns_404_when_no_nearby_mosque_has_times_and_there_is_no_city(
    session, client
):
    add_mosque(session, "no-times", {})

    response = client(["no-times", "unknown"]).get("/prayer-times", params=SOLIHULL)

    assert response.status_code == 404
    assert response.json()["detail"] == "Unable to get prayer times."


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


def test_adds_unknown_mosques_closer_than_the_one_that_answered(session, client):
    add_mosque(session, "has-times", {TODAY: DAY})

    client(["new-near", "has-times", "new-far"]).get("/prayer-times", params=SOLIHULL)

    added = session.get(Mosque, "new-near")
    assert added is not None
    assert added.time_zone == "Europe/London"
    assert added.timetable_updated_at is None
    assert session.get(Mosque, "new-far") is None


def test_adds_every_unknown_mosque_when_none_answers(session, client):
    response = client(["first", "second"]).get("/prayer-times", params=SOLIHULL)

    assert response.status_code == 404
    assert session.get(Mosque, "first") is not None
    assert session.get(Mosque, "second") is not None


def test_repeat_lookups_do_not_add_the_same_mosque_twice(session, client):
    api = client(["new"])

    api.get("/prayer-times", params=SOLIHULL)
    api.get("/prayer-times", params=SOLIHULL)

    assert session.scalars(select(Mosque)).all() == [session.get(Mosque, "new")]


def test_still_answers_when_the_time_zone_lookup_fails(session, client):
    add_mosque(session, "has-times", {TODAY: DAY})

    response = client(["new", "has-times"], time_zones_fail=True).get(
        "/prayer-times", params=SOLIHULL
    )

    assert response.status_code == 200
    assert session.get(Mosque, "new") is None


def test_falls_back_to_the_city_times_when_no_mosque_has_times(session, client):
    response = client(["no-times"], geocoding=FakeGeocoding(SOLIHULL_CITY)).get(
        "/prayer-times", params=SOLIHULL
    )

    assert response.status_code == 200
    body = response.json()
    assert body["mosque"] is None
    assert body["city"] == {
        "id": "place-solihull",
        "name": "Solihull",
        "method": "Moonsighting Committee Worldwide",
        "asr_school": "Hanafi",
    }
    assert body["version"] == "place-solihull:1"
    assert body["days"][0]["times"][0] == {
        "prayer": "fajr",
        "begins": "2027-06-01T03:00:00+01:00",
        "jamaat": None,
    }


def test_prefers_a_mosque_with_times_over_the_city(session, client):
    add_mosque(session, "has-times", {TODAY: DAY})
    aladhan = FakeAlAdhan()

    response = client(
        ["has-times"], geocoding=FakeGeocoding(SOLIHULL_CITY), aladhan=aladhan
    ).get("/prayer-times", params=SOLIHULL)

    assert response.json()["mosque"]["id"] == "has-times"
    assert aladhan.requests == []


def test_calculates_city_times_with_the_country_method_and_school(session, client):
    aladhan = FakeAlAdhan()

    client([], geocoding=FakeGeocoding(SOLIHULL_CITY), aladhan=aladhan).get(
        "/prayer-times", params=SOLIHULL
    )

    assert aladhan.requests == [(2027, 6, Method.MOONSIGHTING_COMMITTEE, School.HANAFI)]
    city = session.get(City, "place-solihull")
    assert city.time_zone == "Europe/London"


def test_reuses_stored_city_times_instead_of_asking_aladhan_again(session, client):
    aladhan = FakeAlAdhan()
    api = client([], geocoding=FakeGeocoding(SOLIHULL_CITY), aladhan=aladhan)

    api.get("/prayer-times", params=SOLIHULL)
    api.get("/prayer-times", params=SOLIHULL)

    assert len(aladhan.requests) == 1


def test_fetches_next_month_when_the_city_times_run_out_within_a_week(session, client):
    aladhan = FakeAlAdhan()
    end_of_june = datetime.datetime(2027, 6, 28, 9, 0, tzinfo=datetime.UTC)

    body = (
        client(
            [], geocoding=FakeGeocoding(SOLIHULL_CITY), aladhan=aladhan, now=end_of_june
        )
        .get("/prayer-times", params=SOLIHULL)
        .json()
    )

    assert [(year, month) for year, month, _, _ in aladhan.requests] == [
        (2027, 6),
        (2027, 7),
    ]
    assert body["days"][0]["date"] == "2027-06-28"
    assert body["days"][-1]["date"] == "2027-07-31"


def test_returns_404_when_aladhan_fails_for_a_new_city(session, client):
    response = client(
        [], geocoding=FakeGeocoding(SOLIHULL_CITY), aladhan=FakeAlAdhan(fails=True)
    ).get("/prayer-times", params=SOLIHULL)

    assert response.status_code == 404
    assert response.json()["detail"] == "Unable to get prayer times."
    assert session.get(City, "place-solihull") is None


def test_returns_404_when_the_city_lookup_fails(session, client):
    response = client([], geocoding=FakeGeocoding(fails=True)).get(
        "/prayer-times", params=SOLIHULL
    )

    assert response.status_code == 404
