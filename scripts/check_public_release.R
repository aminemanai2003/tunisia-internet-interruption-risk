forbidden_fields <- c(
  "panel_firm_id", "observation_id", "annual_sales_tnd",
  "internet_loss_value_tnd"
)
public_files <- list.files("artifacts/public", recursive = TRUE, full.names = TRUE)
public_csv <- public_files[grepl("[.]csv$", public_files)]

for (path in public_csv) {
  header <- names(read.csv(path, nrows = 1, check.names = FALSE))
  bad <- intersect(header, forbidden_fields)
  if (length(bad)) {
    stop("Restricted field(s) found in ", path, ": ", paste(bad, collapse = ", "))
  }
}

segment_path <- file.path("artifacts", "public", "segment_evidence.csv")
if (file.exists(segment_path)) {
  segments <- read.csv(segment_path)
  if (any(segments$raw_n < 30) || any(segments$disruption_events < 5)) {
    stop("A segment-level public row violates the minimum disclosure threshold.")
  }
}

tracked <- system2("git", c("ls-files", "data/raw"), stdout = TRUE)
tracked <- tracked[nzchar(tracked) & !grepl("[.]gitkeep$", tracked)]
if (length(tracked)) stop("Raw data are tracked by Git: ", paste(tracked, collapse = ", "))

tracked_files <- system2("git", "ls-files", stdout = TRUE)
tracked_files <- tracked_files[file.exists(tracked_files)]
text_files <- tracked_files[!grepl("[.](png|pdf|svg|dta)$", tracked_files, ignore.case = TRUE)]
if (length(text_files)) {
  contents <- paste(vapply(text_files, function(path) {
    paste(readLines(path, warn = FALSE, encoding = "UTF-8"), collapse = "\n")
  }, character(1)), collapse = "\n")
  if (grepl("gh[pousr]_[A-Za-z0-9]{20,}", contents)) {
    stop("A GitHub credential-like string is present in tracked text.")
  }
}

cat("Public release, disclosure and credential checks passed.\n")
