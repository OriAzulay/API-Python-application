"""
Integration tests for API endpoints
"""
import pytest


class TestRootEndpoint:
    """Tests for the root endpoint"""
    
    def test_returns_200(self, client):
        """Test that root endpoint returns 200 OK"""
        response = client.get("/")
        assert response.status_code == 200
    
    def test_returns_api_info(self, client):
        """Test that root endpoint returns API information"""
        response = client.get("/")
        data = response.json()
        
        assert "message" in data
        assert "version" in data
        assert "endpoints" in data
    
    def test_message_is_app_name(self, client):
        """Test that message contains app name"""
        response = client.get("/")
        data = response.json()
        
        assert data["message"] == "Shared State API"
    
    def test_endpoints_documented(self, client):
        """Test that available endpoints are documented"""
        response = client.get("/")
        data = response.json()
        
        endpoints = data["endpoints"]
        assert "GET /status" in endpoints
        assert "POST /update" in endpoints
        assert "GET /logs" in endpoints


class TestStatusEndpoint:
    """Tests for the GET /status endpoint"""
    
    def test_returns_200(self, client):
        """Test that status endpoint returns 200 OK"""
        response = client.get("/status")
        assert response.status_code == 200
    
    def test_returns_required_fields(self, client):
        """Test that status returns all required fields"""
        response = client.get("/status")
        data = response.json()
        
        assert "counter" in data
        assert "message" in data
        assert "timestamp" in data
        assert "uptime_seconds" in data
    
    def test_counter_is_integer(self, client):
        """Test that counter is an integer"""
        response = client.get("/status")
        data = response.json()
        
        assert isinstance(data["counter"], int)
    
    def test_message_is_string(self, client):
        """Test that message is a string"""
        response = client.get("/status")
        data = response.json()
        
        assert isinstance(data["message"], str)
    
    def test_uptime_is_numeric(self, client):
        """Test that uptime_seconds is numeric"""
        response = client.get("/status")
        data = response.json()
        
        assert isinstance(data["uptime_seconds"], (int, float))
    
    def test_timestamp_format(self, client):
        """Test that timestamp is in ISO format with Z suffix"""
        response = client.get("/status")
        data = response.json()
        
        assert data["timestamp"].endswith("Z")


class TestUpdateEndpoint:
    """Tests for the POST /update endpoint"""
    
    def test_requires_api_key(self, client):
        """Test that update endpoint requires API key header"""
        response = client.post("/update", json={"counter": 5})
        assert response.status_code == 422  # Missing header
    
    def test_rejects_invalid_api_key(self, client):
        """Test that invalid API key is rejected"""
        response = client.post(
            "/update",
            json={"counter": 5},
            headers={"X-API-Key": "wrong-key"}
        )
        assert response.status_code == 401
    
    def test_invalid_key_error_message(self, client):
        """Test that invalid API key returns proper error message"""
        response = client.post(
            "/update",
            json={"counter": 5},
            headers={"X-API-Key": "wrong-key"}
        )
        assert "Invalid API Key" in response.json()["detail"]
    
    def test_update_counter_only(self, client, auth_headers):
        """Test updating only the counter field"""
        response = client.post(
            "/update",
            json={"counter": 10},
            headers=auth_headers
        )
        
        assert response.status_code == 200
        data = response.json()
        assert data["success"] is True
        assert data["new_state"]["counter"] == 10
    
    def test_update_message_only(self, client, auth_headers):
        """Test updating only the message field"""
        response = client.post(
            "/update",
            json={"message": "Test message"},
            headers=auth_headers
        )
        
        assert response.status_code == 200
        data = response.json()
        assert data["success"] is True
        assert data["new_state"]["message"] == "Test message"
    
    def test_update_both_fields(self, client, auth_headers):
        """Test updating both counter and message"""
        response = client.post(
            "/update",
            json={"counter": 25, "message": "Updated both"},
            headers=auth_headers
        )
        
        assert response.status_code == 200
        data = response.json()
        assert data["new_state"]["counter"] == 25
        assert data["new_state"]["message"] == "Updated both"
    
    def test_returns_old_and_new_state(self, client, auth_headers):
        """Test that response includes old and new state"""
        response = client.post(
            "/update",
            json={"counter": 100},
            headers=auth_headers
        )
        
        data = response.json()
        assert "old_state" in data
        assert "new_state" in data
        assert "counter" in data["old_state"]
        assert "message" in data["old_state"]
    
    def test_empty_request_rejected(self, client, auth_headers):
        """Test that empty request body is rejected"""
        response = client.post(
            "/update",
            json={},
            headers=auth_headers
        )
        assert response.status_code == 422
    
    def test_null_values_rejected(self, client, auth_headers):
        """Test that null values for both fields is rejected"""
        response = client.post(
            "/update",
            json={"counter": None, "message": None},
            headers=auth_headers
        )
        assert response.status_code == 422


