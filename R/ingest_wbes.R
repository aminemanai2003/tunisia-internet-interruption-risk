load_wbes_panel <- function(path) {
  if (!file.exists(path)) {
    stop("Restricted WBES panel not found at: ", path)
  }
  haven::read_dta(path) |>
    as.data.frame()
}

combine_duration_hours <- function(hours_raw, minutes_raw) {
  hours <- clean_numeric(hours_raw)
  minutes <- clean_numeric(minutes_raw)
  result <- rep(NA_real_, length(hours))
  result[is.finite(hours) & hours > 0] <- hours[is.finite(hours) & hours > 0]
  minute_rows <- is.finite(hours) & hours == 0 & is.finite(minutes)
  result[minute_rows] <- minutes[minute_rows] / 60
  result
}

harmonise_internet_2024 <- function(raw) {
  required <- c(
    "panelid", "year", "wmedian", "a3a", "a4a", "a6a", "d2",
    "_2024_c39", "_2024_c40a", "_2024_c40b", "_2024_c41a",
    "_2024_c41b", "_2024_c42", "_2024_n2l"
  )
  absent <- setdiff(required, names(raw))
  if (length(absent)) stop("Missing WBES fields: ", paste(absent, collapse = ", "))

  year <- clean_numeric(raw$year)
  wave <- raw[year == 2024, , drop = FALSE]
  occurrence_raw <- suppressWarnings(as.numeric(wave$`_2024_c39`))
  switch_raw <- suppressWarnings(as.numeric(wave$`_2024_c42`))
  occurrence <- ifelse(
    occurrence_raw == 1, 1,
    ifelse(occurrence_raw == 2, 0, NA_real_)
  )
  connected <- ifelse(
    occurrence_raw == -7, 0,
    ifelse(occurrence_raw %in% c(1, 2), 1, NA_real_)
  )
  duration <- combine_duration_hours(wave$`_2024_c40a`, wave$`_2024_c40b`)
  loss_pct <- clean_numeric(wave$`_2024_c41a`)
  loss_value <- clean_numeric(wave$`_2024_c41b`)
  switch_label <- ifelse(
    switch_raw == -7, "Only one provider available",
    ifelse(switch_raw == 1, "Unable to switch",
      ifelse(switch_raw == 2, "Some difficulty",
        ifelse(switch_raw == 3, "Little difficulty",
          ifelse(switch_raw == 4, "No difficulty", NA_character_)
        )
      )
    )
  )
  switch_constraint <- ifelse(
    switch_raw %in% c(-7, 1, 2), 1,
    ifelse(switch_raw %in% c(3, 4), 0, NA_real_)
  )

  data.frame(
    observation_id = sprintf("wbes_2024_%04d", seq_len(nrow(wave))),
    panel_firm_id = as.character(wave$panelid),
    survey_year = 2024L,
    survey_weight = clean_numeric(wave$wmedian),
    region = factor(as.character(clean_numeric(wave$a3a))),
    sector = factor(as.character(clean_numeric(wave$a4a))),
    firm_size = factor(as.character(clean_numeric(wave$a6a))),
    annual_sales_tnd = clean_numeric(wave$d2),
    internet_connected = connected,
    internet_disruption = occurrence,
    disruption_duration_hours = duration,
    internet_loss_ratio_pct = loss_pct,
    internet_loss_value_tnd = loss_value,
    positive_internet_loss = ifelse(is.na(loss_pct), NA_real_, as.numeric(loss_pct > 0)),
    provider_switch_category = factor(
      switch_label,
      levels = c(
        "Only one provider available", "Unable to switch", "Some difficulty",
        "Little difficulty", "No difficulty"
      )
    ),
    provider_switch_constraint = switch_constraint,
    annual_broadband_cost_tnd = clean_numeric(wave$`_2024_n2l`),
    stringsAsFactors = FALSE
  )
}
