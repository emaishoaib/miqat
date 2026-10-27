import httpx
import pytest

from app.geocoding import City, GeocodingClient, GeocodingError

SOLIHULL = {
    "status": "OK",
    "results": [
        {
            "place_id": "place-solihull",
            "types": ["locality", "political"],
            "address_components": [
                {
                    "long_name": "Solihull",
                    "short_name": "Solihull",
                    "types": ["locality", "political"],
                },
                {
                    "long_name": "England",
                    "short_name": "England",
                    "types": ["administrative_area_level_1", "political"],
                },
                {
                    "long_name": "United Kingdom",
                    "short_name": "GB",
                    "types": ["country", "political"],
                },
            ],
            "geometry": {"location": {"lat": 52.4118, "lng": -1.7776}},
        }
    ],
}


def client_returning(body, requests=None):
    def handle(request):
        if requests is not None:
            requests.append(request)
        return httpx.Response(200, json=body)

    return GeocodingClient(
        "test-key", http=httpx.Client(transport=httpx.MockTransport(handle))
    )


def test_returns_the_city_with_its_country_code_and_centre():
    city = client_returning(SOLIHULL).city_at(52.4128, -1.7781)

    assert city == City("place-solihull", "Solihull", "GB", 52.4118, -1.7776)


def test_asks_google_for_the_city_at_the_location_in_english_with_the_key():
    requests = []
    client_returning(SOLIHULL, requests).city_at(52.4128, -1.7781)

    params = requests[0].url.params
    assert params["latlng"] == "52.4128,-1.7781"
    assert params["result_type"] == "locality|postal_town"
    assert params["language"] == "en"
    assert params["key"] == "test-key"


def test_returns_nothing_when_the_location_is_in_no_city():
    assert client_returning({"status": "ZERO_RESULTS"}).city_at(0.0, 0.0) is None


def test_raises_when_google_refuses_the_request():
    with pytest.raises(GeocodingError):
        client_returning({"status": "REQUEST_DENIED"}).city_at(52.4128, -1.7781)
