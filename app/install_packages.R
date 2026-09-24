# Run once in RStudio or with Rscript install_packages.R.
balloon_minimum <- c(shiny = "1.8.0", ggplot2 = "4.0.0", scales = "1.3.0", jsonlite = "1.8.0")
balloon_packages <- names(balloon_minimum)
balloon_missing <- balloon_packages[!vapply(balloon_packages, function(pkg) {
  requireNamespace(pkg, quietly = TRUE) && utils::packageVersion(pkg) >= package_version(balloon_minimum[[pkg]])
}, logical(1))]
if (length(balloon_missing)) install.packages(balloon_missing, repos = "https://cloud.r-project.org")
message("Installation step finished. Restart R if packages were updated, then open run_app.R and click Source.")
