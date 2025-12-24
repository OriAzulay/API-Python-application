"""
FastAPI application factory and configuration
"""
from contextlib import asynccontextmanager

from fastapi import FastAPI

from app.config import settings
from app.database import init_db
from app.routes import router


@asynccontextmanager
async def lifespan(app: FastAPI):
    """Lifespan context manager for startup and shutdown"""
    # Startup
    init_db()
    yield
    # Shutdown (cleanup if needed)
    pass


def create_app() -> FastAPI:
    """Application factory pattern"""
    application = FastAPI(
        title=settings.APP_TITLE,
        description=settings.APP_DESCRIPTION,
        version=settings.APP_VERSION,
        lifespan=lifespan
    )
    
    # Include routers
    application.include_router(router)
    
    return application


# Create the app instance
app = create_app()

