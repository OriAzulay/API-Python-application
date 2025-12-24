"""
End-to-end tests against the deployed AWS infrastructure.

These tests run against the actual deployed instance from Terraform.
Requires: terraform output to have been run in the terraform/ directory.

Usage:
    # From project root, after terraform apply:
    pytest tests/e2e/test_deployed.py -v

    # Or with explicit values:
    API_URL=http://1.2.3.4:5000 API_KEY=your-key pytest tests/e2e/test_deployed.py -v
"""
import os
import json
import subprocess
import pytest
import requests


def get_terraform_output():
    """Read outputs from Terraform state"""
    try:
        result = subprocess.run(
            ["terraform", "output", "-json"],
            cwd=os.path.join(os.path.dirname(__file__), "..", "..", "terraform"),
            capture_output=True,
            text=True,
            check=True
        )
        outputs = json.loads(result.stdout)
        return {
            "api_url": outputs.get("api_url", {}).get("value"),
            "instance_ip": outputs.get("instance_public_ip", {}).get("value"),
        }
    except (subprocess.CalledProcessError, FileNotFoundError, json.JSONDecodeError):
        return None


@pytest.fixture(scope="module")
def deployed_config():
    """
    Get configuration for deployed instance.
    Tries environment variables first, then Terraform output.
    """
    # Try environment variables first (for CI/CD)
    api_url = os.getenv("API_URL")
    api_key = os.getenv("API_KEY")
    
    if not api_url:
        # Fall back to Terraform output
        tf_output = get_terraform_output()
        if tf_output and tf_output.get("api_url"):
            api_url = tf_output["api_url"]
    
    if not api_key:
        # Default key from terraform.tfvars or config
        api_key = os.getenv("API_KEY", "your-secret-api-key-12345")
    
    if not api_url:
        pytest.skip("No deployed instance available. Run 'terraform apply' first or set API_URL env var.")
    
    return {
        "api_url": api_url.rstrip("/"),
        "api_key": api_key
    }


@pytest.fixture
def api_url(deployed_config):
    return deployed_config["api_url"]


@pytest.fixture
def headers(deployed_config):
    return {"X-API-Key": deployed_config["api_key"]}


class TestDeployedInstance:
    """Tests against the live deployed AWS instance"""
    
    def test_instance_is_reachable(self, api_url):
        """Test that the deployed instance is reachable"""
        response = requests.get(f"{api_url}/", timeout=10)
        assert response.status_code == 200
    
    def test_status_endpoint(self, api_url):
        """Test status endpoint on deployed instance"""
        response = requests.get(f"{api_url}/status", timeout=10)
        assert response.status_code == 200
        
        data = response.json()
        assert "counter" in data
        assert "message" in data
        assert "timestamp" in data
        assert "uptime_seconds" in data
    
    def test_update_requires_auth(self, api_url):
        """Test that update endpoint requires authentication"""
        response = requests.post(
            f"{api_url}/update",
            json={"counter": 1},
            timeout=10
        )
        assert response.status_code == 422  # Missing header
    
    def test_update_with_auth(self, api_url, headers):
        """Test update endpoint with valid authentication"""
        response = requests.post(
            f"{api_url}/update",
            json={"counter": 999, "message": "E2E deployed test"},
            headers=headers,
            timeout=10
        )
        assert response.status_code == 200
        
        data = response.json()
        assert data["success"] is True
        assert data["new_state"]["counter"] == 999
    
    def test_status_reflects_update(self, api_url, headers):
        """Test that status reflects the update we just made"""
        # Update
        requests.post(
            f"{api_url}/update",
            json={"counter": 123, "message": "Verify test"},
            headers=headers,
            timeout=10
        )
        
        # Verify
        response = requests.get(f"{api_url}/status", timeout=10)
        data = response.json()
        
        assert data["counter"] == 123
        assert data["message"] == "Verify test"
    
    def test_logs_endpoint(self, api_url):
        """Test logs endpoint on deployed instance"""
        response = requests.get(f"{api_url}/logs", timeout=10)
        assert response.status_code == 200
        
        data = response.json()
        assert "logs" in data
        assert "total" in data
        assert isinstance(data["logs"], list)
    
    def test_logs_pagination(self, api_url):
        """Test logs pagination on deployed instance"""
        response = requests.get(f"{api_url}/logs?page=1&limit=5", timeout=10)
        assert response.status_code == 200
        
        data = response.json()
        assert data["page"] == 1
        assert data["limit"] == 5
        assert len(data["logs"]) <= 5


class TestDeployedHealthCheck:
    """Health check tests for monitoring"""
    
    def test_response_time(self, api_url):
        """Test that response time is acceptable"""
        response = requests.get(f"{api_url}/status", timeout=10)
        
        # Response should be under 2 seconds
        assert response.elapsed.total_seconds() < 2.0
    
    def test_uptime_positive(self, api_url):
        """Test that uptime is positive (app is running)"""
        response = requests.get(f"{api_url}/status", timeout=10)
        data = response.json()
        
        assert data["uptime_seconds"] > 0

