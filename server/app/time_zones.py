import time

import httpx

from app.places import google_api_key

TIME_ZONE_URL = "https://maps.googleapis.com/maps/api/timezone/json"


class TimeZoneLookupError(Exception):
    pass


class TimeZoneClient:
    def __init__(self, api_key: str, http: httpx.Client | None = None) -> None:
        self.api_key = api_key
        self.http = http or httpx.Client(timeout=10)

    def time_zone_at(self, latitude: float, longitude: float) -> str:
        response = self.http.get(
            TIME_ZONE_URL,
            params={
                "location": f"{latitude},{longitude}",
                "timestamp": int(time.time()),
                "key": self.api_key,
            },
        )
        response.raise_for_status()
        body = response.json()
        if body.get("status") != "OK":
            raise TimeZoneLookupError(body.get("status", "UNKNOWN"))
        return body["timeZoneId"]


def time_zone_client_from_environment() -> TimeZoneClient:
    return TimeZoneClient(google_api_key())
