import pandas as pd

from challenge import model
from challenge.app import schemas


def preprocess_flights(flights: schemas.Prediction) -> pd.DataFrame:
    return model.DelayModel._preprocess(pd.DataFrame(flights.model_dump()["flights"]))
