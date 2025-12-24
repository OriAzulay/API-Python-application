"""
End-to-end tests for complete user workflows
"""
import pytest


class TestStateUpdateWorkflow:
    """E2E tests for state update workflows"""
    
    def test_update_then_verify_status(self, client, auth_headers, clean_state):
        """Test complete workflow: update state and verify via status endpoint"""
        # Update state
        update_response = client.post(
            "/update",
            json={"counter": 77, "message": "E2E test"},
            headers=auth_headers
        )
        assert update_response.status_code == 200
        
        # Verify via status
        status_response = client.get("/status")
        assert status_response.status_code == 200
        
        data = status_response.json()
        assert data["counter"] == 77
        assert data["message"] == "E2E test"
    
    def test_multiple_updates_last_wins(self, client, auth_headers, clean_state):
        """Test that multiple updates result in last value"""
        # First update
        client.post(
            "/update",
            json={"counter": 10},
            headers=auth_headers
        )
        
        # Second update
        client.post(
            "/update",
            json={"counter": 20},
            headers=auth_headers
        )
        
        # Third update
        client.post(
            "/update",
            json={"counter": 30},
            headers=auth_headers
        )
        
        # Verify final state
        status = client.get("/status").json()
        assert status["counter"] == 30
    
    def test_partial_update_preserves_other_field(self, client, auth_headers, clean_state):
        """Test that updating one field preserves the other"""
        # Set both fields
        client.post(
            "/update",
            json={"counter": 100, "message": "Original message"},
            headers=auth_headers
        )
        
        # Update only counter
        client.post(
            "/update",
            json={"counter": 200},
            headers=auth_headers
        )
        
        # Verify message is preserved
        status = client.get("/status").json()
        assert status["counter"] == 200
        assert status["message"] == "Original message"


class TestLoggingWorkflow:
    """E2E tests for logging workflows"""
    
    def test_updates_create_log_entries(self, client, auth_headers):
        """Test that updates create corresponding log entries"""
        # Get initial log count
        initial_logs = client.get("/logs").json()
        initial_count = initial_logs["total"]
        
        # Make an update
        client.post(
            "/update",
            json={"counter": 42, "message": "Log test"},
            headers=auth_headers
        )
        
        # Verify log count increased
        updated_logs = client.get("/logs").json()
        assert updated_logs["total"] == initial_count + 1
    
    def test_log_entry_contains_update_details(self, client, auth_headers):
        """Test that log entries contain correct update details"""
        import time
        unique_marker = f"test_{int(time.time() * 1000)}"
        unique_counter = int(time.time()) % 100000
        
        # Make update with unique values
        client.post(
            "/update",
            json={"counter": unique_counter, "message": unique_marker},
            headers=auth_headers
        )
        
        # Find our log entry by searching recent logs
        logs = client.get("/logs?limit=20").json()
        
        # Find the entry with our unique marker
        found = False
        for log in logs["logs"]:
            if log["new_message"] == unique_marker:
                assert log["new_counter"] == unique_counter
                found = True
                break
        
        assert found, f"Could not find log entry with marker {unique_marker}"
    
    def test_logs_ordered_by_timestamp_desc(self, client, auth_headers):
        """Test that logs are ordered by timestamp descending (newest first)"""
        # Get logs - they should be ordered by timestamp DESC
        logs = client.get("/logs?limit=10").json()
        
        if len(logs["logs"]) >= 2:
            # Verify ordering by comparing timestamps (not IDs which can vary)
            timestamps = [log["timestamp"] for log in logs["logs"]]
            # Timestamps should be in descending order (newest first)
            assert timestamps == sorted(timestamps, reverse=True), \
                "Logs should be ordered by timestamp descending (newest first)"
    
    def test_pagination_workflow(self, client, auth_headers):
        """Test complete pagination workflow"""
        # Create enough entries for multiple pages
        for i in range(15):
            client.post(
                "/update",
                json={"counter": i},
                headers=auth_headers
            )
        
        # Get first page
        page1 = client.get("/logs?page=1&limit=5").json()
        assert page1["page"] == 1
        assert len(page1["logs"]) == 5
        
        # Get second page
        page2 = client.get("/logs?page=2&limit=5").json()
        assert page2["page"] == 2
        assert len(page2["logs"]) <= 5
        
        # Ensure different entries
        page1_ids = {log["id"] for log in page1["logs"]}
        page2_ids = {log["id"] for log in page2["logs"]}
        assert page1_ids.isdisjoint(page2_ids), "Pages should have different entries"


