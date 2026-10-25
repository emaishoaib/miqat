import datetime

from pydantic import BaseModel

from app.models import Prayer


class MosqueOut(BaseModel):
    id: str
    name: str
    address: str
    latitude: float
    longitude: float
    distance_meters: float


class PrayerTimeOut(BaseModel):
    prayer: Prayer
    begins: datetime.datetime
    jamaat: datetime.datetime | None


class DayOut(BaseModel):
    date: datetime.date
    times: list[PrayerTimeOut]


class TimetableOut(BaseModel):
    version: str
    mosque: MosqueOut
    time_zone: str
    days: list[DayOut]
