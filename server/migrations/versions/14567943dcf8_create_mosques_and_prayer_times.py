"""create mosques and prayer times

Revision ID: 14567943dcf8
Revises:
Create Date: 2026-10-25 13:51:22.573899
"""

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op

revision: str = "14567943dcf8"
down_revision: str | None = None
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    op.create_table(
        "mosques",
        sa.Column("place_id", sa.String(), nullable=False),
        sa.Column("name", sa.String(), nullable=False),
        sa.Column("address", sa.String(), nullable=False),
        sa.Column("latitude", sa.Double(), nullable=False),
        sa.Column("longitude", sa.Double(), nullable=False),
        sa.Column("time_zone", sa.String(), nullable=False),
        sa.Column("timetable_version", sa.Integer(), nullable=False),
        sa.Column("timetable_updated_at", sa.DateTime(timezone=True), nullable=True),
        sa.PrimaryKeyConstraint("place_id"),
    )
    op.create_table(
        "prayer_times",
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
        sa.Column("jamaat", sa.Time(), nullable=True),
        sa.ForeignKeyConstraint(
            ["place_id"],
            ["mosques.place_id"],
        ),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint("place_id", "date", "prayer"),
    )


def downgrade() -> None:
    op.drop_table("prayer_times")
    op.drop_table("mosques")
