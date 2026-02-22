import pydantic


class FlightData(pydantic.BaseModel):
    OPERA: str
    TIPOVUELO: str
    MES: int

    @pydantic.field_validator("MES", mode="after")
    def validate_month(cls, v: int) -> int:
        if 1 <= v <= 12:
            return v
        raise ValueError("MES must be between 1 and 12")

    @pydantic.field_validator("TIPOVUELO", mode="after")
    def validate_tipo_vuelo(cls, v: str) -> str:
        if v not in ["I", "N"]:
            raise ValueError("TIPOVUELO must be 'I' or 'N'")
        return v


class Prediction(pydantic.BaseModel):
    flights: list[FlightData]
