import datetime
import logging
from collections.abc import Iterator
from zoneinfo import ZoneInfo

import httpx
from sqlalchemy import delete, func, select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from app.aladhan import AlAdhanClient, CalculatedMonth
from app.calculation import (
    METHOD_NAMES,
    SCHOOL_NAMES,
    Method,
    School,
    method_for,
    school_for,
)
from app.geocoding import GeocodedCity, GeocodingClient, GeocodingError
from app.models import City, CityPrayerTime, Prayer
from app.schemas import CityOut, DayOut, PrayerTimeOut, TimetableOut
from app.time_zones import TimeZoneClient, TimeZoneLookupError

DAYS_AHEAD = 7
PRAYER_ORDER = list(Prayer)

logger = logging.getLogger(__name__)


def city_with_times(
    session: Session,
    geocoding: GeocodingClient,
    time_zones: TimeZoneClient,
    aladhan: AlAdhanClient,
    latitude: float,
    longitude: float,
    now: datetime.datetime,
) -> tuple[City, list[CityPrayerTime]] | None:
    try:
        found = geocoding.city_at(latitude, longitude)
    except (httpx.HTTPError, GeocodingError) as error:
        logger.warning("No city at %s,%s: %s", latitude, longitude, error)
        return None
    if found is None:
        return None

    city = session.get(City, found.place_id)
    try:
        if city is None:
            city = add_city(session, found, time_zones)
        add_missing_days(session, city, aladhan, now)
        session.commit()
    except (httpx.HTTPError, TimeZoneLookupError, IntegrityError) as error:
        logger.warning("No new times for %s: %s", found.place_id, error)
        session.rollback()
        city = session.get(City, found.place_id)
        if city is None:
            return None

    times = upcoming_city_times(session, city, now)
    return (city, times) if times else None


def add_city(session: Session, found: GeocodedCity, time_zones: TimeZoneClient) -> City:
    city = City(
        place_id=found.place_id,
        name=found.name,
        country=found.country,
        latitude=found.latitude,
        longitude=found.longitude,
        time_zone=time_zones.time_zone_at(found.latitude, found.longitude),
        method=method_for(found.country),
        school=school_for(found.country),
    )
    session.add(city)
    return city


def add_missing_days(
    session: Session, city: City, aladhan: AlAdhanClient, now: datetime.datetime
) -> None:
    today = now.astimezone(ZoneInfo(city.time_zone)).date()
    last_needed = today + datetime.timedelta(days=DAYS_AHEAD - 1)
    last_stored = session.scalar(
        select(func.max(CityPrayerTime.date)).where(
            CityPrayerTime.place_id == city.place_id
        )
    )
    if last_stored is not None and last_stored >= last_needed:
        return
    first_missing = (
        today
        if last_stored is None or last_stored < today
        else last_stored + datetime.timedelta(days=1)
    )
    for year, month in months_between(first_missing, last_needed):
        save_city_month(
            session,
            city,
            aladhan.month_at(
                city.latitude,
                city.longitude,
                year,
                month,
                Method(city.method),
                School(city.school),
            ),
        )


def months_between(
    first: datetime.date, last: datetime.date
) -> Iterator[tuple[int, int]]:
    year, month = first.year, first.month
    while (year, month) <= (last.year, last.month):
        yield year, month
        year, month = (year + 1, 1) if month == 12 else (year, month + 1)


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


def upcoming_city_times(
    session: Session, city: City, now: datetime.datetime
) -> list[CityPrayerTime]:
    today = now.astimezone(ZoneInfo(city.time_zone)).date()
    times = session.scalars(
        select(CityPrayerTime).where(
            CityPrayerTime.place_id == city.place_id, CityPrayerTime.date >= today
        )
    ).all()
    return sorted(times, key=lambda time: (time.date, PRAYER_ORDER.index(time.prayer)))


def city_timetable_version(city: City) -> str:
    return f"{city.place_id}:{city.timetable_version}"


def city_timetable_response(city: City, times: list[CityPrayerTime]) -> TimetableOut:
    zone = ZoneInfo(city.time_zone)
    days: dict[datetime.date, list[PrayerTimeOut]] = {}
    for time in times:
        days.setdefault(time.date, []).append(
            PrayerTimeOut(
                prayer=time.prayer,
                begins=datetime.datetime.combine(time.date, time.begins, zone),
                jamaat=None,
            )
        )
    return TimetableOut(
        version=city_timetable_version(city),
        city=CityOut(
            id=city.place_id,
            name=city.name,
            method=METHOD_NAMES[Method(city.method)],
            asr_school=SCHOOL_NAMES[School(city.school)],
        ),
        time_zone=city.time_zone,
        days=[DayOut(date=day, times=day_times) for day, day_times in days.items()],
    )
