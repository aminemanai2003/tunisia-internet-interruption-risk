library(targets)

tar_option_set(
  packages = c("broom", "dplyr", "ggplot2", "haven", "readr", "scales", "survey", "yaml"),
  format = "rds",
  error = "stop"
)
invisible(lapply(list.files("R", pattern = "[.]R$", full.names = TRUE), source))

list(
  tar_target(paths, project_paths()),
  tar_target(wbes_file, paths$wbes, format = "file"),
  tar_target(raw_wbes, load_wbes_panel(wbes_file)),
  tar_target(internet_panel, harmonise_internet_2024(raw_wbes)),
  tar_target(evidence, internet_evidence_2024(internet_panel)),
  tar_target(segments, segment_evidence(internet_panel)),
  tar_target(switching, switching_distribution(internet_panel)),
  tar_target(sample_gate, build_sample_gate(internet_panel)),
  tar_target(data_audit, build_data_audit(internet_panel)),
  tar_target(occurrence_model, fit_occurrence_glm(internet_panel)),
  tar_target(duration_model, fit_duration_model(internet_panel)),
  tar_target(
    coefficients,
    model_coefficients(occurrence = occurrence_model, duration = duration_model)
  ),
  tar_target(validation, repeated_cross_validation(internet_panel)),
  tar_target(calibration, estimate_2024_loss_ratio(internet_panel)),
  tar_target(bootstrap, bootstrap_loss_ratio(internet_panel)),
  tar_target(assumptions, readr::read_csv(paths$scenarios, show_col_types = FALSE)),
  tar_target(projections, build_provision_projection(calibration, bootstrap, assumptions)),
  tar_target(
    public_artifacts,
    write_public_artifacts(
      paths, evidence, segments, switching, sample_gate, coefficients,
      validation, data_audit, calibration, bootstrap, assumptions, projections
    ),
    format = "file"
  )
)
