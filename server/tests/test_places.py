import json

import httpx
import pytest

from app.places import NearbyMosque, PlacesClient

GOOGLE_RESPONSE = {
    "places": [
        {
            "id": "place-near",
            "displayName": {"text": "Near Masjid", "languageCode": "en"},
            "formattedAddress": "1 High Street, Solihull",
            "location": {"latitude": 52.4120, "longitude": -1.7780},
        },
        {
            "id": "place-far",
            "displayName": {"text": "Far Masjid", "languageCode": "en"},
            "formattedAddress": "9 Station Road, Birmingham",
            "location": {"latitude": 52.4800, "longitude": -1.9000},
        },
    ]
}


def client_returning(body, status_code=200, requests=None):
    def handle(request):
        if requests is not None:
            requests.append(request)
        return httpx.Response(status_code, json=body)

    return PlacesClient(
        "test-key", http=httpx.Client(transport=httpx.MockTransport(handle))
    )


def test_returns_mosques_in_the_order_google_ranks_them():
    mosques = client_returning(GOOGLE_RESPONSE).nearest_mosques(52.4128, -1.7781)

    assert mosques == [
        NearbyMosque(
            "place-near", "Near Masjid", "1 High Street, Solihull", 52.4120, -1.7780
        ),
        NearbyMosque(
            "place-far", "Far Masjid", "9 Station Road, Birmingham", 52.4800, -1.9000
        ),
    ]


def test_asks_google_for_mosques_ranked_by_distance_around_the_location():
    requests = []
    client_returning(GOOGLE_RESPONSE, requests=requests).nearest_mosques(
        52.4128, -1.7781
    )

    request = requests[0]
    body = json.loads(request.content)
    assert request.headers["X-Goog-Api-Key"] == "test-key"
    assert body["includedTypes"] == ["mosque"]
    assert body["rankPreference"] == "DISTANCE"
    assert body["locationRestriction"]["circle"]["center"] == {
        "latitude": 52.4128,
        "longitude": -1.7781,
    }


def test_returns_an_empty_list_when_no_mosques_are_nearby():
    assert client_returning({}).nearest_mosques(0.0, 0.0) == []


def test_raises_when_google_rejects_the_request():
    with pytest.raises(httpx.HTTPStatusError):
        client_returning(
            {"error": {"message": "API key not valid"}}, status_code=400
        ).nearest_mosques(0.0, 0.0)
