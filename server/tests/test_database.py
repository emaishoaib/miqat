import pytest

from app.database import with_psycopg_driver


@pytest.mark.parametrize(
    ("url", "expected"),
    [
        (
            "postgresql://user:secret@db.internal:5432/railway",
            "postgresql+psycopg://user:secret@db.internal:5432/railway",
        ),
        (
            "postgres://user:secret@db.internal:5432/railway",
            "postgresql+psycopg://user:secret@db.internal:5432/railway",
        ),
        (
            "postgresql+psycopg://miqat:miqat@localhost:5432/miqat",
            "postgresql+psycopg://miqat:miqat@localhost:5432/miqat",
        ),
    ],
)
def test_uses_the_psycopg_driver_for_postgres_addresses(url, expected):
    assert with_psycopg_driver(url) == expected
