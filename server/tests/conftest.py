import os

import pytest
from sqlalchemy import create_engine
from sqlalchemy.orm import Session

from app.database import Base
from app.models import create_tables

TEST_DATABASE_URL = os.environ.get(
    "MIQAT_TEST_DATABASE_URL",
    "postgresql+psycopg://miqat:miqat@localhost:5432/miqat_test",
)


@pytest.fixture(scope="session")
def engine():
    engine = create_engine(TEST_DATABASE_URL)
    yield engine
    engine.dispose()


@pytest.fixture
def session(engine):
    Base.metadata.drop_all(engine)
    create_tables(engine)
    with Session(engine) as session:
        yield session
