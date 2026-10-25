from fastapi import FastAPI

from app.routes import health

app = FastAPI(title="Miqat")
app.include_router(health.router)
