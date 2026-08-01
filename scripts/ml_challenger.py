"""Evaluate a governed non-linear challenger on the 2024 internet module.

Only repeated-cross-validation metrics and aggregate permutation importance are
published. The event gate is deliberately separate from predictive performance.
"""

from __future__ import annotations

import csv
from collections import defaultdict
from pathlib import Path

import numpy as np
import pandas as pd
from sklearn.compose import ColumnTransformer
from sklearn.ensemble import HistGradientBoostingClassifier
from sklearn.impute import SimpleImputer
from sklearn.metrics import brier_score_loss, roc_auc_score
from sklearn.model_selection import RepeatedStratifiedKFold
from sklearn.pipeline import Pipeline
from sklearn.preprocessing import OrdinalEncoder


ROOT = Path(__file__).resolve().parents[1]
DATA = ROOT / "data" / "raw" / "wbes" / "Tunisia_2013_2020_2024.dta"
METRICS = ROOT / "artifacts" / "public" / "ml_challenger_metrics.csv"
IMPORTANCE = ROOT / "artifacts" / "public" / "ml_feature_importance.csv"
FEATURES = ["region", "sector", "firm_size", "log_annual_sales", "log_broadband_cost"]


def harmonise(raw: pd.DataFrame) -> pd.DataFrame:
    year = pd.to_numeric(raw["year"], errors="coerce")
    data = raw.loc[year.eq(2024)].copy()
    occurrence = pd.to_numeric(data["_2024_c39"], errors="coerce").map({1: 1.0, 2: 0.0})
    weight = pd.to_numeric(data["wmedian"], errors="coerce")
    sales = pd.to_numeric(data["d2"], errors="coerce").where(lambda value: value > 0)
    broadband = pd.to_numeric(data["_2024_n2l"], errors="coerce").where(lambda value: value >= 0)
    result = pd.DataFrame(
        {
            "weight": weight,
            "internet_disruption": occurrence,
            "region": data["a3a"].astype("string"),
            "sector": data["a4a"].astype("string"),
            "firm_size": data["a6a"].astype("string"),
            "log_annual_sales": np.log1p(sales),
            "log_broadband_cost": np.log1p(broadband),
        }
    )
    return result.dropna(subset=["weight", "internet_disruption"]).loc[lambda x: x["weight"] > 0]


def build_model() -> Pipeline:
    categorical = ["region", "sector", "firm_size"]
    numeric = ["log_annual_sales", "log_broadband_cost"]
    preprocessing = ColumnTransformer(
        [
            (
                "categorical",
                Pipeline(
                    [
                        ("impute", SimpleImputer(strategy="most_frequent")),
                        ("encode", OrdinalEncoder(handle_unknown="use_encoded_value", unknown_value=-1)),
                    ]
                ),
                categorical,
            ),
            ("numeric", SimpleImputer(strategy="median"), numeric),
        ]
    )
    return Pipeline(
        [
            ("preprocess", preprocessing),
            (
                "model",
                HistGradientBoostingClassifier(
                    learning_rate=0.035,
                    max_iter=180,
                    max_leaf_nodes=7,
                    min_samples_leaf=30,
                    l2_regularization=2.5,
                    random_state=20260801,
                ),
            ),
        ]
    )


def weighted_average(value: np.ndarray, weight: np.ndarray) -> float:
    return float(np.average(value, weights=weight))


def main() -> None:
    if not DATA.exists():
        raise FileNotFoundError(f"Restricted WBES file not found: {DATA}")
    data = harmonise(pd.read_stata(DATA, convert_categoricals=False)).reset_index(drop=True)
    splitter = RepeatedStratifiedKFold(n_splits=5, n_repeats=10, random_state=20260801)
    metric_values: dict[str, list[float]] = defaultdict(list)
    importance_values: dict[str, list[float]] = defaultdict(list)

    for split_id, (train_index, test_index) in enumerate(
        splitter.split(data[FEATURES], data["internet_disruption"]), start=1
    ):
        train = data.iloc[train_index]
        test = data.iloc[test_index]
        model = build_model()
        model.fit(
            train[FEATURES],
            train["internet_disruption"],
            model__sample_weight=train["weight"],
        )
        probability = np.clip(model.predict_proba(test[FEATURES])[:, 1], 1e-6, 1 - 1e-6)
        prevalence = weighted_average(
            train["internet_disruption"].to_numpy(), train["weight"].to_numpy()
        )
        baseline = np.repeat(prevalence, len(test))
        actual = test["internet_disruption"].to_numpy()
        weight = test["weight"].to_numpy()
        base_auc = roc_auc_score(actual, probability, sample_weight=weight)
        metric_values["weighted_brier"].append(
            brier_score_loss(actual, probability, sample_weight=weight)
        )
        metric_values["prevalence_brier"].append(
            brier_score_loss(actual, baseline, sample_weight=weight)
        )
        metric_values["weighted_auc"].append(base_auc)
        metric_values["observed_rate"].append(weighted_average(actual, weight))
        metric_values["predicted_rate"].append(weighted_average(probability, weight))

        if split_id <= 5:
            random = np.random.default_rng(20260801 + split_id)
            for feature in FEATURES:
                drops: list[float] = []
                for _ in range(10):
                    permuted = test[FEATURES].copy()
                    permuted[feature] = random.permutation(permuted[feature].to_numpy())
                    permuted_probability = model.predict_proba(permuted)[:, 1]
                    permuted_auc = roc_auc_score(actual, permuted_probability, sample_weight=weight)
                    drops.append(base_auc - permuted_auc)
                importance_values[feature].append(float(np.mean(drops)))

    event_count = int(data["internet_disruption"].sum())
    effective_n = float(data["weight"].sum() ** 2 / np.square(data["weight"]).sum())
    gate_passed = event_count >= 200 and effective_n >= 500
    METRICS.parent.mkdir(parents=True, exist_ok=True)
    with METRICS.open("w", newline="", encoding="utf-8") as stream:
        writer = csv.DictWriter(
            stream,
            fieldnames=[
                "model", "validation_design", "metric", "mean_value", "sd_value",
                "evaluated_folds", "event_count", "effective_n", "promotion_gate_passed", "status",
            ],
        )
        writer.writeheader()
        for metric, values in metric_values.items():
            writer.writerow(
                {
                    "model": "hist_gradient_boosting",
                    "validation_design": "repeated_stratified_5fold_10repeats",
                    "metric": metric,
                    "mean_value": float(np.mean(values)),
                    "sd_value": float(np.std(values, ddof=1)),
                    "evaluated_folds": len(values),
                    "event_count": event_count,
                    "effective_n": effective_n,
                    "promotion_gate_passed": gate_passed,
                    "status": "promoted" if gate_passed else "evaluation_only_not_promoted",
                }
            )

    importance_rows = []
    for feature, values in importance_values.items():
        importance_rows.append(
            {
                "feature": feature,
                "importance_auc_mean": float(np.mean(values)),
                "importance_auc_sd": float(np.std(values, ddof=1)),
                "evaluation_folds": len(values),
                "status": "cross_validated_diagnostic_only_not_causal",
            }
        )
    pd.DataFrame(importance_rows).sort_values("importance_auc_mean", ascending=False).to_csv(
        IMPORTANCE, index=False
    )
    print(f"Wrote {len(metric_values)} challenger metrics and aggregate feature diagnostics.")


if __name__ == "__main__":
    main()
