import httpx

URL = "/api/v1/analysis/climate"
GOOD = {"latitude": 7.3, "longitude": 81.8, "start_year": 1981, "end_year": 2025}


def test_analysis_response_structure(api):
    client, state = api
    response = client.get(URL, params=GOOD)
    assert response.status_code == 200
    body = response.json()
    assert set(body) == {
        "location",
        "dataset",
        "period",
        "methodology",
        "temperature",
        "precipitation",
    }
    assert body["location"]["elevation_m"] == 16.12
    assert body["dataset"]["sources"] == ["MERRA2"]
    assert body["dataset"]["time_standard"] == "LST"
    assert body["period"] == {"start_year": 1981, "end_year": 2025}

    for key in ("temperature", "precipitation"):
        section = body[key]
        assert set(section) >= {
            "annual",
            "seasonal_trend",
            "month_wise_trends",
            "anomalies",
        }
        assert section["annual"]["excluded_years"] == []
        assert len(section["annual"]["series"]) == 45
        assert section["seasonal_trend"]["status"] == "ok"
        assert len(section["month_wise_trends"]["months"]) == 12
        assert section["month_wise_trends"]["exploratory"] is True
        baseline = section["anomalies"]["baseline"]
        assert baseline["kind"] == "standard_1991_2020"
        assert (baseline["start_year"], baseline["end_year"]) == (1991, 2020)
        assert len(section["anomalies"]["anomalies"]) == 540

    temp_trend = body["temperature"]["annual_trend"]
    assert temp_trend["status"] == "ok"
    assert temp_trend["n_observations"] == 45
    assert temp_trend["slope_units_per_decade"] == "degC/decade"
    assert "not adjusted for autocorrelation" in temp_trend["ci95_note"].lower()
    prec_trend = body["precipitation"]["annual_total_trend"]
    assert prec_trend["value_units"] == "mm/year"
    first_year = body["precipitation"]["annual"]["series"][0]
    assert set(first_year) == {"year", "total_mm_per_year", "mean_rate_mm_per_day"}

    methodology = body["methodology"]
    assert methodology["hamed_rao_lag"] == 3
    assert methodology["limitations"]


def test_analysis_makes_one_upstream_request(api):
    client, state = api
    client.get(URL, params=GOOD)
    (request,) = state["requests"]
    assert request.url.path == "/api/temporal/monthly/point"
    assert dict(request.url.params)["parameters"] == "T2M,PRECTOTCORR"


def test_analysis_reports_excluded_years_for_missing_months(api, copy_of):
    client, state = api
    raw = copy_of()
    raw["properties"]["parameter"]["T2M"]["199005"] = -999.0
    state["handler"] = lambda request: httpx.Response(200, json=raw)
    body = client.get(URL, params=GOOD).json()
    excluded = body["temperature"]["annual"]["excluded_years"]
    assert [e["year"] for e in excluded] == [1990]
    assert excluded[0]["missing_months"] == [5]
    assert body["temperature"]["annual_trend"]["n_observations"] == 44
    # precipitation unaffected
    assert body["precipitation"]["annual"]["excluded_years"] == []


def test_analysis_short_period_returns_insufficient_data_not_error(api, copy_of):
    client, state = api

    def handler(request):
        # behave like NASA: only return the requested years
        start = int(request.url.params["start"])
        raw = copy_of()
        for values in raw["properties"]["parameter"].values():
            for key in list(values):
                if int(key[:4]) < start:
                    del values[key]
        return httpx.Response(200, json=raw)

    state["handler"] = handler
    response = client.get(URL, params={**GOOD, "start_year": 2020})
    assert response.status_code == 200
    body = response.json()
    assert body["period"] == {"start_year": 2020, "end_year": 2025}
    assert body["temperature"]["annual_trend"]["status"] == "insufficient_data"
    assert body["temperature"]["annual_trend"]["n_observations"] == 6
    assert body["temperature"]["seasonal_trend"]["status"] == "insufficient_data"
    assert body["temperature"]["anomalies"]["status"] == "insufficient_data"


def test_analysis_default_years(api):
    client, state = api
    client.get(URL, params={"latitude": 7.3, "longitude": 81.8})
    query = dict(state["requests"][0].url.params)
    assert (query["start"], query["end"]) == ("1981", "2025")


def test_analysis_input_validation(api):
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


def test_analysis_upstream_errors(api):
    client, state = api
    state["handler"] = lambda request: httpx.Response(500, text="boom")
    assert client.get(URL, params=GOOD).status_code == 502

    def raise_timeout(request):
        raise httpx.ReadTimeout("slow", request=request)

    state["handler"] = raise_timeout
    assert client.get(URL, params=GOOD).status_code == 504

    def raise_error(request):
        raise httpx.ConnectError("down", request=request)

    state["handler"] = raise_error
    assert client.get(URL, params=GOOD).status_code == 502

    state["handler"] = lambda request: httpx.Response(200, json={"unexpected": 1})
    assert client.get(URL, params=GOOD).status_code == 502
