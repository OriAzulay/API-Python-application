"""
Unit tests for app.py - FastAPI Shared State API
"""
import os
import pytest
import sqlite3
import tempfile
from fastapi.testclient import TestClient
from app import (
    app,
    init_db,
    get_current_state,
    update_state,
    get_logs,
    UpdateRequest,
    verify_api_key,
    API_KEY,
    DB_FILE
)


# Create a test client
client = TestClient(app)


# Test database initialization
def test_init_db(monkeypatch):
    """Test that database initialization creates required tables"""
    # Use a temporary database for testing
    test_db = tempfile.NamedTemporaryFile(delete=False, suffix='.db')
    test_db.close()
    
    # Temporarily replace DB_FILE using monkeypatch
    import app
    monkeypatch.setattr(app, "DB_FILE", test_db.name)
    
    # Initialize database
    app.init_db()
    
    # Verify tables exist
    conn = sqlite3.connect(test_db.name)
    cursor = conn.cursor()
    
    # Check shared_state table
    cursor.execute("SELECT name FROM sqlite_master WHERE type='table' AND name='shared_state'")
    assert cursor.fetchone() is not None, "shared_state table should exist"
    
    # Check update_logs table
    cursor.execute("SELECT name FROM sqlite_master WHERE type='table' AND name='update_logs'")
    assert cursor.fetchone() is not None, "update_logs table should exist"
    
    # Check initial state is created
    cursor.execute("SELECT COUNT(*) FROM shared_state")
    assert cursor.fetchone()[0] > 0, "Initial state should be created"
    
    conn.close()
    
    # Clean up
    os.unlink(test_db.name)


# Test root endpoint
def test_root_endpoint():
    """Test that root endpoint returns API information"""
    response = client.get("/")
    assert response.status_code == 200
    data = response.json()
    assert "message" in data
    assert "version" in data
    assert "endpoints" in data
    assert data["message"] == "Shared State API"


# Test status endpoint
def test_get_status():
    """Test that status endpoint returns current state with metadata"""
    response = client.get("/status")
    assert response.status_code == 200
    data = response.json()
    assert "counter" in data
    assert "message" in data
    assert "timestamp" in data
    assert "uptime_seconds" in data
    assert isinstance(data["counter"], int)
    assert isinstance(data["message"], str)
    assert isinstance(data["uptime_seconds"], (int, float))


# Test update endpoint without API key
def test_update_without_api_key():
    """Test that update endpoint requires API key authentication"""
    response = client.post("/update", json={"counter": 5})
    assert response.status_code == 422  # Missing header


# Test update endpoint with invalid API key
def test_update_with_invalid_api_key():
    """Test that update endpoint rejects invalid API keys"""
    response = client.post(
        "/update",
        json={"counter": 5},
        headers={"X-API-Key": "wrong-key"}
    )
    assert response.status_code == 401
    assert "Invalid API Key" in response.json()["detail"]


# Test update endpoint with valid API key - counter only
def test_update_counter_only():
    """Test updating only the counter field"""
    response = client.post(
        "/update",
        json={"counter": 10},
        headers={"X-API-Key": API_KEY}
    )
    assert response.status_code == 200
    data = response.json()
    assert data["success"] is True
    assert "old_state" in data
    assert "new_state" in data
    assert data["new_state"]["counter"] == 10


# Test update endpoint with valid API key - message only
def test_update_message_only():
    """Test updating only the message field"""
    response = client.post(
        "/update",
        json={"message": "Test message"},
        headers={"X-API-Key": API_KEY}
    )
    assert response.status_code == 200
    data = response.json()
    assert data["success"] is True
    assert data["new_state"]["message"] == "Test message"


# Test update endpoint with valid API key - both fields
def test_update_both_fields():
    """Test updating both counter and message fields"""
    response = client.post(
        "/update",
        json={"counter": 25, "message": "Updated both"},
        headers={"X-API-Key": API_KEY}
    )
    assert response.status_code == 200
    data = response.json()
    assert data["success"] is True
    assert data["new_state"]["counter"] == 25
    assert data["new_state"]["message"] == "Updated both"


# Test update endpoint with empty request
def test_update_empty_request():
    """Test that update endpoint requires at least one field"""
    response = client.post(
        "/update",
        json={},
        headers={"X-API-Key": API_KEY}
    )
    assert response.status_code == 422  # Validation error


