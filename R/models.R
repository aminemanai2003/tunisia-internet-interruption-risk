fit_occurrence_glm <- function(panel) {
  data <- panel[!is.na(panel$internet_disruption) & is.finite(panel$survey_weight), ]
  design <- survey::svydesign(ids = ~1, weights = ~survey_weight, data = data)
  survey::svyglm(
    internet_disruption ~ region + sector + firm_size,
    design = design,
    family = quasibinomial()
  )
}

fit_duration_model <- function(panel) {
  data <- panel[
    panel$internet_disruption == 1 & is.finite(panel$disruption_duration_hours) &
      panel$disruption_duration_hours > 0 & is.finite(panel$survey_weight),
  ]
  cap <- as.numeric(stats::quantile(data$disruption_duration_hours, 0.99, na.rm = TRUE))
  data$duration_capped <- pmin(data$disruption_duration_hours, cap)
  stats::glm(
    duration_capped ~ sector + firm_size,
    data = data,
    weights = survey_weight,
    family = Gamma(link = "log")
  )
}

model_coefficients <- function(...) {
  models <- list(...)
  dplyr::bind_rows(lapply(names(models), function(name) {
    broom::tidy(models[[name]], conf.int = FALSE) |>
      dplyr::mutate(
        conf.low = estimate - stats::qnorm(0.975) * std.error,
        conf.high = estimate + stats::qnorm(0.975) * std.error,
        component = name,
        .before = 1
      )
  }))
}

weighted_auc <- function(actual, predicted, weight) {
  ok <- is.finite(actual) & is.finite(predicted) & is.finite(weight) & weight > 0
  actual <- actual[ok]
  predicted <- predicted[ok]
  weight <- weight[ok]
  positive <- which(actual == 1)
  negative <- which(actual == 0)
  if (!length(positive) || !length(negative)) return(NA_real_)
  concordance <- outer(predicted[positive], predicted[negative], `>`)
  ties <- outer(predicted[positive], predicted[negative], `==`)
  pair_weight <- outer(weight[positive], weight[negative], `*`)
  sum(pair_weight * (concordance + 0.5 * ties)) / sum(pair_weight)
}

stratified_fold_ids <- function(outcome, folds, seed) {
  set.seed(seed)
  result <- integer(length(outcome))
  for (class_value in sort(unique(outcome))) {
    rows <- sample(which(outcome == class_value))
    result[rows] <- rep(seq_len(folds), length.out = length(rows))
  }
  result
}

repeated_cross_validation <- function(panel, folds = 5, repeats = 10, seed = 20260801) {
  data <- panel[!is.na(panel$internet_disruption) & is.finite(panel$survey_weight), ]
  fold_rows <- vector("list", folds * repeats)
  cursor <- 1L
  for (repeat_id in seq_len(repeats)) {
    fold_id <- stratified_fold_ids(data$internet_disruption, folds, seed + repeat_id)
    for (fold in seq_len(folds)) {
      train <- data[fold_id != fold, ]
      test <- data[fold_id == fold, ]
      model <- stats::glm(
        internet_disruption ~ region + sector + firm_size,
        data = train,
        weights = survey_weight,
        family = quasibinomial()
      )
      prediction <- pmin(
        pmax(stats::predict(model, newdata = test, type = "response"), 1e-6),
        1 - 1e-6
      )
      prevalence <- weighted_mean_safe(train$internet_disruption, train$survey_weight)
      fold_rows[[cursor]] <- data.frame(
        repeat_id = repeat_id,
        fold_id = fold,
        weighted_brier = weighted_mean_safe(
          (test$internet_disruption - prediction)^2, test$survey_weight
        ),
        prevalence_brier = weighted_mean_safe(
          (test$internet_disruption - prevalence)^2, test$survey_weight
        ),
        weighted_auc = weighted_auc(test$internet_disruption, prediction, test$survey_weight),
        observed_rate = weighted_mean_safe(test$internet_disruption, test$survey_weight),
        predicted_rate = weighted_mean_safe(prediction, test$survey_weight)
      )
      cursor <- cursor + 1L
    }
  }
  fold_results <- dplyr::bind_rows(fold_rows)
  metrics <- c(
    "weighted_brier", "prevalence_brier", "weighted_auc",
    "observed_rate", "predicted_rate"
  )
  dplyr::bind_rows(lapply(metrics, function(metric) {
    values <- fold_results[[metric]]
    data.frame(
      model = "survey_weighted_glm",
      validation_design = sprintf("repeated_stratified_%dfold_%drepeats", folds, repeats),
      metric = metric,
      mean_value = mean(values, na.rm = TRUE),
      sd_value = stats::sd(values, na.rm = TRUE),
      evaluated_folds = sum(is.finite(values))
    )
  }))
}
