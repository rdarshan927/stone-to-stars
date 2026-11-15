"""CORS coverage for the deployed frontend and Flutter Web development."""

import pytest
from fastapi.testclient import TestClient

from app.main import app


@pytest.fixture
def client() -> TestClient:
    return TestClient(app, raise_server_exceptions=True)


# ---------------------------------------------------------------------------
# Actual cross-origin requests (GET with Origin header)
# ---------------------------------------------------------------------------


@pytest.mark.parametrize(
    "origin",
    [
        "http://localhost:36459",   # Flutter Web dynamic port (the specified case)
        "http://localhost:5000",
        "http://localhost",
        "http://127.0.0.1:8080",
        "http://127.0.0.1",
        "https://senku-stone-to-star.netlify.app",
    ],
)
def test_cors_allowed_origins_receive_acao_header(client: TestClient, origin: str):
    """A GET from an allowed origin must echo the origin back."""
    response = client.get("/health", headers={"Origin": origin})
    assert response.status_code == 200
    acao = response.headers.get("access-control-allow-origin")
    assert acao == origin, (
        f"Expected Access-Control-Allow-Origin: {origin!r}, got {acao!r}"
    )


@pytest.mark.parametrize(
    "origin",
    [
        "http://localhost:36459",  # the specifically requested case
        "http://127.0.0.1:9000",
        "https://senku-stone-to-star.netlify.app",
    ],
)
def test_cors_preflight_allowed(client: TestClient, origin: str):
    """OPTIONS preflight for an allowed origin returns 200 with CORS headers."""
    response = client.options(
        "/health",
        headers={
            "Origin": origin,
            "Access-Control-Request-Method": "GET",
            "Access-Control-Request-Headers": "Content-Type",
        },
    )
    assert response.status_code == 200
    assert response.headers.get("access-control-allow-origin") == origin
    assert response.headers.get("access-control-allow-methods") is not None


# ---------------------------------------------------------------------------
# Disallowed origins must NOT receive the ACAO header
# ---------------------------------------------------------------------------


@pytest.mark.parametrize(
    "origin",
    [
        "https://localhost:3000",          # https scheme not allowed
        "http://evil.example.com",         # external host
        "http://notlocalhost:8080",        # hostname contains 'localhost' but isn't
        "http://192.168.1.100:5000",       # LAN IP — not in regex
        "https://senku-stone-to-star.netlify.app.evil.example",
        "http://senku-stone-to-star.netlify.app",
    ],
)
def test_cors_disallowed_origins_have_no_acao_header(
    client: TestClient, origin: str
):
    """Requests from disallowed origins must not receive an ACAO header."""
    response = client.get("/health", headers={"Origin": origin})
    # The response itself succeeds (server-side — CORS is a browser enforcement),
    # but the ACAO header must be absent or not match the origin.
    acao = response.headers.get("access-control-allow-origin")
    assert acao != origin, (
        f"Origin {origin!r} should not be allowed, but got ACAO: {acao!r}"
    )


# ---------------------------------------------------------------------------
# Credentials must NOT be allowed (allow_credentials=False)
# ---------------------------------------------------------------------------


def test_cors_credentials_not_allowed(client: TestClient):
    """Access-Control-Allow-Credentials must not be 'true'."""
    response = client.get(
        "/health", headers={"Origin": "http://localhost:36459"}
    )
    acac = response.headers.get("access-control-allow-credentials", "")
    assert acac.lower() != "true", (
        "allow_credentials=False but header says 'true'"
    )
