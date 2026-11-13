import pytest

from app.nasa_power import NasaPowerError, parse_monthly_response


def parse(raw):
    return parse_monthly_response(raw, 7.3, 81.8, 1981, 2025)


def test_monthly_and_annual_are_separated(sample):
    result = parse(sample)
    for code in ("T2M", "PRECTOTCORR"):
        series = result.parameters[code]
        assert len(series.monthly) == 45 * 12
        assert len(series.annual) == 45
        assert all(1 <= r.month <= 12 for r in series.monthly)
        assert series.annual[0].year == 1981
        assert series.annual[-1].year == 2025
        assert series.missing_monthly_count == 0
        assert series.missing_annual_count == 0


def test_annual_value_matches_yyyy13_key(sample):
    result = parse(sample)
    raw = sample["properties"]["parameter"]["PRECTOTCORR"]
    annual = {r.year: r.value for r in result.parameters["PRECTOTCORR"].annual}
    assert annual[1981] == raw["198113"]
    january = result.parameters["PRECTOTCORR"].monthly[0]
    assert (january.year, january.month, january.value) == (1981, 1, raw["198101"])


def test_metadata_is_preserved(sample):
    result = parse(sample)
    assert result.location.longitude == 81.8
    assert result.location.latitude == 7.3
    assert result.location.elevation_m == 16.12
    assert result.location.requested_latitude == 7.3
    assert result.dataset.sources == ["MERRA2"]
    assert result.dataset.time_standard == "LST"
    assert result.dataset.fill_value == -999.0
    assert result.dataset.community == "AG"
    assert result.parameters["T2M"].units == "C"
    assert result.parameters["T2M"].long_name == "Temperature at 2 Meters"
    assert result.parameters["PRECTOTCORR"].units == "mm/day"
    assert "not a monthly" in result.parameters["PRECTOTCORR"].description


def test_fill_values_are_excluded(copy_of):
    raw = copy_of()
    t2m = raw["properties"]["parameter"]["T2M"]
    t2m["202501"] = -999.0
    t2m["202513"] = -999.0
    series = parse(raw).parameters["T2M"]
    assert series.missing_monthly_count == 1
    assert series.missing_annual_count == 1
    assert len(series.monthly) == 45 * 12 - 1
    assert len(series.annual) == 44
    assert not any(r.value == -999.0 for r in series.monthly)


def test_fill_value_is_read_from_header(copy_of):
    raw = copy_of()
    raw["header"]["fill_value"] = -9999.0
    raw["properties"]["parameter"]["T2M"]["198001"] = -9999.0
    # -999.0 is no longer the sentinel, so it is kept as a real value
    raw["properties"]["parameter"]["T2M"]["198002"] = -999.0
    series = parse(raw).parameters["T2M"]
    assert series.missing_monthly_count == 1
    months = {(r.year, r.month): r.value for r in series.monthly}
    assert (1980, 1) not in months
    assert months[(1980, 2)] == -999.0


def test_null_values_treated_as_missing(copy_of):
    raw = copy_of()
    raw["properties"]["parameter"]["T2M"]["198001"] = None
    assert parse(raw).parameters["T2M"].missing_monthly_count == 1


def test_bad_time_key_rejected(copy_of):
    raw = copy_of()
    raw["properties"]["parameter"]["T2M"]["198114"] = 1.0
    with pytest.raises(NasaPowerError):
        parse(raw)


def test_missing_structure_rejected(copy_of):
    raw = copy_of()
    del raw["header"]["fill_value"]
    with pytest.raises(NasaPowerError):
        parse(raw)


def test_missing_parameter_rejected(copy_of):
    raw = copy_of()
    del raw["properties"]["parameter"]["PRECTOTCORR"]
    with pytest.raises(NasaPowerError):
        parse(raw)
