"""create cities and city prayer times

Revision ID: 0b72feb9ef13
Revises: 14567943dcf8
Create Date: 2026-10-27 06:55:25.000000
"""

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op

revision: str = "0b72feb9ef13"
down_revision: str | None = "14567943dcf8"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    op.create_table(
        "cities",
        sa.Column("place_id", sa.String(), nullable=False),
        sa.Column("name", sa.String(), nullable=False),
        sa.Column("country", sa.String(), nullable=False),
        sa.Column("latitude", sa.Double(), nullable=False),
        sa.Column("longitude", sa.Double(), nullable=False),
        sa.Column("time_zone", sa.String(), nullable=False),
        sa.Column("method", sa.Integer(), nullable=False),
        sa.Column("school", sa.Integer(), nullable=False),
        sa.Column("timetable_version", sa.Integer(), nullable=False),
        sa.PrimaryKeyConstraint("place_id"),
    )
    op.create_table(
        "city_prayer_times",
        sa.Column("id", sa.Integer(), nullable=False),
        sa.Column("place_id", sa.String(), nullable=False),
        sa.Column("date", sa.Date(), nullable=False),
        sa.Column(
            "prayer",
            sa.Enum(
                "fajr",
                "sunrise",
                "dhuhr",
                "asr",
                "maghrib",
                "isha",
                name="prayer",
                native_enum=False,
            ),
            nullable=False,
        ),
        sa.Column("begins", sa.Time(), nullable=False),
        sa.ForeignKeyConstraint(
            ["place_id"],
            ["cities.place_id"],
        ),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint("place_id", "date", "prayer"),
    )


def downgrade() -> None:
    op.drop_table("city_prayer_times")
    op.drop_table("cities")
