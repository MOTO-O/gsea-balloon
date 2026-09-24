export_balloon_plot <- function(result, destination, format = c("pdf", "png"), dpi = NULL) {
  format <- match.arg(format)
  if (is.null(dpi)) dpi <- result$options$png_dpi
  device <- if (format == "pdf") "pdf" else function(filename, width, height, units, res, ...) {
    if (capabilities("cairo")) {
      grDevices::png(filename, width = width, height = height, units = units,
        res = res, type = "cairo", ...)
    } else {
      grDevices::png(filename, width = width, height = height, units = units, res = res, ...)
    }
  }
  ggplot2::ggsave(destination, plot = result$plot, device = device,
    width = result$dimensions$width_mm, height = result$dimensions$height_mm,
    units = "mm", dpi = dpi, bg = "white", limitsize = FALSE)
  invisible(destination)
}

export_balloon_table <- function(table, destination) {
  utils::write.table(table, destination, sep = "\t", quote = TRUE,
    row.names = FALSE, na = "NA", fileEncoding = "UTF-8")
}

balloon_manifest <- function(result) {
  list(app = "GSEA Balloon Plot", app_version = balloon_version(), created_at = result$created_at,
    input_files = as.character(result$summary$source_file),
    comparison_names = as.character(result$summary$comparison),
    selection = result$selection,
    clustering = result$clustering,
    options = result$options, nes_limits_used = result$nes_limits,
    padj_size_limits_used = result$padj_size_limits,
    dimensions = result$dimensions, statistics = result$stats,
    warnings = result$warnings,
    R = R.version.string,
    packages = as.list(vapply(c("shiny", "ggplot2", "scales", "jsonlite"),
      function(pkg) as.character(utils::packageVersion(pkg)), character(1))))
}

export_balloon_settings <- function(result, destination) {
  jsonlite::write_json(balloon_manifest(result), destination,
    auto_unbox = TRUE, pretty = TRUE, null = "null", na = "null", digits = NA)
}
