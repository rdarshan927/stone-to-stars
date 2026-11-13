import httpx
from fastapi.testclient import TestClient

from app.main import app

URL = "/api/v1/climate/monthly"
GOOD = {"latitude": 7.3, "longitude": 81.8, "start_year": 1981, "end_year": 2025}


def test_existing_endpoints_still_work():
    client = TestClient(app)
    assert client.get("/").json()["name"] == "Stone to Stars"
    assert client.get("/health").json() == {"status": "healthy"}


def test_monthly_endpoint_structure(api):
    client, state = api
    response = client.get(URL, params=GOOD)
    assert response.status_code == 200
    body = response.json()
    assert set(body) == {"location", "dataset", "period", "parameters"}
    assert body["period"] == {"start_year": 1981, "end_year": 2025}
    assert body["location"]["elevation_m"] == 16.12
    assert body["dataset"]["sources"] == ["MERRA2"]
    assert body["dataset"]["time_standard"] == "LST"
    assert set(body["parameters"]) == {"T2M", "PRECTOTCORR"}
    t2m = body["parameters"]["T2M"]
    assert len(t2m["monthly"]) == 540
    assert len(t2m["annual"]) == 45
    assert set(t2m["monthly"][0]) == {"year", "month", "value"}
    assert t2m["units"] == "C"


def test_upstream_request_parameters(api):
    client, state = api
    client.get(URL, params=GOOD)
    (request,) = state["requests"]
    query = dict(request.url.params)
    assert request.url.path == "/api/temporal/monthly/point"
    assert query["parameters"] == "T2M,PRECTOTCORR"
    assert query["community"] == "AG"
    assert query["latitude"] == "7.3"
    assert query["longitude"] == "81.8"
    assert query["start"] == "1981"
    assert query["end"] == "2025"
    assert query["format"] == "JSON"


def test_default_years(api):
    client, state = api
    client.get(URL, params={"latitude": 7.3, "longitude": 81.8})
    query = dict(state["requests"][0].url.params)
    assert (query["start"], query["end"]) == ("1981", "2025")


def test_input_validation(api):
    client, state = api
    bad_cases = [
        {**GOOD, "latitude": 95},
        {**GOOD, "longitude": -181},
        {**GOOD, "start_year": 1980},
        {**GOOD, "end_year": 2026},
        {**GOOD, "start_year": 2000, "end_year": 1999},
        {"longitude": 81.8},
        {**GOOD, "latitude": "abc"},
    ]
    for params in bad_cases:
        assert client.get(URL, params=params).status_code == 422, params
    assert state["requests"] == []


def test_upstream_http_error_becomes_502(api):
    client, state = api
    state["handler"] = lambda request: httpx.Response(500, text="boom")
    response = client.get(URL, params=GOOD)
    assert response.status_code == 502
    assert "500" in response.json()["detail"]


def test_upstream_timeout_becomes_504(api):
    client, state = api

    def raise_timeout(request):
        raise httpx.ReadTimeout("slow", request=request)

    state["handler"] = raise_timeout
    assert client.get(URL, params=GOOD).status_code == 504


def test_upstream_network_error_becomes_502(api):
    client, state = api

    def raise_error(request):
        raise httpx.ConnectError("down", request=request)

    state["handler"] = raise_error
    assert client.get(URL, params=GOOD).status_code == 502


def test_malformed_upstream_body_becomes_502(api):
    client, state = api
    state["handler"] = lambda request: httpx.Response(200, json={"unexpected": 1})
    assert client.get(URL, params=GOOD).status_code == 502
    state["handler"] = lambda request: httpx.Response(200, text="not json")
    assert client.get(URL, params=GOOD).status_code == 502
