write_public_artifacts <- function(
    paths, evidence, segments, switching, gate, coefficients, validation,
    audit, calibration, bootstrap, assumptions, projections) {
  ensure_output_dirs(paths)

  outputs <- c(
    internet_evidence_2024 = file.path(paths$artifacts, "internet_evidence_2024.csv"),
    segment_evidence = file.path(paths$artifacts, "segment_evidence.csv"),
    switching_distribution = file.path(paths$artifacts, "switching_distribution.csv"),
    sample_gate = file.path(paths$artifacts, "sample_gate.csv"),
    model_coefficients = file.path(paths$artifacts, "model_coefficients.csv"),
    model_validation = file.path(paths$artifacts, "model_validation.csv"),
    data_audit = file.path(paths$artifacts, "data_audit.csv"),
    loss_calibration = file.path(paths$artifacts, "loss_calibration.csv"),
    bootstrap_uncertainty = file.path(paths$artifacts, "bootstrap_uncertainty.csv"),
    projection_assumptions = file.path(paths$artifacts, "projection_assumptions.csv"),
    internet_provision_projection = file.path(paths$artifacts, "internet_provision_projection.csv")
  )

  readr::write_csv(evidence, outputs[["internet_evidence_2024"]])
  readr::write_csv(segments, outputs[["segment_evidence"]])
  readr::write_csv(switching, outputs[["switching_distribution"]])
  readr::write_csv(gate, outputs[["sample_gate"]])
  readr::write_csv(coefficients, outputs[["model_coefficients"]])
  readr::write_csv(validation, outputs[["model_validation"]])
  readr::write_csv(audit, outputs[["data_audit"]])
  readr::write_csv(calibration, outputs[["loss_calibration"]])
  readr::write_csv(bootstrap, outputs[["bootstrap_uncertainty"]])
  readr::write_csv(assumptions, outputs[["projection_assumptions"]])
  readr::write_csv(projections, outputs[["internet_provision_projection"]])

  model_card <- list(
    project = "tunisia-internet-interruption-risk",
    version = "0.1.0",
    population = paste(
      "Formal Tunisian establishments represented by the 2024 World Bank",
      "Enterprise Survey with a valid connected-business response."
    ),
    purpose = paste(
      "Survey-weighted internet-interruption risk measurement,",
      "business-loss calibration and conditional planning provisions."
    ),
    validation = "Repeated stratified five-fold cross-validation within the 2024 wave.",
    severity_status = paste(
      "Empirical bootstrap calibration only; 16 positive percentage-loss responses",
      "are insufficient for a promoted severity GLM."
    ),
    ai_status = paste(
      "A non-linear challenger is evaluated but not promoted because the",
      "predeclared occurrence-event threshold is not met."
    ),
    operator_boundary = paste(
      "WBES contains no operator identifier. INT and RIPE Atlas evidence is",
      "contextual and is never joined to individual business losses."
    ),
    public_boundary = "Only aggregate artifacts are public; restricted WBES records remain local.",
    prohibited_interpretations = c(
      "official forecast by Tunisie Telecom, Ooredoo Tunisia or Orange Tunisia",
      "causal attribution or legal liability",
      "operator ranking from WBES losses",
      "national total economic loss",
      "commercial insurance premium",
      "statutory or booked reserve"
    )
  )
  yaml::write_yaml(model_card, file.path(paths$artifacts, "model_card.yml"))

  chain <- data.frame(
    component = factor(
      c("Disruption", "Positive loss | disruption", "Mean severity | positive loss"),
      levels = rev(c("Disruption", "Positive loss | disruption", "Mean severity | positive loss"))
    ),
    value = c(
      calibration$disruption_probability,
      calibration$positive_loss_probability_given_disruption,
      calibration$mean_positive_loss_ratio
    )
  )
  plot_chain <- ggplot2::ggplot(chain, ggplot2::aes(x = component, y = value)) +
    ggplot2::geom_col(fill = "#176B87", width = 0.62) +
    ggplot2::geom_text(
      ggplot2::aes(label = scales::percent(value, accuracy = 0.1)),
      hjust = -0.12, color = "#102F46", fontface = "bold", size = 4
    ) +
    ggplot2::coord_flip() +
    ggplot2::scale_y_continuous(
      labels = scales::percent_format(accuracy = 1),
      expand = ggplot2::expansion(mult = c(0, 0.22))
    ) +
    ggplot2::labs(
      x = NULL, y = "Survey-weighted estimate",
      title = "The three-stage actuarial loss chain"
    ) +
    ggplot2::theme_minimal(base_size = 12) +
    ggplot2::theme(
      panel.grid.major.y = ggplot2::element_blank(),
      plot.title = ggplot2::element_text(face = "bold", color = "#102F46")
    )
  ggplot2::ggsave(
    file.path(paths$figures, "actuarial-loss-chain.png"),
    plot_chain, width = 8, height = 4.8, dpi = 200, bg = "white"
  )

  plot_switching <- ggplot2::ggplot(
    switching,
    ggplot2::aes(
      x = stats::reorder(category, weighted_share), y = weighted_share,
      fill = category
    )
  ) +
    ggplot2::geom_col(show.legend = FALSE, width = 0.68) +
    ggplot2::geom_text(
      ggplot2::aes(label = scales::percent(weighted_share, accuracy = 0.1)),
      hjust = -0.1, color = "#102F46", fontface = "bold", size = 3.7
    ) +
    ggplot2::coord_flip() +
    ggplot2::scale_fill_manual(values = c("#BE3144", "#D95D39", "#E9A23B", "#64A6A6", "#176B87")) +
    ggplot2::scale_y_continuous(
      labels = scales::percent_format(accuracy = 1),
      expand = ggplot2::expansion(mult = c(0, 0.18))
    ) +
    ggplot2::labs(
      x = NULL, y = "Survey-weighted share",
      title = "Reported difficulty switching internet providers"
    ) +
    ggplot2::theme_minimal(base_size = 12) +
    ggplot2::theme(
      panel.grid.major.y = ggplot2::element_blank(),
      plot.title = ggplot2::element_text(face = "bold", color = "#102F46")
    )
  ggplot2::ggsave(
    file.path(paths$figures, "provider-switching.png"),
    plot_switching, width = 8, height = 5.2, dpi = 200, bg = "white"
  )

  plot_projection <- ggplot2::ggplot(
    projections,
    ggplot2::aes(
      x = projection_year,
      y = risk_adjusted_provision_tnd / 1000,
      color = scenario_label,
      group = scenario_label
    )
  ) +
    ggplot2::geom_ribbon(
      ggplot2::aes(
        ymin = risk_adjusted_provision_lower_tnd / 1000,
        ymax = risk_adjusted_provision_upper_tnd / 1000,
        fill = scenario_label
      ),
      alpha = 0.12, color = NA, show.legend = FALSE
    ) +
    ggplot2::geom_line(linewidth = 1.2) +
    ggplot2::geom_point(size = 2.4) +
    ggplot2::scale_color_manual(values = c(
      "Resilience improvement" = "#14866D",
      "Persistent conditions" = "#176B87",
      "Systemic stress" = "#BE3144"
    )) +
    ggplot2::scale_x_continuous(breaks = sort(unique(projections$projection_year))) +
    ggplot2::labs(
      x = NULL, y = "Annual planning provision (k TND)", color = NULL,
      title = "Conditional internet-risk provisions, 2027-2031"
    ) +
    ggplot2::theme_minimal(base_size = 12) +
    ggplot2::theme(
      legend.position = "bottom",
      plot.title = ggplot2::element_text(face = "bold", color = "#102F46")
    )
  ggplot2::ggsave(
    file.path(paths$figures, "provision-scenarios.png"),
    plot_projection, width = 8, height = 4.8, dpi = 200, bg = "white"
  )

  c(
    unname(outputs),
    file.path(paths$artifacts, "model_card.yml"),
    file.path(paths$figures, "actuarial-loss-chain.png"),
    file.path(paths$figures, "provider-switching.png"),
    file.path(paths$figures, "provision-scenarios.png")
  )
}
