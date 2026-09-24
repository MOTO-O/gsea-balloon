# GSEA Balloon Plot — reusable plotting core
# Based on balloon_plot_v1.R by Motohiko Oshima and balloon_plot_multifile_v2_EN.R.
# Sourcing this file does not read files or create output.

balloon_version <- function() "1.2.0"

balloon_defaults <- function() list(
  geneset_column = "pathway", nes_column = "NES", padj_column = "padj",
  sep = "\t", file_encoding = "UTF-8-BOM", geneset_order = "first_file",
  geneset_padj_cutoff = NULL, top_n_genesets = NULL,
  highlight_padj = FALSE, highlight_padj_cutoff = 0.05,
  cluster_genesets = FALSE, cluster_samples = FALSE,
  cluster_distance = "euclidean", cluster_method = "complete",
  title = "Hallmark", output_prefix = "balloon_Hallmark", png_dpi = 300,
  nes_limits = NULL, color_lmh = c("dodgerblue3", "gray95", "darkorange3"),
  padj_size_limits = NULL, padj_floor = 1e-300, size_range = c(0.1, 3.3),
  show_nes_sign = FALSE, sign_size = 1.3, sign_color = "black",
  point_border = "gray40", point_stroke = 0.10,
  size_ti = 8, size_al = 6, size_at = 6, fs_leg_title = 6, fs_leg_text = 6,
  font_family = "sans", rect_size = 0.25, size_ticks = 0.25, len_ticks = 0.5,
  grid_major_size = 0.25, grid_major_color = "gray90", margin_size = 0.75,
  width_o = NULL, height_o = NULL, auto_cell_mm = 2.95,
  auto_width_padding_mm = 6, aspect = 1
)

abort <- function(...) stop(..., call. = FALSE)

is_auto_files <- function(files) {
  is.null(files) || identical(files, character(0)) ||
    (is.character(files) && length(files) == 1L && !is.na(files) &&
       !nzchar(trimws(files)))
}

resolve_input_files <- function(path, files = NULL, pattern = "\\.txt$") {
  if (!is_auto_files(files)) return(files) # Explicit file lists retain their order and do not use pattern.
  if (!is.character(path) || length(path) != 1L || is.na(path) || !dir.exists(path)) {
    abort("Input directory does not exist: ", path)
  }
  if (!is.character(pattern) || length(pattern) != 1L || is.na(pattern) || !nzchar(pattern)) {
    abort("Set file_pattern to a non-empty filename regular expression.")
  }
  candidates <- tryCatch(
    list.files(path, pattern = pattern, all.files = FALSE, full.names = FALSE,
               recursive = FALSE, ignore.case = TRUE),
    error = function(e) abort("Invalid file_pattern: ", conditionMessage(e))
  )
  candidates <- candidates[!dir.exists(file.path(path, candidates))]
  if (!length(candidates)) {
    abort("No files directly inside path match file_pattern.\npath: ", path,
          "\nfile_pattern: ", pattern)
  }
  sort(candidates, method = "radix")
}

get_comparison_names <- function(files, labels = NULL) {
  if (is.null(labels)) {
    stems <- tools::file_path_sans_ext(basename(files))
    labels <- sub("_[^_]*$", "", stems)
  }
  if (!is.character(labels) || length(labels) != length(files) ||
      anyNA(labels) || any(!nzchar(trimws(labels))) || anyDuplicated(labels)) {
    abort("Comparison labels are empty, duplicated, or have the wrong length. Edit the comparison labels in the file list.")
  }
  labels
}

