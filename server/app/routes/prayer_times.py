import datetime
from typing import Annotated

from fastapi import APIRouter, Depends, Header, HTTPException, Query, Response
from sqlalchemy.orm import Session

from app.aladhan import AlAdhanClient
from app.cities import city_timetable_response, city_timetable_version, city_with_times
from app.dependencies import (
    get_aladhan_client,
    get_geocoding_client,
    get_now,
    get_places_client,
    get_session,
    get_time_zone_client,
)
from app.geocoding import GeocodingClient
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
        404: {"description": "Neither a nearby mosque nor the city has times."},
    },
)
def prayer_times(
    latitude: Annotated[float, Query(ge=-90, le=90)],
    longitude: Annotated[float, Query(ge=-180, le=180)],
    response: Response,
    session: Annotated[Session, Depends(get_session)],
    places: Annotated[PlacesClient, Depends(get_places_client)],
    time_zones: Annotated[TimeZoneClient, Depends(get_time_zone_client)],
    geocoding: Annotated[GeocodingClient, Depends(get_geocoding_client)],
    aladhan: Annotated[AlAdhanClient, Depends(get_aladhan_client)],
    now: Annotated[datetime.datetime, Depends(get_now)],
    if_none_match: Annotated[str | None, Header()] = None,
):
    lookup = nearest_with_times(
        session, places.nearest_mosques(latitude, longitude), now
    )
    add_unknown_mosques(session, lookup.unknown, time_zones)
    if lookup.found is not None:
        mosque, times = lookup.found
        version = timetable_version(mosque)
        timetable = timetable_response(mosque, times, latitude, longitude)
    else:
        found = city_with_times(
            session, geocoding, time_zones, aladhan, latitude, longitude, now
        )
        if found is None:
            raise HTTPException(status_code=404, detail="Unable to get prayer times.")
        city, city_times = found
        version = city_timetable_version(city)
        timetable = city_timetable_response(city, city_times)

    etag = f'"{version}"'
    if if_none_match == etag:
        return Response(status_code=304, headers={"ETag": etag})
    response.headers["ETag"] = etag
    return timetable
