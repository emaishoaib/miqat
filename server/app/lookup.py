import datetime
import math
from zoneinfo import ZoneInfo

from sqlalchemy import select
from sqlalchemy.orm import Session

from app.models import Mosque, Prayer, PrayerTime
from app.places import NearbyMosque
from app.schemas import DayOut, MosqueOut, PrayerTimeOut, TimetableOut

PRAYER_ORDER = list(Prayer)
EARTH_RADIUS_METERS = 6_371_000


def nearest_with_times(
    session: Session, nearby: list[NearbyMosque], now: datetime.datetime
) -> tuple[Mosque, list[PrayerTime]] | None:
    for candidate in nearby:
        mosque = session.get(Mosque, candidate.place_id)
        if mosque is None:
            continue
        times = upcoming_times(session, mosque, now)
        if times:
            return mosque, times
    return None


def upcoming_times(
    session: Session, mosque: Mosque, now: datetime.datetime
) -> list[PrayerTime]:
    today = now.astimezone(ZoneInfo(mosque.time_zone)).date()
    times = session.scalars(
        select(PrayerTime).where(
            PrayerTime.place_id == mosque.place_id, PrayerTime.date >= today
        )
    ).all()
    return sorted(times, key=lambda time: (time.date, PRAYER_ORDER.index(time.prayer)))


def timetable_version(mosque: Mosque) -> str:
    return f"{mosque.place_id}:{mosque.timetable_version}"


def timetable_response(
    mosque: Mosque, times: list[PrayerTime], latitude: float, longitude: float
) -> TimetableOut:
    zone = ZoneInfo(mosque.time_zone)
    days: dict[datetime.date, list[PrayerTimeOut]] = {}
    for time in times:
        days.setdefault(time.date, []).append(
            PrayerTimeOut(
                prayer=time.prayer,
                begins=datetime.datetime.combine(time.date, time.begins, zone),
                jamaat=datetime.datetime.combine(time.date, time.jamaat, zone)
                if time.jamaat
                else None,
            )
        )
    return TimetableOut(
        version=timetable_version(mosque),
        mosque=MosqueOut(
            id=mosque.place_id,
            name=mosque.name,
            address=mosque.address,
            latitude=mosque.latitude,
            longitude=mosque.longitude,
            distance_meters=distance_meters(
                latitude, longitude, mosque.latitude, mosque.longitude
            ),
        ),
        time_zone=mosque.time_zone,
        days=[DayOut(date=day, times=day_times) for day, day_times in days.items()],
    )


def distance_meters(
    latitude: float, longitude: float, other_latitude: float, other_longitude: float
) -> float:
    lat1, lon1, lat2, lon2 = map(
        math.radians, (latitude, longitude, other_latitude, other_longitude)
    )
    a = (
        math.sin((lat2 - lat1) / 2) ** 2
        + math.cos(lat1) * math.cos(lat2) * math.sin((lon2 - lon1) / 2) ** 2
    )
    return 2 * EARTH_RADIUS_METERS * math.asin(math.sqrt(a))
