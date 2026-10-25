import datetime
from typing import Annotated

from fastapi import APIRouter, Depends, Header, HTTPException, Query, Response
from sqlalchemy.orm import Session

from app.dependencies import get_now, get_places_client, get_session
from app.lookup import nearest_with_times, timetable_response, timetable_version
from app.places import PlacesClient
from app.schemas import TimetableOut

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
    now: Annotated[datetime.datetime, Depends(get_now)],
    if_none_match: Annotated[str | None, Header()] = None,
):
    found = nearest_with_times(
        session, places.nearest_mosques(latitude, longitude), now
    )
    if found is None:
        raise HTTPException(
            status_code=404, detail="No nearby mosque has upcoming prayer times."
        )
    mosque, times = found

    etag = f'"{timetable_version(mosque)}"'
    if if_none_match == etag:
        return Response(status_code=304, headers={"ETag": etag})
    response.headers["ETag"] = etag
    return timetable_response(mosque, times, latitude, longitude)
