from collections.abc import AsyncIterator
from contextlib import asynccontextmanager

from fastapi import FastAPI

from app.database import engine
from app.models import create_tables
from app.routes import health, prayer_times


@asynccontextmanager
async def lifespan(app: FastAPI) -> AsyncIterator[None]:
    create_tables(engine)
    yield


app = FastAPI(title="Miqat", lifespan=lifespan)
app.include_router(health.router)
app.include_router(prayer_times.router)
