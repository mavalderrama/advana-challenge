import pydantic
import pandas as pd
from challenge import model


class Flight(pydantic.BaseModel):
    flights: pd.DataFrame

    model_config = pydantic.ConfigDict(arbitrary_types_allowed=True)

    @pydantic.field_validator("flights", mode="before")
    @classmethod
    def flight_columns(cls, value: pd.DataFrame) -> pd.DataFrame:
        required_columns = ["OPERA", "TIPOVUELO", "MES"]
        features = pd.DataFrame(value)
        missing_columns = [
            col for col in required_columns if col not in features.columns
        ]
        if missing_columns:
            raise ValueError(f"Missing required columns: {', '.join(missing_columns)}")
        return model.DelayModel._preprocess(features)
