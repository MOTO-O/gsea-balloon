# Preserve original filenames separately from Shiny's temporary upload paths.
make_inventory <- function(paths, filenames) {
  if (!length(paths) || length(paths) != length(filenames)) abort("Select at least one input file.")
  if (anyNA(filenames) || any(!nzchar(filenames)) || anyDuplicated(filenames)) {
    abort("Original filenames must be unique. Rename duplicate files before selecting them.")
  }
  if (any(!file.exists(paths) | dir.exists(paths))) abort("One or more selected files are no longer available. Select them again.")
  stems <- tools::file_path_sans_ext(basename(filenames))
  data.frame(id = seq_along(paths), path = paths, filename = filenames,
    comparison = sub("_[^_]*$", "", stems), stringsAsFactors = FALSE)
}

inventory_from_upload <- function(upload) {
  if (is.null(upload) || !nrow(upload)) abort("Select one or more GSEA result files.")
  indices <- order(upload$name, method = "radix")
  make_inventory(upload$datapath[indices], upload$name[indices])
}

inventory_from_folder <- function(path, pattern = "\\.txt$") {
  path <- path.expand(trimws(path))
  filenames <- resolve_input_files(path, files = NULL, pattern = pattern)
  make_inventory(file.path(path, filenames), filenames)
}

number_input <- function(value, label, blank = NA_real_) {
  if (is.null(value) || length(value) == 0L || (is.character(value) && !nzchar(trimws(value)))) return(blank)
  if (length(value) != 1L) abort(label, " must be a single number.")
  number <- suppressWarnings(as.numeric(value))
  if (!is.finite(number)) abort(label, " must be a finite number, or blank where automatic values are allowed.")
  number
}

range_inputs <- function(minimum, maximum, label) {
  values <- c(number_input(minimum, paste(label, "minimum")), number_input(maximum, paste(label, "maximum")))
  if (all(is.na(values))) NULL else values
}

select_inventory <- function(inventory, include, labels, ranks) {
  if (is.null(inventory)) abort("Select files or load the example first.")
  keep <- which(include)
  if (!length(keep)) abort("Include at least one comparison.")
  if (any(!is.finite(ranks[keep])) || any(ranks[keep] <= 0) || anyDuplicated(ranks[keep])) {
    abort("Included comparisons need unique, positive order numbers.")
  }
  keep <- keep[order(ranks[keep])]
  chosen <- inventory[keep, , drop = FALSE]
  chosen$comparison <- trimws(labels[keep])
  get_comparison_names(chosen$filename, chosen$comparison)
  chosen
}
