from fastapi import FastAPI

from app.routes import admin, health, prayer_times

app = FastAPI(title="Miqat")
app.include_router(health.router)
app.include_router(prayer_times.router)
app.include_router(admin.router)
