"""
Unit tests for database functions
"""
import sqlite3
import pytest

from app import database
from app.config import settings


class TestInitDb:
    """Tests for database initialization"""
    
    def test_creates_shared_state_table(self, temp_db):
        """Test that init_db creates shared_state table"""
        conn = sqlite3.connect(temp_db)
        cursor = conn.cursor()
        
        cursor.execute(
            "SELECT name FROM sqlite_master WHERE type='table' AND name='shared_state'"
        )
        assert cursor.fetchone() is not None, "shared_state table should exist"
        
        conn.close()
    
    def test_creates_update_logs_table(self, temp_db):
        """Test that init_db creates update_logs table"""
        conn = sqlite3.connect(temp_db)
        cursor = conn.cursor()
        
        cursor.execute(
            "SELECT name FROM sqlite_master WHERE type='table' AND name='update_logs'"
        )
        assert cursor.fetchone() is not None, "update_logs table should exist"
        
        conn.close()
    
    def test_creates_initial_state(self, temp_db):
        """Test that init_db creates initial state record"""
        conn = sqlite3.connect(temp_db)
        cursor = conn.cursor()
        
        cursor.execute("SELECT COUNT(*) FROM shared_state")
        count = cursor.fetchone()[0]
        assert count > 0, "Initial state should be created"
        
        conn.close()
    
    def test_initial_state_has_default_values(self, temp_db):
        """Test that initial state has expected default values"""
        conn = sqlite3.connect(temp_db)
        conn.row_factory = sqlite3.Row
        cursor = conn.cursor()
        
        cursor.execute("SELECT counter, message FROM shared_state LIMIT 1")
        row = cursor.fetchone()
        
        assert row["counter"] == 0
        assert row["message"] == ""
        
        conn.close()


class TestGetCurrentState:
    """Tests for get_current_state function"""
    
    def test_returns_dict_with_required_keys(self, temp_db):
        """Test that get_current_state returns dict with counter and message"""
        state = database.get_current_state()
        
        assert "counter" in state
        assert "message" in state
    
    def test_counter_is_integer(self, temp_db):
        """Test that counter is an integer"""
        state = database.get_current_state()
        assert isinstance(state["counter"], int)
    
    def test_message_is_string(self, temp_db):
        """Test that message is a string"""
        state = database.get_current_state()
        assert isinstance(state["message"], str)


class TestUpdateState:
    """Tests for update_state function"""
    
    def test_returns_result_dict(self, temp_db):
        """Test that update_state returns result dictionary"""
        result = database.update_state(counter=10)
        
        assert "old_counter" in result
        assert "new_counter" in result
        assert "old_message" in result
        assert "new_message" in result
    
    def test_updates_counter_only(self, temp_db):
        """Test updating only counter"""
        result = database.update_state(counter=42)
        
        assert result["new_counter"] == 42
        
        # Verify persisted
        state = database.get_current_state()
        assert state["counter"] == 42
    
    def test_updates_message_only(self, temp_db):
        """Test updating only message"""
        result = database.update_state(message="Hello World")
        
        assert result["new_message"] == "Hello World"
        
        # Verify persisted
        state = database.get_current_state()
        assert state["message"] == "Hello World"
    
    def test_updates_both_fields(self, temp_db):
        """Test updating both counter and message"""
        result = database.update_state(counter=99, message="Both updated")
        
        assert result["new_counter"] == 99
        assert result["new_message"] == "Both updated"
        
        # Verify persisted
        state = database.get_current_state()
        assert state["counter"] == 99
        assert state["message"] == "Both updated"
    
    def test_preserves_unchanged_field(self, temp_db):
        """Test that unchanged fields are preserved"""
        # Set initial values
        database.update_state(counter=50, message="Original")
        
        # Update only counter
        database.update_state(counter=100)
        
        state = database.get_current_state()
        assert state["counter"] == 100
        assert state["message"] == "Original"  # Should be preserved
    
    def test_creates_log_entry(self, temp_db):
        """Test that update creates a log entry"""
        initial_logs = database.get_logs()
        initial_count = initial_logs["total"]
        
        database.update_state(counter=1)
        
        updated_logs = database.get_logs()
        assert updated_logs["total"] == initial_count + 1


class TestGetLogs:
    """Tests for get_logs function"""
    
    def test_returns_required_keys(self, temp_db):
        """Test that get_logs returns all required keys"""
        result = database.get_logs()
        
        assert "logs" in result
        assert "page" in result
        assert "limit" in result
        assert "total" in result
        assert "total_pages" in result
    
    def test_logs_is_list(self, temp_db):
        """Test that logs is a list"""
        result = database.get_logs()
        assert isinstance(result["logs"], list)
    
    def test_default_pagination(self, temp_db):
        """Test default pagination values"""
        result = database.get_logs()
        
        assert result["page"] == 1
        assert result["limit"] == 10
    
    def test_custom_pagination(self, temp_db):
        """Test custom pagination parameters"""
        result = database.get_logs(page=2, limit=5)
        
        assert result["page"] == 2
        assert result["limit"] == 5
    
    def test_respects_limit(self, temp_db):
        """Test that limit is respected"""
        # Create some log entries
        for i in range(5):
            database.update_state(counter=i)
        
        result = database.get_logs(limit=3)
        assert len(result["logs"]) <= 3
    
    def test_total_pages_calculation(self, temp_db):
        """Test that total_pages is calculated correctly"""
        # Create 15 log entries
        for i in range(15):
            database.update_state(counter=i)
        
        result = database.get_logs(limit=10)
        
        # With 15 entries and limit 10, should have 2 pages
        assert result["total_pages"] >= 2