# Test logs endpoint - default pagination
def test_get_logs_default():
    """Test that logs endpoint returns paginated logs with default values"""
    response = client.get("/logs")
    assert response.status_code == 200
    data = response.json()
    assert "logs" in data
    assert "page" in data
    assert "limit" in data
    assert "total" in data
    assert "total_pages" in data
    assert isinstance(data["logs"], list)
    assert data["page"] == 1
    assert data["limit"] == 10


# Test logs endpoint - custom pagination
def test_get_logs_with_pagination():
    """Test that logs endpoint respects pagination parameters"""
    response = client.get("/logs?page=1&limit=5")
    assert response.status_code == 200
    data = response.json()
    assert data["page"] == 1
    assert data["limit"] == 5
    assert len(data["logs"]) <= 5


# Test logs endpoint - invalid page number
def test_get_logs_invalid_page():
    """Test that logs endpoint rejects invalid page numbers"""
    response = client.get("/logs?page=0")
    assert response.status_code == 422  # Validation error


# Test logs endpoint - limit too high
def test_get_logs_limit_too_high():
    """Test that logs endpoint enforces maximum limit"""
    response = client.get("/logs?limit=200")
    assert response.status_code == 422  # Validation error (max is 100)


# Test UpdateRequest model validation - counter must be integer
def test_update_request_counter_validation():
    """Test that UpdateRequest validates counter as integer"""
    with pytest.raises(ValueError):
        UpdateRequest(counter="not-an-int", message="test")


# Test UpdateRequest model validation - message must be string
def test_update_request_message_validation():
    """Test that UpdateRequest validates message as string"""
    with pytest.raises(ValueError):
        UpdateRequest(counter=1, message=123)


# Test UpdateRequest model validation - at least one field required
def test_update_request_at_least_one_field():
    """Test that UpdateRequest requires at least one field"""
    with pytest.raises(ValueError):
        UpdateRequest(counter=None, message=None)


# Test get_current_state helper function
def test_get_current_state():
    """Test that get_current_state returns current state from database"""
    state = get_current_state()
    assert "counter" in state
    assert "message" in state
    assert isinstance(state["counter"], int)
    assert isinstance(state["message"], str)


# Test update_state helper function
def test_update_state_helper():
    """Test that update_state helper function updates database correctly"""
    # Get initial state
    initial_state = get_current_state()
    
    # Update state
    result = update_state(counter=99, message="Helper test")
    
    # Verify result structure
    assert "old_counter" in result
    assert "new_counter" in result
    assert "old_message" in result
    assert "new_message" in result
    assert result["new_counter"] == 99
    assert result["new_message"] == "Helper test"
    
    # Verify state was actually updated
    current_state = get_current_state()
    assert current_state["counter"] == 99
    assert current_state["message"] == "Helper test"


# Test get_logs helper function
def test_get_logs_helper():
    """Test that get_logs helper function returns paginated logs"""
    result = get_logs(page=1, limit=10)
    assert "logs" in result
    assert "page" in result
    assert "limit" in result
    assert "total" in result
    assert "total_pages" in result
    assert isinstance(result["logs"], list)
    assert result["page"] == 1
    assert result["limit"] == 10


# Test that logs are created when state is updated
def test_logs_created_on_update():
    """Test that updating state creates log entries"""
    # Get initial log count
    initial_logs = get_logs()
    initial_count = initial_logs["total"]
    
    # Make an update
    client.post(
        "/update",
        json={"counter": 42, "message": "Log test"},
        headers={"X-API-Key": API_KEY}
    )
    
    # Check that log count increased
    updated_logs = get_logs()
    assert updated_logs["total"] > initial_count


# Test status reflects updates
def test_status_reflects_updates():
    """Test that status endpoint reflects the latest state updates"""
    # Update state
    client.post(
        "/update",
        json={"counter": 77, "message": "Status test"},
        headers={"X-API-Key": API_KEY}
    )
    
    # Check status
    response = client.get("/status")
    assert response.status_code == 200
    data = response.json()
    assert data["counter"] == 77
    assert data["message"] == "Status test"


if __name__ == "__main__":
    pytest.main([__file__, "-v"])

