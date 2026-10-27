from dataclasses import dataclass

import httpx

from app.places import google_api_key

GEOCODE_URL = "https://maps.googleapis.com/maps/api/geocode/json"
CITY_TYPES = ("locality", "postal_town")


class GeocodingError(Exception):
    pass


@dataclass(frozen=True)
class GeocodedCity:
    place_id: str
    name: str
    country: str
    latitude: float
    longitude: float


class GeocodingClient:
    def __init__(self, api_key: str, http: httpx.Client | None = None) -> None:
        self.api_key = api_key
        self.http = http or httpx.Client(timeout=10)

    def city_at(self, latitude: float, longitude: float) -> GeocodedCity | None:
        response = self.http.get(
            GEOCODE_URL,
            params={
                "latlng": f"{latitude},{longitude}",
                "result_type": "|".join(CITY_TYPES),
                "language": "en",
                "key": self.api_key,
            },
        )
        response.raise_for_status()
        body = response.json()
        status = body.get("status", "UNKNOWN")
        if status == "ZERO_RESULTS":
            return None
        if status != "OK":
            raise GeocodingError(status)
        result = body["results"][0]
        components = result["address_components"]
        name = next(
            part["long_name"]
            for part in components
            if any(kind in CITY_TYPES for kind in part["types"])
        )
        country = next(
            (part["short_name"] for part in components if "country" in part["types"]),
            None,
        )
        if country is None:
            return None
        location = result["geometry"]["location"]
        return GeocodedCity(
            place_id=result["place_id"],
            name=name,
            country=country,
            latitude=location["lat"],
            longitude=location["lng"],
        )


def geocoding_client_from_environment() -> GeocodingClient:
    return GeocodingClient(google_api_key())
