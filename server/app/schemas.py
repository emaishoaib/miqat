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


class CityOut(BaseModel):
    id: str
    name: str


class PrayerTimeOut(BaseModel):
    prayer: Prayer
    begins: datetime.datetime
    jamaat: datetime.datetime | None


class DayOut(BaseModel):
    date: datetime.date
    times: list[PrayerTimeOut]


class TimetableOut(BaseModel):
    version: str
    mosque: MosqueOut | None = None
    city: CityOut | None = None
    time_zone: str
    days: list[DayOut]
