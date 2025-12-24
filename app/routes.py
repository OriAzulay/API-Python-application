"""
API route definitions
"""
import time
from datetime import datetime, timezone

from fastapi import APIRouter, Depends, Query

from app.config import settings
from app.database import get_current_state, update_state, get_logs
from app.schemas import UpdateRequest, StatusResponse, LogsResponse
from app.dependencies import verify_api_key


router = APIRouter()


@router.get("/", tags=["root"])
async def root():
    """Root endpoint with API information"""
    return {
        "message": settings.APP_TITLE,
        "version": settings.APP_VERSION,
        "endpoints": {
            "GET /status": "Get current state with metadata",
            "POST /update": "Update shared state (requires API key)",
            "GET /logs": "Get paginated update logs"
        }
    }


@router.get("/status", response_model=StatusResponse, tags=["state"])
async def get_status():
    """
    Get the current state of the shared variable with metadata
    """
    state = get_current_state()
    current_time = datetime.now(timezone.utc).isoformat().replace("+00:00", "Z")
    uptime = time.time() - settings.START_TIME
    
    return StatusResponse(
        counter=state["counter"],
        message=state["message"],
        timestamp=current_time,
        uptime_seconds=round(uptime, 2)
    )


@router.post("/update", tags=["state"])
async def update_state_endpoint(
    request: UpdateRequest,
    api_key: str = Depends(verify_api_key)
):
    """
    Update the shared variable (counter or message)
    Requires API key authentication via X-API-Key header
    """
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


@router.get("/logs", response_model=LogsResponse, tags=["logs"])
async def get_logs_endpoint(
    page: int = Query(1, ge=1, description="Page number (starts from 1)"),
    limit: int = Query(10, ge=1, le=100, description="Number of logs per page (max 100)")
):
    """
    Get paginated list of all updates made to the shared variable
    """
    result = get_logs(page=page, limit=limit)
    return LogsResponse(**result)

