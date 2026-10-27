import datetime
from dataclasses import dataclass

import httpx

from app.calculation import Method, School
from app.models import Prayer

CALENDAR_URL = "https://api.aladhan.com/v1/calendar/{year}/{month}"
TIMING_NAMES = {
    Prayer.FAJR: "Fajr",
    Prayer.SUNRISE: "Sunrise",
    Prayer.DHUHR: "Dhuhr",
    Prayer.ASR: "Asr",
    Prayer.MAGHRIB: "Maghrib",
    Prayer.ISHA: "Isha",
}


@dataclass(frozen=True)
class CalculatedMonth:
    time_zone: str
    days: dict[datetime.date, dict[Prayer, datetime.time]]


class AlAdhanClient:
    def __init__(self, http: httpx.Client | None = None) -> None:
        self.http = http or httpx.Client(timeout=10)

    def month_at(
        self,
        latitude: float,
        longitude: float,
        year: int,
        month: int,
        method: Method,
        school: School,
    ) -> CalculatedMonth:
        response = self.http.get(
            CALENDAR_URL.format(year=year, month=month),
            params={
                "latitude": latitude,
                "longitude": longitude,
                "method": int(method),
                "school": int(school),
            },
        )
        response.raise_for_status()
        days = response.json()["data"]
        return CalculatedMonth(
            time_zone=days[0]["meta"]["timezone"],
            days={
                datetime.datetime.strptime(
                    day["date"]["gregorian"]["date"], "%d-%m-%Y"
                ).date(): {
                    prayer: datetime.time.fromisoformat(day["timings"][name].split()[0])
                    for prayer, name in TIMING_NAMES.items()
                }
                for day in days
            },
        )
