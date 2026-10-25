import datetime
from typing import Annotated

from fastapi import APIRouter, Depends, Header, HTTPException, Query, Response
from sqlalchemy.orm import Session

from app.dependencies import (
    get_now,
    get_places_client,
    get_session,
    get_time_zone_client,
)
from app.lookup import (
    add_unknown_mosques,
    nearest_with_times,
    timetable_response,
    timetable_version,
)
from app.places import PlacesClient
from app.schemas import TimetableOut
from app.time_zones import TimeZoneClient

router = APIRouter()


@router.get(
    "/prayer-times",
    response_model=TimetableOut,
    responses={
        304: {"description": "The timetable has not changed since the given version."},
        404: {"description": "No nearby mosque has upcoming prayer times."},
    },
)
def prayer_times(
    latitude: Annotated[float, Query(ge=-90, le=90)],
    longitude: Annotated[float, Query(ge=-180, le=180)],
    response: Response,
    session: Annotated[Session, Depends(get_session)],
    places: Annotated[PlacesClient, Depends(get_places_client)],
    time_zones: Annotated[TimeZoneClient, Depends(get_time_zone_client)],
    now: Annotated[datetime.datetime, Depends(get_now)],
    if_none_match: Annotated[str | None, Header()] = None,
):
    lookup = nearest_with_times(
        session, places.nearest_mosques(latitude, longitude), now
    )
    add_unknown_mosques(session, lookup.unknown, time_zones)
    if lookup.found is None:
        raise HTTPException(
            status_code=404, detail="No nearby mosque has upcoming prayer times."
        )
    mosque, times = lookup.found

    etag = f'"{timetable_version(mosque)}"'
    if if_none_match == etag:
        return Response(status_code=304, headers={"ETag": etag})
    response.headers["ETag"] = etag
    return timetable_response(mosque, times, latitude, longitude)