read_gsea_inputs <- function(input_paths, original_names, labels = NULL,
                            geneset_column = "pathway", nes_column = "NES",
                            padj_column = "padj", sep = "\t",
                            encoding = "UTF-8-BOM", order = "first_file") {
  files <- original_names
  if (!is.character(files) || !length(files) || anyNA(files) ||
      any(!nzchar(trimws(files))) || anyDuplicated(files)) {
    abort("Select at least one file. Original filenames must be non-empty and unique.")
  }
  if (!is.character(input_paths) || length(input_paths) != length(files) || anyNA(input_paths)) {
    abort("Input paths and original filenames must have matching lengths.")
  }
  missing <- !file.exists(input_paths) | dir.exists(input_paths)
  if (any(missing)) abort("Input files are missing:\n", paste(input_paths[missing], collapse = "\n"))
  labels <- get_comparison_names(files, labels)
  required <- c(geneset_column, nes_column, padj_column)
  if (length(required) != 3L || anyNA(required) || anyDuplicated(required) || any(!nzchar(required))) {
    abort("Set geneset_column, nes_column, and padj_column to three different column names.")
  }
  if (!order %in% c("first_file", "alphabetical")) abort("Invalid geneset_order. Use first_file or alphabetical.")

  tables <- lapply(seq_along(files), function(i) {
    tab <- tryCatch(
      utils::read.delim(input_paths[i], sep = sep, check.names = FALSE,
                       stringsAsFactors = FALSE, fileEncoding = encoding,
                       na.strings = c("", "NA", "NaN"), comment.char = ""),
      error = function(e) abort(files[i], ": ", conditionMessage(e))
    )
    names(tab) <- sub("^\ufeff", "", trimws(names(tab)))
    if (anyDuplicated(names(tab))) abort(files[i], ": Duplicate column names.")
    if (!all(required %in% names(tab))) {
      abort(files[i], ": Missing required columns: ",
            paste(setdiff(required, names(tab)), collapse = ", "),
            "\nAvailable columns: ", paste(names(tab), collapse = ", "))
    }
    genesets <- trimws(as.character(tab[[geneset_column]]))
    if (!length(genesets) || anyNA(genesets) || any(!nzchar(genesets))) {
      abort(files[i], ": The geneset column is empty or contains missing/blank names.")
    }
    if (anyDuplicated(genesets)) {
      abort(files[i], ": Duplicate geneset names: ",
            paste(head(unique(genesets[duplicated(genesets)]), 10), collapse = ", "))
    }
    numeric_column <- function(column) {
      raw <- trimws(as.character(tab[[column]]))
      absent <- is.na(raw) | raw %in% c("", "NA", "NaN")
      value <- suppressWarnings(as.numeric(raw))
      if (any(!absent & !is.finite(value))) {
        abort(files[i], ": ", column, " contains non-numeric or infinite values.")
      }
      value[absent] <- NA_real_
      value
    }
    nes <- numeric_column(nes_column)
    padj <- numeric_column(padj_column)
    if (any(padj < 0 | padj > 1, na.rm = TRUE)) abort(files[i], ": padj must be between 0 and 1.")
    data.frame(geneset = genesets, comparison = labels[i], NES = nes,
               padj = padj, source_file = files[i], stringsAsFactors = FALSE)
  })

  # Align by geneset name rather than row number, so row order may differ between files.
  common <- Reduce(intersect, lapply(tables, function(x) x$geneset))
  if (!length(common)) abort("No genesets are shared by all input files.")
  if (order == "alphabetical") common <- sort(common)
  aligned <- lapply(tables, function(x) x[match(common, x$geneset), , drop = FALSE])
  data <- do.call(rbind, aligned)
  rownames(data) <- NULL
  data$NES_sign <- ifelse(is.na(data$NES), NA_character_,
                          ifelse(data$NES > 0, "+", ifelse(data$NES < 0, "-", "0")))
  data$plotted <- is.finite(data$NES) & is.finite(data$padj)
  if (!any(data$plotted)) abort("No plottable NES/padj pairs are available among the common genesets.")
  if (any(!data$plotted)) {
    warning(sum(!data$plotted), " cells will be blank because NES or padj is missing.",
            call. = FALSE)
  }
  data$comparison <- factor(data$comparison, levels = labels)
  data$geneset <- factor(data$geneset, levels = rev(common))
  summary <- data.frame(
    source_file = files, comparison = labels,
    input_genesets = vapply(tables, nrow, integer(1)),
    common_genesets = length(common),
    excluded_noncommon = vapply(tables, nrow, integer(1)) - length(common),
    missing_common_cells = vapply(aligned, function(x) sum(is.na(x$NES) | is.na(x$padj)), integer(1))
  )
  list(data = data, summary = summary, common_genesets = common)
}

