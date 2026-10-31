import datetime
import secrets
from typing import Annotated
from zoneinfo import ZoneInfo

from fastapi import APIRouter, Depends, Header, HTTPException, Query
from pydantic import BaseModel, HttpUrl
from sqlalchemy import func, select
from sqlalchemy.orm import Session

from app.dependencies import get_admin_token, get_now, get_places_client, get_session
from app.lookup import PRAYER_ORDER, distance_meters, timetable_version
from app.missing import DAYS_AHEAD, mosques_needing_times
from app.models import Mosque, PrayerTime
from app.places import PlacesClient
from app.timetables import save_timetable
from app.uploads import DayIn, TimeIn, TimetableIn, as_day_times, problems_with


class MosqueSummary(BaseModel):
    id: str
    name: str
    address: str
    website: str | None
    latitude: float
    longitude: float
    time_zone: str
    timetable_version: int
    timetable_updated_at: datetime.datetime | None
    first_day: datetime.date | None
    last_day: datetime.date | None


class NearbyMosqueOut(BaseModel):
    id: str
    name: str
    address: str
    distance_meters: float
    in_database: bool
    last_day: datetime.date | None


class WebsiteIn(BaseModel):
    website: HttpUrl


def require_admin(
    admin_token: Annotated[str | None, Depends(get_admin_token)],
    authorization: Annotated[str | None, Header()] = None,
) -> None:
    expected = f"Bearer {admin_token}" if admin_token else None
    if expected is None or not secrets.compare_digest(authorization or "", expected):
        raise HTTPException(status_code=401, detail="A valid admin token is required.")


router = APIRouter(
    prefix="/admin",
    dependencies=[Depends(require_admin)],
    responses={401: {"description": "The admin token is missing or wrong."}},
)

SessionDependency = Annotated[Session, Depends(get_session)]
MOSQUE_NOT_FOUND = (
    "That mosque is not in the database yet. "
    "It is added when the app looks for mosques near it."
)


def covered_days(
    session: Session, place_id: str
) -> tuple[datetime.date | None, datetime.date | None]:
    first_day, last_day = session.execute(
        select(func.min(PrayerTime.date), func.max(PrayerTime.date)).where(
            PrayerTime.place_id == place_id
        )
    ).one()
    return first_day, last_day


def summary(session: Session, mosque: Mosque) -> MosqueSummary:
    first_day, last_day = covered_days(session, mosque.place_id)
    return MosqueSummary(
        id=mosque.place_id,
        name=mosque.name,
        address=mosque.address,
        website=mosque.website,
        latitude=mosque.latitude,
        longitude=mosque.longitude,
        time_zone=mosque.time_zone,
        timetable_version=mosque.timetable_version,
        timetable_updated_at=mosque.timetable_updated_at,
        first_day=first_day,
        last_day=last_day,
    )


def mosque_or_404(session: Session, place_id: str) -> Mosque:
    mosque = session.get(Mosque, place_id)
    if mosque is None:
        raise HTTPException(status_code=404, detail=MOSQUE_NOT_FOUND)
    return mosque


@router.get("/mosques")
def search_mosques(
    search: Annotated[str, Query(min_length=1)], session: SessionDependency
) -> list[MosqueSummary]:
    mosques = session.scalars(
        select(Mosque).where(Mosque.name.ilike(f"%{search}%")).order_by(Mosque.name)
    ).all()
    return [summary(session, mosque) for mosque in mosques]


@router.get("/mosques/nearby")
def nearby_mosques(
    latitude: Annotated[float, Query(ge=-90, le=90)],
    longitude: Annotated[float, Query(ge=-180, le=180)],
    session: SessionDependency,
    places: Annotated[PlacesClient, Depends(get_places_client)],
) -> list[NearbyMosqueOut]:
    nearby = []
    for place in places.nearest_mosques(latitude, longitude):
        in_database = session.get(Mosque, place.place_id) is not None
        nearby.append(
            NearbyMosqueOut(
                id=place.place_id,
                name=place.name,
                address=place.address,
                distance_meters=distance_meters(
                    latitude, longitude, place.latitude, place.longitude
                ),
                in_database=in_database,
                last_day=covered_days(session, place.place_id)[1]
                if in_database
                else None,
            )
        )
    return nearby


@router.get("/mosques/needing-times")
def needing_times(
    session: SessionDependency,
    now: Annotated[datetime.datetime, Depends(get_now)],
    days_ahead: Annotated[int, Query(ge=0)] = DAYS_AHEAD,
) -> list[MosqueSummary]:
    return [
        summary(session, mosque)
        for mosque, _ in mosques_needing_times(session, now.date(), days_ahead)
    ]


@router.get("/mosques/{place_id}", responses={404: {"description": MOSQUE_NOT_FOUND}})
def mosque_summary(place_id: str, session: SessionDependency) -> MosqueSummary:
    return summary(session, mosque_or_404(session, place_id))


@router.get(
    "/mosques/{place_id}/timetable",
    responses={404: {"description": MOSQUE_NOT_FOUND}},
)
def read_timetable(
    place_id: str,
    session: SessionDependency,
    now: Annotated[datetime.datetime, Depends(get_now)],
    start: Annotated[datetime.date | None, Query(alias="from")] = None,
    end: Annotated[datetime.date | None, Query(alias="to")] = None,
) -> TimetableIn:
    mosque = mosque_or_404(session, place_id)
    start = start or now.astimezone(ZoneInfo(mosque.time_zone)).date()
    end = end or start
    if end < start:
        raise HTTPException(status_code=422, detail="'to' is before 'from'.")

    times = session.scalars(
        select(PrayerTime).where(
            PrayerTime.place_id == place_id,
            PrayerTime.date >= start,
            PrayerTime.date <= end,
        )
    ).all()
    days: dict[datetime.date, dict] = {}
    for time in sorted(
        times, key=lambda time: (time.date, PRAYER_ORDER.index(time.prayer))
    ):
        days.setdefault(time.date, {})[time.prayer] = TimeIn(
            begins=time.begins, jamaat=time.jamaat
        )
    return TimetableIn(
        days=[DayIn(date=day, times=day_times) for day, day_times in days.items()]
    )


@router.put(
    "/mosques/{place_id}/timetable",
    responses={
        404: {"description": MOSQUE_NOT_FOUND},
        422: {"description": "The timetable failed its checks."},
    },
)
def upload_timetable(
    place_id: str, timetable: TimetableIn, session: SessionDependency
) -> dict[str, str | int]:
    mosque = mosque_or_404(session, place_id)
    problems = problems_with(timetable)
    if problems:
        raise HTTPException(status_code=422, detail=problems)

    save_timetable(session, mosque, as_day_times(timetable))
    session.commit()
    return {"version": timetable_version(mosque), "days_saved": len(timetable.days)}


@router.put(
    "/mosques/{place_id}/website",
    responses={404: {"description": MOSQUE_NOT_FOUND}},
)
def set_website(
    place_id: str, website: WebsiteIn, session: SessionDependency
) -> MosqueSummary:
    mosque = mosque_or_404(session, place_id)
    mosque.website = str(website.website)
    mosque.timetable_version += 1
    session.commit()
    return summary(session, mosque)
