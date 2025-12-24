"""
Unit tests for Pydantic schemas/models
"""
import pytest
from pydantic import ValidationError

from app.schemas import UpdateRequest, StatusResponse, LogEntry, LogsResponse


class TestUpdateRequest:
    """Tests for UpdateRequest model validation"""
    
    def test_valid_counter_only(self):
        """Test valid request with counter only"""
        request = UpdateRequest(counter=5)
        assert request.counter == 5
        assert request.message is None
    
    def test_valid_message_only(self):
        """Test valid request with message only"""
        request = UpdateRequest(message="hello")
        assert request.message == "hello"
        assert request.counter is None
    
    def test_valid_both_fields(self):
        """Test valid request with both fields"""
        request = UpdateRequest(counter=10, message="test")
        assert request.counter == 10
        assert request.message == "test"
    
    def test_counter_must_be_integer(self):
        """Test that counter validates as integer"""
        with pytest.raises(ValidationError):
            UpdateRequest(counter="not-an-int", message="test")
    
    def test_message_must_be_string(self):
        """Test that message validates as string"""
        with pytest.raises(ValidationError):
            UpdateRequest(counter=1, message=123)
    
    def test_at_least_one_field_required(self):
        """Test that at least one field must be provided"""
        with pytest.raises(ValidationError):
            UpdateRequest(counter=None, message=None)
    
    def test_empty_dict_raises_error(self):
        """Test that empty input raises validation error"""
        with pytest.raises(ValidationError):
            UpdateRequest()
    
    def test_zero_counter_is_valid(self):
        """Test that zero is a valid counter value"""
        request = UpdateRequest(counter=0)
        assert request.counter == 0
    
    def test_negative_counter_is_valid(self):
        """Test that negative counter values are allowed"""
        request = UpdateRequest(counter=-5)
        assert request.counter == -5
    
    def test_empty_message_is_valid(self):
        """Test that empty string is a valid message"""
        request = UpdateRequest(message="")
        assert request.message == ""


class TestStatusResponse:
    """Tests for StatusResponse model"""
    
    def test_valid_status_response(self):
        """Test creating a valid status response"""
        response = StatusResponse(
            counter=10,
            message="test",
            timestamp="2024-01-01T00:00:00Z",
            uptime_seconds=123.45
        )
        assert response.counter == 10
        assert response.message == "test"
        assert response.timestamp == "2024-01-01T00:00:00Z"
        assert response.uptime_seconds == 123.45
    
    def test_missing_required_field_raises_error(self):
        """Test that missing required fields raise error"""
        with pytest.raises(ValidationError):
            StatusResponse(counter=10, message="test")


class TestLogEntry:
    """Tests for LogEntry model"""
    
    def test_valid_log_entry(self):
        """Test creating a valid log entry"""
        entry = LogEntry(
            id=1,
            timestamp="2024-01-01T00:00:00",
            old_counter=0,
            new_counter=5,
            old_message="",
            new_message="test",
            update_type="counter, message"
        )
        assert entry.id == 1
        assert entry.new_counter == 5
    
    def test_optional_fields_can_be_none(self):
        """Test that optional fields accept None"""
        entry = LogEntry(
            id=1,
            timestamp="2024-01-01T00:00:00",
            old_counter=None,
            new_counter=None,
            old_message=None,
            new_message=None,
            update_type="counter"
        )
        assert entry.old_counter is None
        assert entry.new_counter is None


class TestLogsResponse:
    """Tests for LogsResponse model"""
    
    def test_valid_logs_response(self):
        """Test creating a valid logs response"""
        response = LogsResponse(
            logs=[],
            page=1,
            limit=10,
            total=0,
            total_pages=1
        )
        assert response.logs == []
        assert response.page == 1
        assert response.total_pages == 1
    
    def test_logs_response_with_entries(self):
        """Test logs response with log entries"""
        entry = LogEntry(
            id=1,
            timestamp="2024-01-01T00:00:00",
            old_counter=0,
            new_counter=5,
            old_message="",
            new_message="test",
            update_type="counter"
        )
        response = LogsResponse(
            logs=[entry],
            page=1,
            limit=10,
            total=1,
            total_pages=1
        )
        assert len(response.logs) == 1
        assert response.total == 1