class TestLogsEndpoint:
    """Tests for the GET /logs endpoint"""
    
    def test_returns_200(self, client):
        """Test that logs endpoint returns 200 OK"""
        response = client.get("/logs")
        assert response.status_code == 200
    
    def test_returns_required_fields(self, client):
        """Test that logs returns all required fields"""
        response = client.get("/logs")
        data = response.json()
        
        assert "logs" in data
        assert "page" in data
        assert "limit" in data
        assert "total" in data
        assert "total_pages" in data
    
    def test_logs_is_list(self, client):
        """Test that logs field is a list"""
        response = client.get("/logs")
        data = response.json()
        
        assert isinstance(data["logs"], list)
    
    def test_default_pagination(self, client):
        """Test default pagination values"""
        response = client.get("/logs")
        data = response.json()
        
        assert data["page"] == 1
        assert data["limit"] == 10
    
    def test_custom_page(self, client):
        """Test custom page parameter"""
        response = client.get("/logs?page=2")
        data = response.json()
        
        assert data["page"] == 2
    
    def test_custom_limit(self, client):
        """Test custom limit parameter"""
        response = client.get("/logs?limit=5")
        data = response.json()
        
        assert data["limit"] == 5
    
    def test_invalid_page_zero(self, client):
        """Test that page=0 is rejected"""
        response = client.get("/logs?page=0")
        assert response.status_code == 422
    
    def test_invalid_negative_page(self, client):
        """Test that negative page is rejected"""
        response = client.get("/logs?page=-1")
        assert response.status_code == 422
    
    def test_limit_too_high(self, client):
        """Test that limit > 100 is rejected"""
        response = client.get("/logs?limit=200")
        assert response.status_code == 422
    
    def test_invalid_limit_zero(self, client):
        """Test that limit=0 is rejected"""
        response = client.get("/logs?limit=0")
        assert response.status_code == 422
    
    def test_respects_limit(self, client, auth_headers):
        """Test that limit is respected in results"""
        # Create some updates to ensure logs exist
        for i in range(5):
            client.post(
                "/update",
                json={"counter": i},
                headers=auth_headers
            )
        
        response = client.get("/logs?limit=3")
        data = response.json()
        
        assert len(data["logs"]) <= 3


class TestAuthenticationDependency:
    """Tests for authentication dependency behavior"""
    
    def test_case_sensitive_header_name(self, client, api_key):
        """Test that X-API-Key header is case-insensitive (FastAPI behavior)"""
        response = client.post(
            "/update",
            json={"counter": 1},
            headers={"x-api-key": api_key}  # lowercase
        )
        # FastAPI headers are case-insensitive
        assert response.status_code == 200
    
    def test_whitespace_in_key_rejected(self, client, api_key):
        """Test that API key with extra whitespace is rejected"""
        response = client.post(
            "/update",
            json={"counter": 1},
            headers={"X-API-Key": f" {api_key} "}  # with whitespace
        )
        assert response.status_code == 401

