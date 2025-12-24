"""
Pydantic models/schemas for request and response validation
"""
from typing import Optional

from pydantic import BaseModel, field_validator, model_validator


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

