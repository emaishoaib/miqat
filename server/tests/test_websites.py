import pytest
from fastapi.testclient import TestClient

from app.dependencies import get_admin_token, get_session
from app.main import app
from app.models import Mosque

TOKEN = "test-admin-token"
AUTH = {"Authorization": f"Bearer {TOKEN}"}


@pytest.fixture
def api(session):
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
    app.dependency_overrides[get_session] = lambda: session
    app.dependency_overrides[get_admin_token] = lambda: TOKEN
    yield TestClient(app, headers=AUTH)
    app.dependency_overrides.clear()


def set_website(api, website, place_id="masjid", headers=None):
    return api.put(
        f"/admin/mosques/{place_id}/website",
        json={"website": website},
        headers=headers,
    )


def test_saves_the_website_and_shows_it_in_the_summary(api):
    response = set_website(api, "https://example.org/")

    assert response.status_code == 200
    assert response.json()["website"] == "https://example.org/"
    assert api.get("/admin/mosques/masjid").json()["website"] == "https://example.org/"


def test_replaces_a_website_the_mosque_already_has(session, api):
    set_website(api, "https://old.example.org/")

    set_website(api, "https://new.example.org/")

    assert session.get(Mosque, "masjid").website == "https://new.example.org/"


def test_bumps_the_version_so_the_apps_receive_the_website(session, api):
    set_website(api, "https://example.org/")

    assert session.get(Mosque, "masjid").timetable_version == 1


def test_needs_the_admin_token(session, api):
    response = set_website(
        api, "https://example.org/", headers={"Authorization": "Bearer wrong-token"}
    )

    assert response.status_code == 401
    assert session.get(Mosque, "masjid").website is None


def test_rejects_unknown_mosques(api):
    assert set_website(api, "https://example.org/", "unknown").status_code == 404


@pytest.mark.parametrize(
    "website", ["not a website", "ftp://example.org/", "javascript:alert(1)"]
)
def test_rejects_anything_but_a_web_address(session, api, website):
    response = set_website(api, website)

    assert response.status_code == 422
    mosque = session.get(Mosque, "masjid")
    assert mosque.website is None
    assert mosque.timetable_version == 0
