project_paths <- function(root = getwd()) {
  list(
    root = root,
    wbes = file.path(root, "data", "raw", "wbes", "Tunisia_2013_2020_2024.dta"),
    network_raw = file.path(root, "data", "raw", "network"),
    artifacts = file.path(root, "artifacts", "public"),
    figures = file.path(root, "artifacts", "public", "figures"),
    scenarios = file.path(root, "config", "scenarios.csv")
  )
}

missing_codes <- c(-9, -8, -7, -6, -5, -4, -3, -2, -1)

clean_numeric <- function(x) {
  value <- suppressWarnings(as.numeric(x))
  value[value %in% missing_codes] <- NA_real_
  value
}

weighted_mean_safe <- function(x, w) {
  ok <- is.finite(x) & is.finite(w) & w > 0
  if (!any(ok)) return(NA_real_)
  sum(x[ok] * w[ok]) / sum(w[ok])
}

weighted_quantile_safe <- function(x, w, probability = 0.5) {
  ok <- is.finite(x) & is.finite(w) & w > 0
  if (!any(ok)) return(NA_real_)
  x <- x[ok]
  w <- w[ok]
  ordering <- order(x)
  x <- x[ordering]
  w <- w[ordering]
  x[which(cumsum(w) / sum(w) >= probability)[1]]
}

effective_n <- function(w) {
  w <- w[is.finite(w) & w > 0]
  if (!length(w)) return(0)
  sum(w)^2 / sum(w^2)
}

ensure_output_dirs <- function(paths) {
  dir.create(paths$artifacts, recursive = TRUE, showWarnings = FALSE)
  dir.create(paths$figures, recursive = TRUE, showWarnings = FALSE)
  invisible(paths)
}
