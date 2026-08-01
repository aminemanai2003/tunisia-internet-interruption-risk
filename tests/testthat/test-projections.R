test_that("projection preserves the actuarial identity", {
  calibration <- data.frame(calibration_year = 2024, expected_loss_ratio = 0.001)
  bootstrap <- data.frame(lower_95 = 0.0005, upper_95 = 0.002)
  scenarios <- data.frame(
    scenario = "persistent",
    scenario_label = "Persistent conditions",
    portfolio_exposure_tnd_start = 10000000,
    annual_exposure_growth = 0.02,
    initial_risk_stress = 1,
    annual_risk_trend = 0,
    prudence_margin = 0.2,
    projection_start_year = 2027,
    projection_end_year = 2028
  )
  result <- build_provision_projection(calibration, bootstrap, scenarios)
  expect_equal(result$expected_economic_loss_tnd[1], 10000)
  expect_equal(result$risk_adjusted_provision_tnd[1], 12000)
  expect_equal(result$cumulative_provision_tnd[2], sum(result$risk_adjusted_provision_tnd))
})

test_that("the initial stress applies in the projection start year", {
  calibration <- data.frame(calibration_year = 2024, expected_loss_ratio = 0.001)
  bootstrap <- data.frame(lower_95 = 0.0005, upper_95 = 0.002)
  scenarios <- data.frame(
    scenario = "systemic",
    scenario_label = "Systemic stress",
    portfolio_exposure_tnd_start = 10000000,
    annual_exposure_growth = 0,
    initial_risk_stress = 1.6,
    annual_risk_trend = 0.06,
    prudence_margin = 0,
    projection_start_year = 2027,
    projection_end_year = 2028
  )
  result <- build_provision_projection(calibration, bootstrap, scenarios)
  expect_equal(result$expected_loss_ratio, c(0.0016, 0.001696))
})
