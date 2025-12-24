"""
Application configuration and settings
"""
import os
import time


class Settings:
    """Application settings"""
    
    # Application metadata
    APP_TITLE: str = "Shared State API"
    APP_DESCRIPTION: str = "API for managing shared state with logging"
    APP_VERSION: str = "1.0.0"
    
    # Database
    DB_FILE: str = "app.db"
    
    # Server
    HOST: str = "0.0.0.0"
    PORT: int = int(os.getenv("PORT", "5000"))
    
    # Security
    API_KEY: str = os.getenv("API_KEY", "your-secret-api-key-12345")
    
    # Application start time for uptime calculation
    START_TIME: float = time.time()


settings = Settings()

