$ErrorActionPreference = "Stop"

python scripts/collect_public_network_context.py
python scripts/ml_challenger.py

$rscript = Get-Command Rscript -ErrorAction SilentlyContinue
if ($null -eq $rscript) {
    $candidate = Get-ChildItem "C:\Program Files\R" -Filter Rscript.exe -Recurse |
        Sort-Object FullName -Descending |
        Select-Object -First 1
    if ($null -eq $candidate) { throw "Rscript was not found." }
    $rscriptPath = $candidate.FullName
} else {
    $rscriptPath = $rscript.Source
}

& $rscriptPath scripts/run_pipeline.R
& $rscriptPath tests/testthat.R
& $rscriptPath scripts/check_public_release.R
quarto render
quarto render reports/actuarial-report-pdf.qmd

Write-Host "Pipeline, tests, privacy check, site and PDF completed."
