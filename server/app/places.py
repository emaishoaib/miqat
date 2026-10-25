import os
import sys
from dataclasses import dataclass

import httpx

SEARCH_NEARBY_URL = "https://places.googleapis.com/v1/places:searchNearby"
FIELD_MASK = "places.id,places.displayName,places.formattedAddress,places.location"
MAX_RADIUS_METERS = 50_000.0
MAX_RESULTS = 20


@dataclass(frozen=True)
class NearbyMosque:
    place_id: str
    name: str
    address: str
    latitude: float
    longitude: float


class PlacesClient:
    def __init__(self, api_key: str, http: httpx.Client | None = None) -> None:
        self.api_key = api_key
        self.http = http or httpx.Client(timeout=10)

    def nearest_mosques(self, latitude: float, longitude: float) -> list[NearbyMosque]:
        response = self.http.post(
            SEARCH_NEARBY_URL,
            headers={"X-Goog-Api-Key": self.api_key, "X-Goog-FieldMask": FIELD_MASK},
            json={
                "includedTypes": ["mosque"],
                "maxResultCount": MAX_RESULTS,
                "rankPreference": "DISTANCE",
                "locationRestriction": {
                    "circle": {
                        "center": {"latitude": latitude, "longitude": longitude},
                        "radius": MAX_RADIUS_METERS,
                    }
                },
            },
        )
        response.raise_for_status()
        return [
            NearbyMosque(
                place_id=place["id"],
                name=place["displayName"]["text"],
                address=place.get("formattedAddress", ""),
                latitude=place["location"]["latitude"],
                longitude=place["location"]["longitude"],
            )
            for place in response.json().get("places", [])
        ]


def google_api_key() -> str:
    api_key = os.environ.get("GOOGLE_PLACES_API_KEY")
    if not api_key:
        raise RuntimeError(
            "Set GOOGLE_PLACES_API_KEY to a Google Cloud key with the Places API "
            "and the Time Zone API enabled."
        )
    return api_key


def places_client_from_environment() -> PlacesClient:
    return PlacesClient(google_api_key())


if __name__ == "__main__":
    for mosque in places_client_from_environment().nearest_mosques(
        float(sys.argv[1]), float(sys.argv[2])
    ):
        print(f"{mosque.place_id}  {mosque.name}  ({mosque.address})")
