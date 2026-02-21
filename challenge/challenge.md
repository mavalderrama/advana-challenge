# Part 1: Exploratory Data Analysis

1. First, after looking at the DS job, I noticed some minor mistakes that could lead to wrong conclusions.
   1. The `get_period_day` function was returning `None` for boundary times, the function makes use of strict inequalities `>`, instead of `>=`, so flights departing exactly at `05:00`, `12:00`, `19:00`, etc, are mapped to `NaN`, failing silently in the features set.
   2. Found a small bug that on `get_rate_from_column` function causing that we weren't calculating the `Delay Rate` since the DS was doing ` total/delays` instead of `delays/total`.
   3. The feature engineering looks fantastic, but it seems some features were left out unintentionally like `period_day`, `high_season`, `SIGLADES`, `DIANOM` and `DIA` on the training set, leaving them out potentially limits the model performance.
   4. The top 10 features were extracted from the first `XGBoost` model, this model had a `Recall` of `0.00` for the minority class. Extracting the features from this model can be dangerous because this model will tell you only about `on-time` flights, and not about `delayed` flights.
      1. There is a chance that these exact features work also for the `delayed` flights, but it is risky to assume that from this specific analysis.
   5. The DS defined a prediction threshold of `0.5`, this is a common threshold for binary classification problems, but it might not be the best choice for this specific problem, due to the imbalance of the classes.
   6. The DS did not perform any hyperparameter tuning, this can lead to suboptimal model performance.
        1. The DS used a `learning_rate` of `0.01` but left the `n_estimators` at its default value of `100`, this can lead to underfitting.
   7. At the training stage the DS didn't take into account the class imbalance; the split was done without considering the class distribution, depending on the luck the training set could contain more or less from the intended class.
         1. Optionally, since the data is `temporal`, we can also make a `temporal split` training the first 8-9 months of the year, and validate on the last 3-4 months. In production a model trained today never sees data from the past.
   8. Finally, the DS concludes that the balance improved the recall on class `1` but he doesn't mention that the precision is worse.

2. Since the model was trained entirely on categorical data, you should move away from `LogisticRegression` and try models optimized for categories like `CatBoost`, `LightGBM` and `RandomForest`.
3. Modified the `exploration.ipynb` to include the fixes mentioned above.