resolve_limits <- function(values, specified, name, domain = c(-Inf, Inf)) {
  limits <- range(values[is.finite(values)])
  if (!is.null(specified)) {
    if (!is.numeric(specified) || length(specified) != 2L ||
        any(is.infinite(specified)) || any(is.nan(specified))) {
      abort(name, " must be NULL or c(minimum, maximum); use NA for an automatic endpoint.")
    }
    use <- !is.na(specified)
    limits[use] <- specified[use]
  }
  if (any(!is.finite(limits)) || limits[1] > limits[2] ||
      limits[1] < domain[1] || limits[2] > domain[2]) {
    abort(name, " has invalid limits. Check that minimum <= maximum and both values are in the allowed domain.")
  }
  limits
}

padj_size_values <- function(x, floor) {
  -log10(pmax(x, floor))
}

is_auto_dimension <- function(value) {
  is.null(value) || (is.numeric(value) && length(value) == 1L && is.na(value)) ||
    identical(value, NA)
}

check_dimension <- function(value, name) {
  if (is_auto_dimension(value)) return(invisible(NULL))
  if (!is.numeric(value) || length(value) != 1L || !is.finite(value) || value <= 0) {
    abort(name, " must be a positive number (mm), NULL, or NA.")
  }
}

measure_plot_size <- function(plot, width, height, cell_mm, padding_mm, aspect) {
  # Measure text with the same PDF device used for export. pdf(NULL) creates no file.
  grDevices::pdf(file = NULL, width = 7, height = 7)
  measure_device <- grDevices::dev.cur()
  on.exit(grDevices::dev.off(measure_device), add = TRUE)
  gt <- ggplot2::ggplotGrob(plot)
  fixed_width <- grid::convertWidth(sum(gt$widths), "mm", valueOnly = TRUE)
  fixed_height <- grid::convertHeight(sum(gt$heights), "mm", valueOnly = TRUE)
  panel <- ggplot2::ggplot_build(plot)$layout$panel_params[[1]]
  panel_width <- diff(panel$x.range) * cell_mm
  panel_height <- diff(panel$y.range) * cell_mm * aspect
  guides <- gt$grobs[grepl("^guide-box", gt$layout$name)]
  guide_height <- max(c(0, vapply(guides, function(x) {
    grid::convertHeight(grid::grobHeight(x), "mm", valueOnly = TRUE)
  }, numeric(1))))
  # Reserve enough height for the legends, even with few genesets.
  # When legends determine the height, omit extra horizontal padding to preserve cell spacing.
  auto_width <- fixed_width + panel_width + if (panel_height >= guide_height) padding_mm else 0
  auto_height <- fixed_height + max(panel_height, guide_height)
  list(
    width_mm = if (is_auto_dimension(width)) auto_width else width,
    height_mm = if (is_auto_dimension(height)) auto_height else height,
    width_auto = is_auto_dimension(width), height_auto = is_auto_dimension(height),
    cell_mm = cell_mm, fixed_width_mm = fixed_width, fixed_height_mm = fixed_height,
    guide_height_mm = guide_height
  )
}


