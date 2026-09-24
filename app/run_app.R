# Open this file in RStudio and click Source, or run: Rscript run_app.R
balloon_launcher_file <- local({
  command <- grep("^--file=", commandArgs(FALSE), value = TRUE)
  if (length(command)) sub("^--file=", "", command[1]) else {
    frames <- sys.frames()
    files <- vapply(frames, function(frame) if (is.null(frame$ofile)) "" else frame$ofile, character(1))
    files <- files[nzchar(files)]
    if (length(files)) tail(files, 1) else "run_app.R"
  }
})
balloon_app_dir <- dirname(normalizePath(balloon_launcher_file, mustWork = TRUE))
balloon_minimum <- c(shiny = "1.8.0", ggplot2 = "4.0.0", scales = "1.3.0", jsonlite = "1.8.0")
balloon_required <- names(balloon_minimum)
balloon_missing <- balloon_required[!vapply(balloon_required, function(pkg) {
  requireNamespace(pkg, quietly = TRUE) && utils::packageVersion(pkg) >= package_version(balloon_minimum[[pkg]])
}, logical(1))]
if (length(balloon_missing)) {
  stop("Install or update the required packages first: install.packages(c(",
    paste(sprintf('"%s"', balloon_missing), collapse = ", "), "))", call. = FALSE)
}
options(gsea.balloon.local_folder = TRUE)
shiny::runApp(balloon_app_dir, host = "127.0.0.1", launch.browser = TRUE)