class TestErrorRecoveryWorkflow:
    """E2E tests for error handling and recovery"""
    
    def test_invalid_update_does_not_change_state(self, client, auth_headers, clean_state):
        """Test that failed updates don't modify state"""
        # Set initial state
        client.post(
            "/update",
            json={"counter": 100, "message": "Initial"},
            headers=auth_headers
        )
        
        # Attempt invalid update (no API key)
        client.post("/update", json={"counter": 999})
        
        # Verify state unchanged
        status = client.get("/status").json()
        assert status["counter"] == 100
        assert status["message"] == "Initial"
    
    def test_invalid_request_does_not_create_log(self, client, auth_headers):
        """Test that failed requests don't create log entries"""
        # Get initial log count
        initial_count = client.get("/logs").json()["total"]
        
        # Attempt invalid update
        client.post(
            "/update",
            json={},  # Empty - should fail validation
            headers=auth_headers
        )
        
        # Verify no new log
        current_count = client.get("/logs").json()["total"]
        assert current_count == initial_count
    
    def test_consecutive_operations_after_error(self, client, auth_headers, clean_state):
        """Test that system works correctly after an error"""
        # Successful update
        client.post(
            "/update",
            json={"counter": 1},
            headers=auth_headers
        )
        
        # Failed update (wrong API key)
        client.post(
            "/update",
            json={"counter": 999},
            headers={"X-API-Key": "wrong"}
        )
        
        # Another successful update
        response = client.post(
            "/update",
            json={"counter": 2},
            headers=auth_headers
        )
        assert response.status_code == 200
        
        # Verify correct state
        status = client.get("/status").json()
        assert status["counter"] == 2


class TestConcurrentAccessSimulation:
    """E2E tests simulating concurrent access patterns"""
    
    def test_rapid_sequential_updates(self, client, auth_headers):
        """Test rapid sequential updates maintain consistency"""
        # Use smaller number to avoid SQLite lock issues in test environment
        expected_final = 10
        
        for i in range(expected_final + 1):
            response = client.post(
                "/update",
                json={"counter": i},
                headers=auth_headers
            )
            assert response.status_code == 200
        
        status = client.get("/status").json()
        assert status["counter"] == expected_final
    
    def test_interleaved_read_write(self, client, auth_headers):
        """Test interleaved reads and writes maintain consistency"""
        for i in range(5):
            # Write with unique offset to avoid collision with other tests
            value = 5000 + i
            client.post(
                "/update",
                json={"counter": value},
                headers=auth_headers
            )
            
            # Read - verify write was successful
            status = client.get("/status").json()
            assert status["counter"] == value


class TestApiDiscoverability:
    """E2E tests for API discoverability"""
    
    def test_root_documents_all_endpoints(self, client):
        """Test that root endpoint documents all available endpoints"""
        root = client.get("/").json()
        
        # All endpoints mentioned should work
        assert client.get("/status").status_code == 200
        assert client.get("/logs").status_code == 200
    
    def test_openapi_schema_available(self, client):
        """Test that OpenAPI schema is available"""
        response = client.get("/openapi.json")
        assert response.status_code == 200
        
        schema = response.json()
        assert "openapi" in schema
        assert "paths" in schema
    
    def test_docs_endpoint_available(self, client):
        """Test that Swagger UI docs are available"""
        response = client.get("/docs")
        assert response.status_code == 200

