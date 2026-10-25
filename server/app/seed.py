import datetime

from sqlalchemy.orm import Session

from app.database import SessionLocal, engine
from app.models import Mosque, Prayer, create_tables
from app.timetables import DayTimes, save_timetable

EXAMPLE_MOSQUE_ID = "example-masjid"

EXAMPLE_SCHEDULE: DayTimes = {
    Prayer.FAJR: (datetime.time(5, 52), datetime.time(6, 30)),
    Prayer.SUNRISE: (datetime.time(7, 48), None),
    Prayer.DHUHR: (datetime.time(12, 49), datetime.time(13, 30)),
    Prayer.ASR: (datetime.time(15, 14), datetime.time(15, 45)),
    Prayer.MAGHRIB: (datetime.time(17, 50), datetime.time(17, 55)),
    Prayer.ISHA: (datetime.time(19, 21), datetime.time(19, 45)),
}


def seed(session: Session, start: datetime.date, days: int = 30) -> Mosque:
    mosque = session.get(Mosque, EXAMPLE_MOSQUE_ID)
    if mosque is None:
        mosque = Mosque(
            place_id=EXAMPLE_MOSQUE_ID,
            name="Example Masjid",
            address="Solihull, West Midlands",
            latitude=52.4118,
            longitude=-1.7776,
            time_zone="Europe/London",
        )
        session.add(mosque)
    save_timetable(
        session,
        mosque,
        {
            start + datetime.timedelta(days=offset): EXAMPLE_SCHEDULE
            for offset in range(days)
        },
    )
    return mosque


if __name__ == "__main__":
    create_tables(engine)
    with SessionLocal.begin() as session:
        seed(session, datetime.date.today())
