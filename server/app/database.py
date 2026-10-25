import os

from sqlalchemy import create_engine
from sqlalchemy.orm import DeclarativeBase, sessionmaker

DATABASE_URL = os.environ.get(
    "MIQAT_DATABASE_URL", "postgresql+psycopg://miqat:miqat@localhost:5432/miqat"
)

engine = create_engine(DATABASE_URL)
SessionLocal = sessionmaker(engine)


class Base(DeclarativeBase):
    pass
