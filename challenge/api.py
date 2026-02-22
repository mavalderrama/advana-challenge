import fastapi
import logging
import os
from contextlib import asynccontextmanager
from challenge import model
from challenge.app import schemas
from challenge.domain.models import flight
from fastapi.responses import JSONResponse
from fastapi import Request, status
from fastapi.exceptions import RequestValidationError

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)


@asynccontextmanager
async def lifespan(app: fastapi.FastAPI):
    logger.info(
        "Starting LATAM Advana Challenge API.",
        extra={
            "python_version": os.sys.version,
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
async def validation_exception_handler(request: Request, exc: RequestValidationError):
    return JSONResponse(
        status_code=status.HTTP_400_BAD_REQUEST,
        content={},
    )


@app.get("/health", status_code=200)
async def get_health() -> dict:
    return {"status": "OK"}


@app.post("/predict", status_code=200)
async def post_predict(request: Request, data: schemas.Prediction) -> dict:
    flight_data = data.model_dump_json()
    try:
        validated_flight_data = flight.Flight.model_validate_json(flight_data)
    except Exception as e:
        logger.error(f"Error validating flight data: {e}")
        return {"predict": [0]}
    logger.info(f"Predicting for flights: {validated_flight_data.flights}")
    return {"predict": request.app.state.model.predict(validated_flight_data.flights)}
