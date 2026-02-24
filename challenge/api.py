import logging
import sys
from collections.abc import AsyncGenerator
from contextlib import asynccontextmanager

import fastapi
from fastapi import Request, status
from fastapi.exceptions import RequestValidationError
from fastapi.responses import JSONResponse

from challenge import model
from challenge.app import schemas
from challenge.domain.models import flight

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)


@asynccontextmanager
async def lifespan(app: fastapi.FastAPI) -> AsyncGenerator[None]:
    logger.info(
        "Starting LATAM Advana Challenge API.",
        extra={
            "python_version": sys.version,
        },
    )
    try:
        app.state.model = model.DelayModel()
        yield
    finally:
        logger.info("Stopping LATAM Advana Challenge API.")


app = fastapi.FastAPI(
    title="LATAM Advana Challenge API",
    lifespan=lifespan,
    docs_url="/docs",
)


@app.exception_handler(RequestValidationError)
async def validation_exception_handler(
    request: Request, exc: RequestValidationError
) -> JSONResponse:
    return JSONResponse(
        status_code=status.HTTP_400_BAD_REQUEST,
        content={},
    )


@app.get("/health", status_code=200)
async def get_health() -> dict:
    return {"status": "OK"}


@app.post("/predict", status_code=200)
async def post_predict(request: Request, data: schemas.Prediction) -> dict:
    features = flight.preprocess_flights(data)
    logger.info(f"Predicting for {len(data.flights)} flights")
    return {"predict": await request.app.state.model.predict(features)}


if __name__ == "__main__":
    import uvicorn

    uvicorn.run(app, host="0.0.0.0", port=8080)
