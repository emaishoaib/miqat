import datetime
import logging
from zoneinfo import ZoneInfo

import httpx
from sqlalchemy import delete, select
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
from app.lookup import DAYS_BACK
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
    if not times:
        return None
    return city, get_city_times_before_today(session, city, now) + times


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
    one_day = datetime.timedelta(days=1)
    first_needed = today - DAYS_BACK * one_day
    stored = set(
        session.scalars(
            select(CityPrayerTime.date).where(
                CityPrayerTime.place_id == city.place_id,
                CityPrayerTime.date >= first_needed,
            )
        )
    )
    needed = [
        first_needed + offset * one_day for offset in range(DAYS_BACK + DAYS_AHEAD)
    ]
    missing_months = {(day.year, day.month) for day in needed if day not in stored}
    for year, month in sorted(missing_months):
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


def get_city_times_before_today(
    session: Session, city: City, now: datetime.datetime
) -> list[CityPrayerTime]:
    today = now.astimezone(ZoneInfo(city.time_zone)).date()
    one_day = datetime.timedelta(days=1)
    times = session.scalars(
        select(CityPrayerTime).where(
            CityPrayerTime.place_id == city.place_id,
            CityPrayerTime.date >= today - DAYS_BACK * one_day,
            CityPrayerTime.date < today,
        )
    ).all()
    dates = {time.date for time in times}
    first = today
    while first - one_day in dates:
        first -= one_day
    return sorted(
        (time for time in times if time.date >= first),
        key=lambda time: (time.date, PRAYER_ORDER.index(time.prayer)),
    )


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
    city_out = CityOut(
        id=city.place_id,
        name=city.name,
        method=METHOD_NAMES[Method(city.method)],
        asr_school=SCHOOL_NAMES[School(city.school)],
    )
    return TimetableOut(
        version=city_timetable_version(city),
        city=city_out,
        time_zone=city.time_zone,
        days=[
            DayOut(date=day, city=city_out, times=day_times)
            for day, day_times in days.items()
        ],
    )
