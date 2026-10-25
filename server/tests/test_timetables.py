import datetime

from sqlalchemy import select

from app.models import Prayer, PrayerTime
from app.seed import seed
from app.timetables import save_timetable

START = datetime.date(2026, 10, 25)


def times_on(session, place_id, day):
    return session.scalars(
        select(PrayerTime).where(
            PrayerTime.place_id == place_id, PrayerTime.date == day
        )
    ).all()


def test_seed_stores_thirty_days_of_times_for_the_example_mosque(session):
    mosque = seed(session, START)
    session.flush()

    assert len(session.scalars(select(PrayerTime)).all()) == 30 * 6
    assert mosque.timetable_version == 1


def test_saving_a_day_again_replaces_it_and_bumps_the_version(session):
    mosque = seed(session, START)
    session.flush()

    save_timetable(session, mosque, {START: {Prayer.FAJR: (datetime.time(6, 0), None)}})
    session.flush()

    times = times_on(session, mosque.place_id, START)
    assert [(time.prayer, time.begins) for time in times] == [
        (Prayer.FAJR, datetime.time(6, 0))
    ]
    assert (
        len(times_on(session, mosque.place_id, START + datetime.timedelta(days=1))) == 6
    )
    assert mosque.timetable_version == 2
