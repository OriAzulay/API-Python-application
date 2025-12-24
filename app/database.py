"""
Database initialization and CRUD operations
"""
import sqlite3
from typing import Optional

from app.config import settings
from app.schemas import LogEntry


def get_connection():
    """Get a database connection with row factory"""
    conn = sqlite3.connect(settings.DB_FILE, timeout=10)
    conn.row_factory = sqlite3.Row
    return conn


def init_db():
    """Initialize SQLite database with required tables"""
    conn = sqlite3.connect(settings.DB_FILE, timeout=10)
    cursor = conn.cursor()
    
    # Enable WAL mode for better concurrency
    cursor.execute("PRAGMA journal_mode=WAL")
    
    # Table for shared state
    cursor.execute("""
        CREATE TABLE IF NOT EXISTS shared_state (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            counter INTEGER DEFAULT 0,
            message TEXT DEFAULT '',
            updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        )
    """)
    
    # Table for logs
    cursor.execute("""
        CREATE TABLE IF NOT EXISTS update_logs (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            old_counter INTEGER,
            new_counter INTEGER,
            old_message TEXT,
            new_message TEXT,
            update_type TEXT
        )
    """)
    
    # Initialize shared state if empty
    cursor.execute("SELECT COUNT(*) FROM shared_state")
    if cursor.fetchone()[0] == 0:
        cursor.execute("INSERT INTO shared_state (counter, message) VALUES (0, '')")
    
    conn.commit()
    conn.close()


def get_current_state() -> dict:
    """Get current shared state from database"""
    conn = get_connection()
    cursor = conn.cursor()
    cursor.execute("SELECT * FROM shared_state ORDER BY id DESC LIMIT 1")
    row = cursor.fetchone()
    conn.close()
    
    if row:
        return {"counter": row["counter"], "message": row["message"]}
    return {"counter": 0, "message": ""}


def update_state(counter: Optional[int] = None, message: Optional[str] = None) -> dict:
    """Update shared state and log the change"""
    conn = get_connection()
    cursor = conn.cursor()
    
    # Get current state
    cursor.execute("SELECT * FROM shared_state ORDER BY id DESC LIMIT 1")
    current = cursor.fetchone()
    old_counter = current["counter"] if current else 0
    old_message = current["message"] if current else ""
    
    # Determine new values
    new_counter = counter if counter is not None else old_counter
    new_message = message if message is not None else old_message
    
    # Update state
    cursor.execute("""
        UPDATE shared_state 
        SET counter = ?, message = ?, updated_at = CURRENT_TIMESTAMP
        WHERE id = (SELECT id FROM shared_state ORDER BY id DESC LIMIT 1)
    """, (new_counter, new_message))
    
    # Log the change
    update_type = []
    if counter is not None:
        update_type.append("counter")
    if message is not None:
        update_type.append("message")
    
    cursor.execute("""
        INSERT INTO update_logs 
        (old_counter, new_counter, old_message, new_message, update_type)
        VALUES (?, ?, ?, ?, ?)
    """, (old_counter, new_counter, old_message, new_message, ", ".join(update_type)))
    
    conn.commit()
    conn.close()
    
    return {
        "old_counter": old_counter,
        "new_counter": new_counter,
        "old_message": old_message,
        "new_message": new_message
    }


def get_logs(page: int = 1, limit: int = 10) -> dict:
    """Get paginated logs from database"""
    conn = get_connection()
    cursor = conn.cursor()
    
    # Get total count
    cursor.execute("SELECT COUNT(*) FROM update_logs")
    total = cursor.fetchone()[0]
    
    # Calculate pagination
    offset = (page - 1) * limit
    total_pages = (total + limit - 1) // limit if total > 0 else 1
    
    # Get logs
    cursor.execute("""
        SELECT * FROM update_logs 
        ORDER BY timestamp DESC 
        LIMIT ? OFFSET ?
    """, (limit, offset))
    
    rows = cursor.fetchall()
    conn.close()
    
    logs = [
        LogEntry(
            id=row["id"],
            timestamp=row["timestamp"],
            old_counter=row["old_counter"],
            new_counter=row["new_counter"],
            old_message=row["old_message"],
            new_message=row["new_message"],
            update_type=row["update_type"]
        )
        for row in rows
    ]
    
    return {
        "logs": logs,
        "page": page,
        "limit": limit,
        "total": total,
        "total_pages": total_pages
    }

