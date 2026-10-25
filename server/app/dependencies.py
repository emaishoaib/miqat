import datetime
from collections.abc import Iterator
from functools import cache

from sqlalchemy.orm import Session

from app.database import SessionLocal
from app.places import PlacesClient, places_client_from_environment


def get_session() -> Iterator[Session]:
    with SessionLocal() as session:
        yield session


@cache
def get_places_client() -> PlacesClient:
    return places_client_from_environment()


def get_now() -> datetime.datetime:
    return datetime.datetime.now(datetime.UTC)
