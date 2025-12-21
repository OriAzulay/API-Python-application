"""
FastAPI Application with shared state management and logging
"""
import os
import time
from datetime import datetime
from typing import Optional
from contextlib import asynccontextmanager

from fastapi import FastAPI, HTTPException, Header, Depends, Query
from fastapi.responses import JSONResponse
from pydantic import BaseModel, field_validator, model_validator
import sqlite3
import uvicorn

# Application start time for uptime calculation
START_TIME = time.time()

# Database file
DB_FILE = "app.db"

# API Key (in production, use environment variables or secrets management)
API_KEY = os.getenv("API_KEY", "your-secret-api-key-12345")


# Database initialization
def init_db():
    """Initialize SQLite database with required tables"""
    conn = sqlite3.connect(DB_FILE)
    cursor = conn.cursor()
    
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


@asynccontextmanager
async def lifespan(app: FastAPI):
    """Lifespan context manager for startup and shutdown"""
    # Startup
    init_db()
    yield
    # Shutdown (cleanup if needed)
    pass


app = FastAPI(
    title="Shared State API",
    description="API for managing shared state with logging",
    version="1.0.0",
    lifespan=lifespan
)


# Pydantic models
class UpdateRequest(BaseModel):
    """Model for update requests"""
    counter: Optional[int] = None
    message: Optional[str] = None
    
    @field_validator('counter')
    @classmethod
    def validate_counter(cls, v):
        if v is not None and not isinstance(v, int):
            raise ValueError('counter must be an integer')
        return v
    
    @field_validator('message')
    @classmethod
    def validate_message(cls, v):
        if v is not None and not isinstance(v, str):
            raise ValueError('message must be a string')
        return v
    
    @model_validator(mode='after')
    def validate_at_least_one_field(self):
        """Ensure at least one field is provided"""
        if self.counter is None and self.message is None:
            raise ValueError('At least one of counter or message must be provided')
        return self


class StatusResponse(BaseModel):
    """Model for status response"""
    counter: int
    message: str
    timestamp: str
    uptime_seconds: float


class LogEntry(BaseModel):
    """Model for log entry"""
    id: int
    timestamp: str
    old_counter: Optional[int]
    new_counter: Optional[int]
    old_message: Optional[str]
    new_message: Optional[str]
    update_type: str


class LogsResponse(BaseModel):
    """Model for logs response"""
    logs: list[LogEntry]
    page: int
    limit: int
    total: int
    total_pages: int


# Dependency for API key authentication
async def verify_api_key(x_api_key: str = Header(..., alias="X-API-Key")):
    """Verify API key from header"""
    if x_api_key != API_KEY:
        raise HTTPException(
            status_code=401,
            detail="Invalid API Key"
        )
    return x_api_key


# Database helper functions
def get_current_state():
    """Get current shared state from database"""
    conn = sqlite3.connect(DB_FILE)
    conn.row_factory = sqlite3.Row
    cursor = conn.cursor()
    cursor.execute("SELECT * FROM shared_state ORDER BY id DESC LIMIT 1")
    row = cursor.fetchone()
    conn.close()
    
    if row:
        return {"counter": row["counter"], "message": row["message"]}
    return {"counter": 0, "message": ""}


def update_state(counter: Optional[int] = None, message: Optional[str] = None):
    """Update shared state and log the change"""
    conn = sqlite3.connect(DB_FILE)
    conn.row_factory = sqlite3.Row
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


def get_logs(page: int = 1, limit: int = 10):
    """Get paginated logs from database"""
    conn = sqlite3.connect(DB_FILE)
    conn.row_factory = sqlite3.Row
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


# API Endpoints
@app.get("/status", response_model=StatusResponse)
async def get_status():
    """
    Get the current state of the shared variable with metadata
    """
    state = get_current_state()
    current_time = datetime.utcnow().isoformat() + "Z"
    uptime = time.time() - START_TIME
    
    return StatusResponse(
        counter=state["counter"],
        message=state["message"],
        timestamp=current_time,
        uptime_seconds=round(uptime, 2)
    )


@app.post("/update")
async def update_state_endpoint(
    request: UpdateRequest,
    api_key: str = Depends(verify_api_key)
):
    """
    Update the shared variable (counter or message)
    Requires API key authentication via X-API-Key header
    """
    # Update state (validation is handled by Pydantic)
    result = update_state(
        counter=request.counter,
        message=request.message
    )
    
    return {
        "success": True,
        "message": "State updated successfully",
        "old_state": {
            "counter": result["old_counter"],
            "message": result["old_message"]
        },
        "new_state": {
            "counter": result["new_counter"],
            "message": result["new_message"]
        }
    }


@app.get("/logs", response_model=LogsResponse)
async def get_logs_endpoint(
    page: int = Query(1, ge=1, description="Page number (starts from 1)"),
    limit: int = Query(10, ge=1, le=100, description="Number of logs per page (max 100)")
):
    """
    Get paginated list of all updates made to the shared variable
    """
    result = get_logs(page=page, limit=limit)
    return LogsResponse(**result)


@app.get("/")
async def root():
    """Root endpoint with API information"""
    return {
        "message": "Shared State API",
        "version": "1.0.0",
        "endpoints": {
            "GET /status": "Get current state with metadata",
            "POST /update": "Update shared state (requires API key)",
            "GET /logs": "Get paginated update logs"
        }
    }


if __name__ == "__main__":
    port = int(os.getenv("PORT", "5000"))
    uvicorn.run(app, host="0.0.0.0", port=port)