validate_balloon_options <- function(options = list()) {
  defaults <- balloon_defaults()
  unknown <- setdiff(names(options), names(defaults))
  if (length(unknown)) abort("Unknown options: ", paste(unknown, collapse = ", "))
  defaults[names(options)] <- options
  o <- defaults
  for (key in c("size_ti", "size_al", "size_at", "fs_leg_title", "fs_leg_text", "sign_size")) {
    value <- o[[key]]
    if (!is.numeric(value) || length(value) != 1L || !is.finite(value) || value <= 0) abort(key, " must be positive.")
  }
  for (key in c("point_stroke", "len_ticks", "margin_size")) {
    value <- o[[key]]
    if (!is.numeric(value) || length(value) != 1L || !is.finite(value) || value < 0) abort(key, " must be non-negative.")
  }
  if (!is.character(o$title) || length(o$title) != 1L || is.na(o$title)) abort("Enter a plot title (an empty title is allowed).")
  if (!o$font_family %in% c("sans", "serif", "mono")) abort("Select a standard font family: sans, serif, or mono.")
  if (!is.logical(o$show_nes_sign) || length(o$show_nes_sign) != 1L || is.na(o$show_nes_sign)) abort("Invalid sign-label setting.")
  for (key in c("cluster_genesets", "cluster_samples", "highlight_padj")) {
    if (!is.logical(o[[key]]) || length(o[[key]]) != 1L || is.na(o[[key]])) abort("Invalid ", key, " setting.")
  }
  if (length(o$cluster_distance) != 1L || !o$cluster_distance %in% c("euclidean", "manhattan", "pearson")) abort("Invalid clustering distance.")
  if (length(o$cluster_method) != 1L || !o$cluster_method %in% c("complete", "average", "ward.D2")) abort("Invalid clustering linkage.")
  if ((o$cluster_genesets || o$cluster_samples) && o$cluster_method == "ward.D2" && o$cluster_distance != "euclidean") abort("Ward.D2 requires Euclidean distance.")
  for (key in c("geneset_padj_cutoff", "highlight_padj_cutoff")) {
    value <- o[[key]]
    if (key == "geneset_padj_cutoff" && is.null(value)) next
    if (!is.numeric(value) || length(value) != 1L || !is.finite(value) || value < 0 || value > 1)
      abort(key, " must be a number between 0 and 1.")
  }
  n <- o$top_n_genesets
  if (!is.null(n) && (!is.numeric(n) || length(n) != 1L || !is.finite(n) || n < 1 || n != floor(n)))
    abort("Top N must be a positive whole number, or blank for all genesets.")
  for (key in c("point_border", "sign_color", "grid_major_color")) grDevices::col2rgb(o[[key]])
  o
}

# Cluster raw, signed NES profiles before colour clipping; no imputation or scaling.
cluster_balloon_data <- function(data, options) {
  rows <- rev(levels(data$geneset))
  columns <- levels(data$comparison)
  mat <- matrix(NA_real_, length(rows), length(columns), dimnames = list(rows, columns))
  mat[cbind(match(data$geneset, rows), match(data$comparison, columns))] <- data$NES
  cluster_axis <- function(x, enabled, axis) {
    labels <- rownames(x)
    if (!enabled || nrow(x) < 2L) return(list(labels = labels,
      status = if (!enabled) "disabled" else "single object", tree = NULL))
    if (any(!is.finite(x))) abort(axis, " clustering requires finite NES for every shared geneset and comparison. Remove incomplete files/genesets or turn clustering off. Values are not imputed.")
    if (options$cluster_distance == "pearson") {
      if (ncol(x) < 2L || any(apply(x, 1, stats::sd) == 0))
        abort(axis, " Pearson distance requires at least two values and non-constant NES profiles. Choose Euclidean or Manhattan distance.")
      correlation <- stats::cor(t(x))
      if (any(!is.finite(correlation))) abort(axis, " Pearson correlations are not finite.")
      correlation[] <- pmax(0, pmin(2, 1 - correlation))
      distance <- stats::as.dist(correlation)
    } else distance <- stats::dist(x, method = options$cluster_distance)
    tree <- stats::hclust(distance, method = options$cluster_method)
    list(labels = labels[tree$order], status = "clustered",
      tree = list(labels = tree$labels, order = tree$order, merge = tree$merge,
                  height = tree$height, method = tree$method))
  }
  genesets <- cluster_axis(mat, options$cluster_genesets, "Geneset")
  samples <- cluster_axis(t(mat), options$cluster_samples, "Sample")
  data$geneset <- factor(data$geneset, levels = rev(genesets$labels))
  data$comparison <- factor(data$comparison, levels = samples$labels)
  list(data = data, metadata = list(basis = "raw signed NES; no scaling or imputation",
    distance = options$cluster_distance, linkage = options$cluster_method,
    genesets_top_to_bottom = genesets$labels, samples_left_to_right = samples$labels,
    genesets = genesets, samples = samples))
}

