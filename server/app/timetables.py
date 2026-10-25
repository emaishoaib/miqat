import datetime

from sqlalchemy import delete
from sqlalchemy.orm import Session

from app.models import Mosque, Prayer, PrayerTime

DayTimes = dict[Prayer, tuple[datetime.time, datetime.time | None]]


def save_timetable(
    session: Session, mosque: Mosque, days: dict[datetime.date, DayTimes]
) -> None:
    session.execute(
        delete(PrayerTime).where(
            PrayerTime.place_id == mosque.place_id, PrayerTime.date.in_(list(days))
        )
    )
    for day, times in days.items():
        for prayer, (begins, jamaat) in times.items():
            session.add(
                PrayerTime(
                    place_id=mosque.place_id,
                    date=day,
                    prayer=prayer,
                    begins=begins,
                    jamaat=jamaat,
                )
            )
    mosque.timetable_version = (mosque.timetable_version or 0) + 1
