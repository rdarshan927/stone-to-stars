import copy
import json
from pathlib import Path

import httpx
import pytest
from fastapi.testclient import TestClient

from app import climate
from app.main import app

SAMPLE_PATH = (
    Path(__file__).resolve().parents[1]
    / "data"
    / "samples"
    / "nasa_power_monthly_sample.json"
)


@pytest.fixture
def sample() -> dict:
    return json.loads(SAMPLE_PATH.read_text())


@pytest.fixture
def api(sample, monkeypatch):
    """TestClient whose NASA POWER calls are served by a mock transport."""
    monkeypatch.setattr(climate, "last_complete_year", lambda: 2025)
    state = {"handler": lambda request: httpx.Response(200, json=sample), "requests": []}

    def handler(request: httpx.Request) -> httpx.Response:
        state["requests"].append(request)
        return state["handler"](request)

    async def override_client():
        async with httpx.AsyncClient(transport=httpx.MockTransport(handler)) as c:
            yield c

    app.dependency_overrides[climate.get_http_client] = override_client
    yield TestClient(app), state
    app.dependency_overrides.clear()


@pytest.fixture
def copy_of(sample):
    return lambda: copy.deepcopy(sample)