# Select by raw minimum padj across the INCLUDED comparisons. Missing values are
# ignored; all-missing genesets have NA minima and cannot pass an active filter.
select_balloon_genesets <- function(gsea, options) {
  common <- gsea$common_genesets
  minima <- vapply(common, function(name) {
    p <- gsea$data$padj[as.character(gsea$data$geneset) == name]
    p <- p[is.finite(p)]
    if (length(p)) min(p) else NA_real_
  }, numeric(1))
  ranking <- order(minima, common, na.last = TRUE, method = "radix")
  active <- !is.null(options$geneset_padj_cutoff) || !is.null(options$top_n_genesets)
  keep <- if (active) !is.na(minima) else rep(TRUE, length(common))
  if (!is.null(options$geneset_padj_cutoff)) keep <- keep & !is.na(minima) & minima <= options$geneset_padj_cutoff
  eligible <- sum(keep)
  if (!is.null(options$top_n_genesets)) {
    top <- head(ranking[keep[ranking]], options$top_n_genesets)
    keep <- seq_along(common) %in% top
  }
  if (!any(keep)) abort("No genesets match the minimum-padj cutoff. Increase the cutoff or disable the geneset filter.")
  retained <- common[keep]
  data <- gsea$data[as.character(gsea$data$geneset) %in% retained, , drop = FALSE]
  data$geneset <- factor(data$geneset, levels = rev(retained))
  if (!any(data$plotted)) abort("The selected genesets have no plottable NES/padj pairs. Change the geneset filter.")
  ranks <- match(seq_along(common), ranking)
  ranks[is.na(minima)] <- NA_integer_
  list(data = data, common_genesets = retained,
    metadata = list(basis = "minimum raw padj across included comparisons",
      cutoff = options$geneset_padj_cutoff, top_n = options$top_n_genesets,
      shared_before_filter = length(common), after_cutoff = eligible,
      displayed = length(retained), excluded = sum(!keep),
      tie_break = "geneset name (radix order); at most N genesets",
      ranking = data.frame(geneset = common, min_padj = unname(minima),
        rank = ranks, selected = keep, stringsAsFactors = FALSE)))
}

