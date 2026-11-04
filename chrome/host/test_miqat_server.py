import pytest
from miqat_server import UploadError, outcome, server_host, upload_url


def test_reads_the_server_domain_from_the_release_config(tmp_path):
    config = tmp_path / "Release.xcconfig"
    config.write_text("DEVELOPMENT_TEAM = TEAM\nMIQAT_SERVER_HOST = miqat.example\n")

    assert server_host(config) == "miqat.example"


def test_reports_a_release_config_without_the_server_domain(tmp_path):
    config = tmp_path / "Release.xcconfig"
    config.write_text("DEVELOPMENT_TEAM = TEAM\n")

    with pytest.raises(UploadError, match="has no MIQAT_SERVER_HOST"):
        server_host(config)


def test_reports_a_missing_release_config(tmp_path):
    with pytest.raises(UploadError, match="Couldn't read Release.xcconfig"):
        server_host(tmp_path / "Release.xcconfig")


def test_puts_the_timetable_under_the_mosque_place_id():
    assert (
        upload_url("miqat.example", "ChIJ123abc")
        == "https://miqat.example/admin/mosques/ChIJ123abc/timetable"
    )


def test_escapes_a_place_id_that_could_change_the_path():
    assert (
        upload_url("miqat.example", "../health")
        == "https://miqat.example/admin/mosques/..%2Fhealth/timetable"
    )


def test_reports_how_many_days_the_server_saved():
    body = {"version": "masjid:3", "days_saved": 30}

    assert outcome(200, body) == {"type": "uploaded", "daysSaved": 30}


def test_passes_on_the_server_reasons_for_a_rejection():
    body = {"detail": ["2026-11-02 is missing.", "2026-11-05 isha is before maghrib."]}

    assert outcome(422, body) == {
        "type": "rejected",
        "problems": ["2026-11-02 is missing.", "2026-11-05 isha is before maghrib."],
    }


def test_explains_a_rejection_of_the_timetable_shape():
    body = {
        "detail": [
            {
                "loc": ["body", "days", 0, "times", "fajr"],
                "msg": "Field required",
            }
        ]
    }

    assert outcome(422, body) == {
        "type": "rejected",
        "problems": ["days.0.times.fajr: Field required"],
    }


@pytest.mark.parametrize(
    ("status", "message"),
    [
        (401, "didn't accept the admin token"),
        (404, "doesn't know this mosque"),
        (500, "status 500"),
    ],
)
def test_reports_other_replies_as_errors(status, message):
    with pytest.raises(UploadError, match=message):
        outcome(status, {"detail": "Something went wrong."})
