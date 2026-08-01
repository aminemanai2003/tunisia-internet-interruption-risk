estimate_2024_loss_ratio <- function(panel) {
  valid <- panel[!is.na(panel$internet_disruption) & is.finite(panel$survey_weight), ]
  affected <- valid[
    valid$internet_disruption == 1 & is.finite(valid$internet_loss_ratio_pct),
  ]
  positive <- affected[affected$internet_loss_ratio_pct > 0, ]

  p_disruption <- weighted_mean_safe(valid$internet_disruption, valid$survey_weight)
  p_positive <- weighted_mean_safe(affected$positive_internet_loss, affected$survey_weight)
  severity <- weighted_mean_safe(
    positive$internet_loss_ratio_pct / 100, positive$survey_weight
  )

  data.frame(
    calibration_year = 2024L,
    disruption_probability = p_disruption,
    positive_loss_probability_given_disruption = p_positive,
    mean_positive_loss_ratio = severity,
    expected_loss_ratio = p_disruption * p_positive * severity,
    valid_loss_ratio_responses = nrow(affected),
    positive_loss_events = nrow(positive)
  )
}

bootstrap_loss_ratio <- function(panel, replicates = 2000, seed = 20260801) {
  valid <- panel[!is.na(panel$internet_disruption) & is.finite(panel$survey_weight), ]
  probability <- valid$survey_weight / sum(valid$survey_weight)
  set.seed(seed)
  estimates <- replicate(replicates, {
    sample_id <- sample(seq_len(nrow(valid)), nrow(valid), replace = TRUE, prob = probability)
    sample_wave <- valid[sample_id, ]
    affected <- sample_wave[
      sample_wave$internet_disruption == 1 & is.finite(sample_wave$internet_loss_ratio_pct),
    ]
    positive <- affected[affected$internet_loss_ratio_pct > 0, ]
    if (!nrow(affected) || !nrow(positive)) return(NA_real_)
    mean(sample_wave$internet_disruption) *
      mean(affected$positive_internet_loss) *
      mean(positive$internet_loss_ratio_pct / 100)
  })
  estimates <- estimates[is.finite(estimates)]
  data.frame(
    replicates_requested = replicates,
    replicates_valid = length(estimates),
    lower_95 = as.numeric(stats::quantile(estimates, 0.025)),
    median = as.numeric(stats::quantile(estimates, 0.5)),
    upper_95 = as.numeric(stats::quantile(estimates, 0.975))
  )
}

build_provision_projection <- function(calibration, bootstrap, scenarios) {
  baseline <- calibration$expected_loss_ratio[[1]]
  rows <- lapply(seq_len(nrow(scenarios)), function(i) {
    assumption <- scenarios[i, ]
    years <- seq.int(assumption$projection_start_year, assumption$projection_end_year)
    step <- years - assumption$projection_start_year
    exposure <- assumption$portfolio_exposure_tnd_start *
      (1 + assumption$annual_exposure_growth)^step
    multiplier <- assumption$initial_risk_stress *
      (1 + assumption$annual_risk_trend)^step
    expected_ratio <- baseline * multiplier
    expected_loss <- exposure * expected_ratio
    provision <- expected_loss * (1 + assumption$prudence_margin)
    lower <- exposure * bootstrap$lower_95[[1]] * multiplier *
      (1 + assumption$prudence_margin)
    upper <- exposure * bootstrap$upper_95[[1]] * multiplier *
      (1 + assumption$prudence_margin)

    data.frame(
      scenario = assumption$scenario,
      scenario_label = assumption$scenario_label,
      projection_year = years,
      calibration_year = calibration$calibration_year[[1]],
      portfolio_exposure_tnd = exposure,
      initial_risk_stress = assumption$initial_risk_stress,
      annual_risk_trend = assumption$annual_risk_trend,
      annual_exposure_growth = assumption$annual_exposure_growth,
      expected_loss_ratio = expected_ratio,
      expected_loss_ratio_lower = bootstrap$lower_95[[1]] * multiplier,
      expected_loss_ratio_upper = bootstrap$upper_95[[1]] * multiplier,
      expected_economic_loss_tnd = expected_loss,
      prudence_margin = assumption$prudence_margin,
      risk_adjusted_provision_tnd = provision,
      risk_adjusted_provision_lower_tnd = lower,
      risk_adjusted_provision_upper_tnd = upper,
      cumulative_provision_tnd = cumsum(provision),
      interpretation = paste(
        "Conditional management scenario; not an operator forecast,",
        "statutory provision or booked insurance reserve."
      )
    )
  })
  dplyr::bind_rows(rows)
}