build_balloon_result <- function(gsea, options = list()) {
  options <- validate_balloon_options(options)
  with(options, {
    selected <- select_balloon_genesets(gsea, options)
    clustered <- cluster_balloon_data(selected$data, options)
    sc_tbl <- clustered$data
    valid <- sc_tbl$plotted
    
    nes_limits_used <- resolve_limits(sc_tbl$NES[valid], nes_limits, "nes_limits")
    if (!is.numeric(padj_floor) || length(padj_floor) != 1L ||
        !is.finite(padj_floor) || padj_floor <= 0 || padj_floor > 1) abort("padj_floor must be greater than 0 and at most 1.")
    if (!is.numeric(size_range) || length(size_range) != 2L ||
        any(!is.finite(size_range)) || size_range[1] < 0 || size_range[1] > size_range[2]) {
      abort("size_range must contain two numbers with 0 <= minimum <= maximum.")
    }
    if (length(color_lmh) != 3L) abort("Set color_lmh to three colours for negative NES, zero, and positive NES.")
    invisible(grDevices::col2rgb(color_lmh))
    if (length(output_prefix) != 1L || is.na(output_prefix) || !nzchar(output_prefix) ||
        grepl("[/\\\\]", output_prefix)) abort("output_prefix must be a non-empty filename without directory separators.")
    check_dimension(width_o, "width_o")
    check_dimension(height_o, "height_o")
    for (setting in c("aspect", "png_dpi", "auto_cell_mm")) {
      value <- get(setting)
      if (!is.numeric(value) || length(value) != 1L || !is.finite(value) || value <= 0) {
        abort(setting, " must be a positive number.")
      }
    }
    for (setting in c("rect_size", "size_ticks", "grid_major_size", "auto_width_padding_mm")) {
      value <- get(setting)
      if (!is.numeric(value) || length(value) != 1L || !is.finite(value) || value < 0) {
        abort(setting, " must be a non-negative number.")
      }
    }
    
    if (any(sc_tbl$padj[valid] < padj_floor)) {
      # Original padj values are retained; the summary records the number floored.
    }
    sc_tbl$neglog10_padj <- padj_size_values(sc_tbl$padj, padj_floor)
    padj_size_limits_used <- resolve_limits(sc_tbl$neglog10_padj[valid], padj_size_limits,
                                            "padj_size_limits", c(0, Inf))
    sc_tbl$NES_clipped <- sc_tbl$NES < nes_limits_used[1] | sc_tbl$NES > nes_limits_used[2]
    sc_tbl$padj_size_clipped <- sc_tbl$neglog10_padj < padj_size_limits_used[1] |
                               sc_tbl$neglog10_padj > padj_size_limits_used[2]
    # scale_size_continuous has no oob argument, so clamp the size values explicitly.
    # Keep the original NES, padj, and neglog10_padj; store clamped plotting values separately.
    sc_tbl$padj_size_for_plot <- pmin(pmax(sc_tbl$neglog10_padj, padj_size_limits_used[1]),
                                     padj_size_limits_used[2])
    if (highlight_padj) sc_tbl$padj_highlighted <- valid & !is.na(sc_tbl$padj) & sc_tbl$padj <= highlight_padj_cutoff
    plot_tbl <- sc_tbl[valid, , drop = FALSE]
    
    # Show a legend value even when an automatic range contains only one distinct value.
    legend_breaks <- function(limits) {
      if (limits[1] == limits[2]) return(limits[1])
      values <- pretty(limits, n = 4)
      values <- values[values >= limits[1] & values <= limits[2]]
      if (length(values) < 2L) unique(limits) else values
    }
    legend_labels <- function(x) vapply(x, function(y) format(y, digits = 3, trim = TRUE), character(1))
    # PDF line widths: ggplot2 multiplies linewidth by .pt to obtain lwd; PDF lwd=1 is 0.75 pt.
    # Use a line-specific conversion; the text pt/mm conversion would turn 0.25 pt into 0.1875 pt.
    # Here, pt means an Illustrator / PDF point (1/72 inch).
    pt_to_linewidth <- 1 / (0.75 * ggplot2::.pt)
    caption <- if (show_nes_sign) "Circle labels: + / - = NES direction; 0 = NES zero" else NULL
    
    point_layer <- ggplot2::geom_point(data = plot_tbl, ggplot2::aes(size = padj_size_for_plot, fill = NES),
      shape = 21, color = point_border, stroke = point_stroke)
    if (highlight_padj) {
      # geom_point: PDF width = stroke * ggplot2::.stroke / 2 * 0.75 pt.
      plot_tbl$outline_stroke <- ifelse(plot_tbl$padj_highlighted, 0.5 / (0.75 * ggplot2::.stroke / 2), point_stroke)
      plot_tbl$outline_colour <- ifelse(plot_tbl$padj_highlighted, "black", point_border)
      point_layer <- ggplot2::geom_point(data = plot_tbl,
        ggplot2::aes(size = padj_size_for_plot, fill = NES, colour = outline_colour, stroke = outline_stroke), shape = 21)
    }
    gg <- ggplot2::ggplot(sc_tbl, ggplot2::aes(x = comparison, y = geneset)) +
      point_layer +
      ggplot2::scale_size_continuous(name = expression(-log[10](padj)), range = size_range,
                                     limits = padj_size_limits_used,
                                     breaks = legend_breaks, labels = legend_labels) +
      ggplot2::scale_fill_gradient2(name = "NES", low = color_lmh[1], mid = color_lmh[2],
                                    high = color_lmh[3], midpoint = 0,
                                    limits = nes_limits_used, oob = scales::squish,
                                    breaks = legend_breaks, labels = legend_labels) +
      ggplot2::scale_x_discrete(drop = FALSE) +
      ggplot2::scale_y_discrete(drop = FALSE) +
      ggplot2::coord_fixed(ratio = aspect) +
      ggplot2::labs(title = title, x = NULL, y = NULL, caption = caption) +
      ggplot2::guides(fill = ggplot2::guide_colorbar(order = 1),
                      size = ggplot2::guide_legend(order = 2, override.aes = list(fill = "gray75", colour = point_border, stroke = point_stroke))) +
      ggplot2::theme_bw(base_family = font_family) +
      ggplot2::theme(
        plot.title = ggplot2::element_text(size = size_ti, face = "plain"),
        plot.caption = ggplot2::element_text(size = fs_leg_text, hjust = 0),
        axis.title = ggplot2::element_text(size = size_at),
        axis.text.x = ggplot2::element_text(size = size_al, color = "black", angle = 90,
                                           hjust = 1, vjust = 0.5,
                                           margin = ggplot2::margin(t = margin_size, unit = "mm")),
        axis.text.y = ggplot2::element_text(size = size_al, color = "black",
                                           margin = ggplot2::margin(r = margin_size, unit = "mm")),
        axis.ticks = ggplot2::element_line(linewidth = size_ticks * pt_to_linewidth),
        axis.ticks.length = grid::unit(len_ticks, "mm"),
        panel.grid.major = if (grid_major_size > 0) {
          ggplot2::element_line(color = grid_major_color, linewidth = grid_major_size * pt_to_linewidth)
        } else ggplot2::element_blank(),
        panel.grid.minor = ggplot2::element_blank(),
        panel.border = ggplot2::element_rect(color = "black", fill = NA, linewidth = rect_size * pt_to_linewidth),
        legend.title = ggplot2::element_text(size = fs_leg_title),
        legend.text = ggplot2::element_text(size = fs_leg_text),
        legend.key.height = grid::unit(3.5, "mm"),
        legend.key.width = grid::unit(3.5, "mm"),
        plot.margin = ggplot2::margin(5, 5, 5, 5, unit = "mm")
      )
    if (highlight_padj) gg <- gg + ggplot2::scale_colour_identity(guide = "none")
    if (show_nes_sign) {
      gg <- gg + ggplot2::geom_text(data = plot_tbl, ggplot2::aes(label = NES_sign),
                                    size = sign_size, color = sign_color,
                                    family = font_family, show.legend = FALSE)
    }
    
    plot_dimensions <- measure_plot_size(gg, width_o, height_o,
                                          auto_cell_mm, auto_width_padding_mm, aspect)
    width_used <- plot_dimensions$width_mm
    height_used <- plot_dimensions$height_mm
    

    list(
      plot = gg, data = sc_tbl, summary = gsea$summary,
      common_genesets = selected$common_genesets, dimensions = plot_dimensions,
      nes_limits = nes_limits_used, padj_size_limits = padj_size_limits_used,
      options = options, clustering = clustered$metadata, selection = selected$metadata,
      stats = list(comparisons = length(unique(sc_tbl$comparison)),
        genesets = length(selected$common_genesets), shared_genesets = length(gsea$common_genesets),
        highlighted_cells = if (highlight_padj) sum(sc_tbl$padj_highlighted) else 0L, circles = sum(valid), missing = sum(!valid),
        nes_clipped = sum(sc_tbl$NES_clipped[valid]),
        size_clipped = sum(sc_tbl$padj_size_clipped[valid]),
        padj_floored = sum(sc_tbl$padj[valid] < padj_floor)),
      created_at = format(Sys.time(), "%Y-%m-%d %H:%M:%S %Z")
    )
  })
}

create_balloon_result <- function(input_paths, original_names, labels = NULL, options = list()) {
  options <- validate_balloon_options(options)
  gsea <- read_gsea_inputs(input_paths, original_names, labels,
    options$geneset_column, options$nes_column, options$padj_column,
    options$sep, options$file_encoding, options$geneset_order)
  build_balloon_result(gsea, options)
}
