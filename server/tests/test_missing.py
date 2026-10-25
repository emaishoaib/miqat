import datetime

from app.missing import mosques_needing_times
from app.models import Mosque, Prayer
from app.timetables import save_timetable

TODAY = datetime.date(2027, 6, 1)
DAY = {Prayer.FAJR: (datetime.time(3, 0), None)}


def add_mosque(session, place_id, days=None, updated_at=None):
    mosque = Mosque(
        place_id=place_id,
        name=place_id,
        address="",
        latitude=52.4,
        longitude=-1.7,
        time_zone="Europe/London",
    )
    session.add(mosque)
    if days is not None:
        save_timetable(
            session,
            mosque,
            {TODAY + datetime.timedelta(days=offset): DAY for offset in range(days)},
            now=updated_at,
        )
    session.flush()


def needing(session):
    return [mosque.place_id for mosque, _ in mosques_needing_times(session, TODAY)]


def test_lists_mosques_without_times_or_running_low_and_skips_the_rest(session):
    add_mosque(session, "never")
    add_mosque(session, "low", days=3, updated_at=datetime.datetime(2027, 5, 1))
    add_mosque(session, "plenty", days=30, updated_at=datetime.datetime(2027, 5, 1))

    assert needing(session) == ["never", "low"]


def test_lists_the_longest_untouched_mosques_first(session):
    add_mosque(session, "recent", days=1, updated_at=datetime.datetime(2027, 5, 20))
    add_mosque(session, "old", days=1, updated_at=datetime.datetime(2027, 3, 1))
    add_mosque(session, "never")

    assert needing(session) == ["never", "old", "recent"]
