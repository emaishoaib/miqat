import os

from sqlalchemy import create_engine
from sqlalchemy.orm import DeclarativeBase, sessionmaker

PSYCOPG_PREFIX = "postgresql+psycopg://"


def with_psycopg_driver(url: str) -> str:
    for prefix in ("postgres://", "postgresql://"):
        if url.startswith(prefix):
            return PSYCOPG_PREFIX + url.removeprefix(prefix)
    return url


DATABASE_URL = with_psycopg_driver(
    os.environ.get(
        "MIQAT_DATABASE_URL", f"{PSYCOPG_PREFIX}miqat:miqat@localhost:5432/miqat"
    )
)

engine = create_engine(DATABASE_URL)
SessionLocal = sessionmaker(engine)


class Base(DeclarativeBase):
    pass
