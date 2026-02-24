import asyncio
import logging
from datetime import datetime
from pathlib import Path
from typing import Final

import numpy as np
import pandas as pd
import sklearn
import skops.io as sio
from sklearn.linear_model import LogisticRegression
from sklearn.pipeline import Pipeline

TOP_10_FEATURES: Final[list[str]] = [
    "OPERA_Latin American Wings",
    "MES_7",
    "MES_10",
    "OPERA_Grupo LATAM",
    "MES_12",
    "TIPOVUELO_I",
    "MES_4",
    "MES_11",
    "OPERA_Sky Airline",
    "OPERA_Copa Air",
]

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)


class DelayModel:
    def __init__(self) -> None:
        self._model = None  # Model should be saved in this attribute.
        self._root_path = Path(__file__).parent.parent
        model_path = self._root_path / "artifacts" / "lr-flight-delay-model.skops"
        try:
            unknown_types = sio.get_untrusted_types(file=model_path)
            self._artifact = sio.load(model_path, trusted=unknown_types)
        except FileNotFoundError:
            logger.warning("Model file not found.")
            self._artifact = None
        self._model = self._artifact["pipeline"] if self._artifact else None
        self._metadata = self._artifact["metadata"] if self._artifact else {}
        self._metadata["features"] = TOP_10_FEATURES
        self._threshold_in_minutes = 15

    def _get_min_diff(self, data: pd.Series) -> float:
        fecha_o = datetime.strptime(data["Fecha-O"], "%Y-%m-%d %H:%M:%S")
        fecha_i = datetime.strptime(data["Fecha-I"], "%Y-%m-%d %H:%M:%S")
        min_diff = ((fecha_o - fecha_i).total_seconds()) / 60
        return min_diff

    def _get_target_delay_column(
        self,
        target_column: str,
        data: pd.DataFrame,
    ) -> pd.DataFrame:
        data[target_column] = np.where(
            data["min_diff"] > self._threshold_in_minutes, 1, 0
        )
        return data[[target_column]]

    @staticmethod
    def _preprocess(
        data: pd.DataFrame,
        top_10_features: list[str] | None = None,
    ) -> pd.DataFrame:
        features = pd.concat(
            [
                pd.get_dummies(data["OPERA"], prefix="OPERA"),
                pd.get_dummies(data["TIPOVUELO"], prefix="TIPOVUELO"),
                pd.get_dummies(data["MES"], prefix="MES"),
            ],
            axis=1,
        )
        try:
            features = features[top_10_features]
        except KeyError as e:
            logger.warning(f"defaulting to top 10 features: {e}")
            for feature in TOP_10_FEATURES:
                if feature not in features.columns:
                    features[feature] = 0
            features = features[TOP_10_FEATURES]
        return features

    def preprocess(
        self, data: pd.DataFrame, target_column: str | None = None
    ) -> tuple[pd.DataFrame, pd.DataFrame] | pd.DataFrame:
        """
        Prepare raw data for training or predict.

        Args:
            data (pd.DataFrame): raw data.
            target_column (str, optional): if set, the target is returned.

        Returns:
            Tuple[pd.DataFrame, pd.DataFrame]: features and target.
            or
            pd.DataFrame: features.
        """
        top_10_features = self._metadata.get("features", TOP_10_FEATURES)
        features = self._preprocess(data, top_10_features)
        if target_column is not None:
            data["min_diff"] = data.apply(self._get_min_diff, axis=1)
            target = self._get_target_delay_column(target_column, data)
            return features, target
        return features

    def fit(self, features: pd.DataFrame, target: pd.DataFrame) -> None:
        """
        Fit model with preprocessed data.

        Args:
            features (pd.DataFrame): preprocessed data.
            target (pd.DataFrame): target.
        """
        target = target["delay"]
        n_y0 = len(target[target == 0])
        n_y1 = len(target[target == 1])
        self._model = Pipeline(
            [
                (
                    "model",
                    LogisticRegression(
                        class_weight={1: n_y0 / len(target), 0: n_y1 / len(target)}
                    ),
                )
            ]
        )
        self._model.fit(features, target)
        self.dump_model()

    def dump_model(self) -> None:
        assert self._model is not None, "Model must be fitted before dumping."
        self._artifact = {
            "pipeline": self._model,
            "metadata": {
                "author": "Manuel Valderrama",
                "sklearn_version": sklearn.__version__,
                "features": TOP_10_FEATURES,
                "accuracy_score": 0.55,
                "hyperparameters": self._model.named_steps["model"].get_params(),
            },
        }
        sio.dump(
            self._artifact,
            self._root_path / "artifacts" / "lr-flight-delay-model.skops",
        )

    def load(
        self,
        model_path: str | Path | None = None,
    ) -> None:
        if model_path is None:
            logger.warning("Model path is not provided. Loading default model.")
            model_path = self._root_path / "artifacts" / "lr-flight-delay-model.skops"
        logger.info(f"Loading model from {model_path}")
        try:
            unknown_types = sio.get_untrusted_types(file=model_path)
            self._artifact = sio.load(model_path, trusted=unknown_types)
            self._metadata = self._artifact["metadata"]
            self._model = self._artifact["pipeline"]
        except FileNotFoundError:
            logger.error(f"Model file not found at {model_path}")
            raise
        except Exception as e:
            logger.error(f"Error loading model: {e}")
            raise

    async def predict(self, features: pd.DataFrame) -> list[int]:
        """
        Predict delays for new flights.

        Args:
            features (pd.DataFrame): preprocessed data.

        Returns:
            (List[int]): predicted targets.
        """
        if self._model is None:
            raise ValueError("Model is not fitted yet.")
        result = await asyncio.to_thread(self._model.predict, features)
        return [int(x) for x in result]
