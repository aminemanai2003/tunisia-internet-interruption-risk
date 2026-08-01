internet_evidence_2024 <- function(panel) {
  valid <- panel[!is.na(panel$internet_disruption) & is.finite(panel$survey_weight), ]
  affected <- valid[valid$internet_disruption == 1, ]
  duration <- affected[is.finite(affected$disruption_duration_hours), ]
  loss_valid <- affected[is.finite(affected$internet_loss_ratio_pct), ]
  positive <- loss_valid[loss_valid$internet_loss_ratio_pct > 0, ]
  switching <- panel[is.finite(panel$provider_switch_constraint) & is.finite(panel$survey_weight), ]
  broadband <- panel[is.finite(panel$annual_broadband_cost_tnd) & is.finite(panel$survey_weight), ]

  p_disruption <- weighted_mean_safe(valid$internet_disruption, valid$survey_weight)
  p_loss <- weighted_mean_safe(loss_valid$positive_internet_loss, loss_valid$survey_weight)
  severity <- weighted_mean_safe(positive$internet_loss_ratio_pct / 100, positive$survey_weight)

  data.frame(
    survey_year = 2024L,
    raw_n = nrow(panel),
    connected_usable_n = nrow(valid),
    no_internet_connection_n = sum(panel$internet_connected == 0, na.rm = TRUE),
    effective_n = round(effective_n(valid$survey_weight), 1),
    disruption_events = sum(valid$internet_disruption == 1),
    disruption_rate_unweighted = mean(valid$internet_disruption),
    disruption_rate_weighted = p_disruption,
    duration_usable_n = nrow(duration),
    mean_duration_hours_weighted = weighted_mean_safe(
      duration$disruption_duration_hours, duration$survey_weight
    ),
    median_duration_hours_weighted = weighted_quantile_safe(
      duration$disruption_duration_hours, duration$survey_weight
    ),
    loss_ratio_usable_n = nrow(loss_valid),
    positive_loss_events = nrow(positive),
    positive_loss_rate_given_disruption_weighted = p_loss,
    mean_positive_loss_ratio_weighted = severity,
    expected_loss_ratio_weighted = p_disruption * p_loss * severity,
    provider_switch_constraint_rate_weighted = weighted_mean_safe(
      switching$provider_switch_constraint, switching$survey_weight
    ),
    median_annual_broadband_cost_tnd_weighted = weighted_quantile_safe(
      broadband$annual_broadband_cost_tnd, broadband$survey_weight
    )
  )
}

segment_evidence <- function(panel, minimum_n = 30, minimum_events = 5) {
  dimensions <- c("region", "sector", "firm_size")
  rows <- lapply(dimensions, function(dimension) {
    data <- panel[
      !is.na(panel$internet_disruption) & is.finite(panel$survey_weight) &
        !is.na(panel[[dimension]]),
    ]
    groups <- split(data, data[[dimension]], drop = TRUE)
    dplyr::bind_rows(lapply(names(groups), function(group_name) {
      group <- groups[[group_name]]
      events <- sum(group$internet_disruption == 1)
      if (nrow(group) < minimum_n || events < minimum_events) return(NULL)
      data.frame(
        dimension = dimension,
        segment = group_name,
        raw_n = nrow(group),
        effective_n = round(effective_n(group$survey_weight), 1),
        disruption_events = events,
        disruption_rate_weighted = weighted_mean_safe(
          group$internet_disruption, group$survey_weight
        )
      )
    }))
  })
  dplyr::bind_rows(rows)
}

switching_distribution <- function(panel) {
  data <- panel[
    !is.na(panel$provider_switch_category) & is.finite(panel$survey_weight),
  ]
  groups <- split(data, data$provider_switch_category, drop = TRUE)
  total_weight <- sum(data$survey_weight)
  dplyr::bind_rows(lapply(names(groups), function(category) {
    group <- groups[[category]]
    data.frame(
      category = category,
      raw_n = nrow(group),
      weighted_share = sum(group$survey_weight) / total_weight
    )
  }))
}

build_sample_gate <- function(panel) {
  valid <- panel[!is.na(panel$internet_disruption) & is.finite(panel$survey_weight), ]
  affected <- valid[valid$internet_disruption == 1, ]
  duration_n <- sum(affected$disruption_duration_hours > 0, na.rm = TRUE)
  positive_loss_n <- sum(affected$internet_loss_ratio_pct > 0, na.rm = TRUE)
  occurrence_events <- sum(valid$internet_disruption == 1)
  n_eff <- effective_n(valid$survey_weight)

  data.frame(
    component = c(
      "occurrence_glm", "duration_gamma", "severity_glm",
      "ml_challenger", "operator_loss_attribution"
    ),
    observed_events_or_rows = c(occurrence_events, duration_n, positive_loss_n, occurrence_events, 0),
    minimum_required = c(100, 100, 50, 200, 1),
    allowed = c(
      occurrence_events >= 100,
      duration_n >= 100,
      positive_loss_n >= 50,
      occurrence_events >= 200 && n_eff >= 500,
      FALSE
    ),
    interpretation = c(
      "Parsimonious survey-weighted occurrence GLM permitted.",
      "Conditional Gamma duration model permitted with limited predictors.",
      "Positive-loss sample is too small for a stable severity GLM.",
      "The non-linear model remains an evaluation-only challenger.",
      "WBES contains no operator identifier; business losses cannot be assigned to an operator."
    )
  )
}

build_data_audit <- function(panel) {
  fields <- c(
    "internet_connected", "internet_disruption", "disruption_duration_hours",
    "internet_loss_ratio_pct", "internet_loss_value_tnd",
    "provider_switch_category", "annual_broadband_cost_tnd", "survey_weight",
    "region", "sector", "firm_size", "annual_sales_tnd"
  )
  data.frame(
    survey_year = 2024L,
    field = fields,
    raw_n = nrow(panel),
    non_missing_n = vapply(fields, function(field) sum(!is.na(panel[[field]])), numeric(1)),
    non_missing_rate = vapply(fields, function(field) mean(!is.na(panel[[field]])), numeric(1))
  )
}
