from logging.config import fileConfig

from alembic import context
from sqlalchemy import create_engine

from app import models
from app.database import DATABASE_URL

if context.config.config_file_name:
    fileConfig(context.config.config_file_name, disable_existing_loggers=False)

target_metadata = models.Base.metadata
url = context.config.get_main_option("sqlalchemy.url") or DATABASE_URL

if context.is_offline_mode():
    context.configure(url=url, target_metadata=target_metadata, literal_binds=True)
    with context.begin_transaction():
        context.run_migrations()
else:
    engine = create_engine(url)
    with engine.connect() as connection:
        context.configure(connection=connection, target_metadata=target_metadata)
        with context.begin_transaction():
            context.run_migrations()
    engine.dispose()
