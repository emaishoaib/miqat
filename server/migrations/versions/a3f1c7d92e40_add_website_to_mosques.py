"""add website to mosques

Revision ID: a3f1c7d92e40
Revises: 0b72feb9ef13
Create Date: 2026-10-31 12:00:00.000000
"""

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op

revision: str = "a3f1c7d92e40"
down_revision: str | None = "0b72feb9ef13"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    op.add_column("mosques", sa.Column("website", sa.String(), nullable=True))


def downgrade() -> None:
    op.drop_column("mosques", "website")
