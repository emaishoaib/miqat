from sqlalchemy import delete
from sqlalchemy.orm import Session

from app.aladhan import CalculatedMonth
from app.models import City, CityPrayerTime


def save_city_month(session: Session, city: City, month: CalculatedMonth) -> None:
    session.execute(
        delete(CityPrayerTime).where(
            CityPrayerTime.place_id == city.place_id,
            CityPrayerTime.date.in_(list(month.days)),
        )
    )
    for day, times in month.days.items():
        for prayer, begins in times.items():
            session.add(
                CityPrayerTime(
                    place_id=city.place_id, date=day, prayer=prayer, begins=begins
                )
            )
    city.timetable_version = (city.timetable_version or 0) + 1
