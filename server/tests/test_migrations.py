from alembic import command
from sqlalchemy import inspect, text

from app.database import Base


def start_empty(engine):
    Base.metadata.drop_all(engine)
    with engine.begin() as connection:
        connection.execute(text("DROP TABLE IF EXISTS alembic_version"))


def test_migrations_build_the_same_tables_as_the_models(engine, alembic_config):
    start_empty(engine)

    command.upgrade(alembic_config, "head")

    command.check(alembic_config)
    assert {"mosques", "prayer_times"} <= set(inspect(engine).get_table_names())


def test_migrations_can_be_undone(engine, alembic_config):
    start_empty(engine)
    command.upgrade(alembic_config, "head")

    command.downgrade(alembic_config, "base")

    assert not {"mosques", "prayer_times"} & set(inspect(engine).get_table_names())
