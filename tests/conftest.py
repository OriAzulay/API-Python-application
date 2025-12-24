"""
Shared pytest fixtures and configuration for all tests
"""
import os
import tempfile
import pytest
from fastapi.testclient import TestClient

from app.main import app
from app.config import settings
from app import database


@pytest.fixture(scope="session")
def api_key():
    """Provide the API key for authenticated requests"""
    return settings.API_KEY


@pytest.fixture
def client():
    """Create a test client for API testing with proper lifespan"""
    with TestClient(app) as client:
        yield client


@pytest.fixture
def auth_headers(api_key):
    """Provide authentication headers for protected endpoints"""
    return {"X-API-Key": api_key}


@pytest.fixture
def temp_db(monkeypatch):
    """
    Create a temporary database for isolated testing.
    Automatically cleans up after the test.
    """
    temp_file = tempfile.NamedTemporaryFile(delete=False, suffix='.db')
    temp_file.close()
    
    # Patch the database file path
    monkeypatch.setattr(settings, "DB_FILE", temp_file.name)
    
    # Initialize the temporary database
    database.init_db()
    
    yield temp_file.name
    
    # Cleanup
    try:
        os.unlink(temp_file.name)
    except OSError:
        pass


@pytest.fixture
def clean_state(client, auth_headers):
    """
    Reset the state to known values before a test.
    Useful for e2e tests that need predictable initial state.
    """
    client.post(
        "/update",
        json={"counter": 0, "message": ""},
        headers=auth_headers
    )
    yield

