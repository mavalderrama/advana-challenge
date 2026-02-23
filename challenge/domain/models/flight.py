import pandas as pd
from challenge import model


def preprocess_flights(flights) -> pd.DataFrame:
    return model.DelayModel._preprocess(pd.DataFrame(flights.model_dump()["flights"]))
