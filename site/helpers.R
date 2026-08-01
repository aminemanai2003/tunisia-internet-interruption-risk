project_root <- if (dir.exists(file.path("artifacts", "public"))) "." else ".."
public_path <- function(name) file.path(project_root, "artifacts", "public", name)

evidence <- read.csv(public_path("internet_evidence_2024.csv"), check.names = FALSE)
segments <- read.csv(public_path("segment_evidence.csv"), check.names = FALSE)
switching <- read.csv(public_path("switching_distribution.csv"), check.names = FALSE)
gate <- read.csv(public_path("sample_gate.csv"), check.names = FALSE)
validation <- read.csv(public_path("model_validation.csv"), check.names = FALSE)
ml_validation <- read.csv(public_path("ml_challenger_metrics.csv"), check.names = FALSE)
calibration <- read.csv(public_path("loss_calibration.csv"), check.names = FALSE)
bootstrap <- read.csv(public_path("bootstrap_uncertainty.csv"), check.names = FALSE)
assumptions <- read.csv(public_path("projection_assumptions.csv"), check.names = FALSE)
projections <- read.csv(public_path("internet_provision_projection.csv"), check.names = FALSE)
audit <- read.csv(public_path("data_audit.csv"), check.names = FALSE)
qos <- read.csv(public_path("int_qos_benchmark.csv"), check.names = FALSE)
operator_scope <- read.csv(public_path("int_mobile_campaign_scope.csv"), check.names = FALSE)
ripe <- read.csv(public_path("ripe_atlas_probe_snapshot.csv"), check.names = FALSE)
source_manifest <- read.csv(public_path("network_source_manifest.csv"), check.names = FALSE)

fmt_pct <- function(x, digits = 1) paste0(formatC(100 * x, digits = digits, format = "f"), "%")
fmt_ratio_pct <- function(x, digits = 3) paste0(formatC(100 * x, digits = digits, format = "f"), "%")
fmt_tnd <- function(x, digits = 0) paste0(formatC(x, digits = digits, format = "f", big.mark = " "), " TND")
fmt_num <- function(x, digits = 1) formatC(x, digits = digits, format = "f", big.mark = " ")

metric_value <- function(data, metric_name) data$mean_value[data$metric == metric_name][1]
metric_sd <- function(data, metric_name) data$sd_value[data$metric == metric_name][1]
projection_row <- function(scenario_name, year) {
  projections[projections$scenario == scenario_name & projections$projection_year == year, ][1, ]
}
