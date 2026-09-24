balloon_browser_downloads <- function() {
  isTRUE(getOption("gsea.balloon.browser_downloads",
    grepl("emscripten|wasm", paste(R.version$platform, R.version$os), ignore.case = TRUE)))
}

balloon_download_button <- function(outputId, label, ...) {
  if (balloon_browser_downloads()) shiny::actionButton(paste0("prepare_", outputId), label, ...)
  else shiny::downloadButton(outputId, label, ...)
}

balloon_server <- function(local_folder = FALSE) {
  function(input, output, session) {
    inventory <- reactiveVal(NULL)
    input_kind <- reactiveVal("")
    generation <- reactiveVal(0L)
    result <- reactiveVal(NULL)
    feedback <- reactiveVal(NULL)
    pending_example <- reactiveVal(FALSE)
    input_value <- function(id, default) {
      value <- input[[id]]
      if (is.null(value)) default else value
    }
    set_inventory <- function(value, kind) {
      generation(generation() + 1L)
      value$key <- paste0(generation(), "_", value$id)
      inventory(value)
      input_kind(kind)
      result(NULL)
      feedback(NULL)
    }
    show_error <- function(error) {
      result(NULL)
      feedback(list(kind = "error", message = conditionMessage(error)))
    }
    observeEvent(input$files, {
      inventory(NULL)
      tryCatch(set_inventory(inventory_from_upload(input$files), "Selected files"), error = show_error)
    }, ignoreNULL = TRUE)
    observeEvent(input$input_source, {
      inventory(NULL)
      result(NULL)
      feedback(NULL)
    }, ignoreInit = TRUE)
    observeEvent(input$scan_folder, {
      inventory(NULL)
      tryCatch({
        if (!local_folder) abort("Folder access is available only in the local launcher.")
        set_inventory(inventory_from_folder(input$folder_path, input$file_pattern), "Local folder")
      }, error = show_error)
    })

    current_request <- reactive({
      inv <- inventory()
      if (is.null(inv)) abort("Select files or try the example first.")
      include <- vapply(inv$key, function(key) isTRUE(input_value(paste0("include_", key), TRUE)), logical(1))
      labels <- vapply(seq_len(nrow(inv)), function(i)
        input_value(paste0("label_", inv$key[i]), inv$comparison[i]), character(1))
      ranks <- vapply(seq_len(nrow(inv)), function(i)
        number_input(input_value(paste0("order_", inv$key[i]), i), "Comparison order"), numeric(1))
      selected <- select_inventory(inv, include, labels, ranks)
      num <- function(id, default, label) {
        value <- number_input(input_value(id, default), label)
        if (is.na(value)) abort(label, " cannot be blank.")
        value
      }
      sep <- switch(input_value("separator", "tab"), tab = "\t", comma = ",", semicolon = ";")
      optional_num <- function(id, label) {
        value <- number_input(input_value(id, ""), label)
        if (is.na(value)) NULL else value
      }
      options <- list(
        geneset_column = input_value("geneset_column", "pathway"),
        nes_column = input_value("nes_column", "NES"), padj_column = input_value("padj_column", "padj"),
        sep = sep, file_encoding = input_value("file_encoding", "UTF-8-BOM"),
        geneset_padj_cutoff = optional_num("geneset_padj_cutoff", "Minimum-padj cutoff"),
        top_n_genesets = optional_num("top_n_genesets", "Top N"),
        highlight_padj = input_value("highlight_padj", FALSE),
        highlight_padj_cutoff = num("highlight_padj_cutoff", 0.05, "Outline padj cutoff"),
        geneset_order = input_value("geneset_order", "first_file"),
        cluster_genesets = input_value("cluster_genesets", FALSE),
        cluster_samples = input_value("cluster_samples", FALSE),
        cluster_distance = input_value("cluster_distance", "euclidean"),
        cluster_method = input_value("cluster_method", "complete"),
        title = input_value("plot_title", "Hallmark"), output_prefix = input_value("output_prefix", "balloon_Hallmark"),
        nes_limits = range_inputs(input_value("nes_min", ""), input_value("nes_max", ""), "NES"),
        padj_size_limits = range_inputs(input_value("padj_min", ""), input_value("padj_max", ""), "-log10(padj)"),
        size_range = c(num("circle_min", 0.1, "Smallest circle"), num("circle_max", 3.3, "Largest circle")),
        color_lmh = c(input_value("colour_low", "dodgerblue3"), input_value("colour_mid", "gray95"), input_value("colour_high", "darkorange3")),
        show_nes_sign = input_value("show_nes_sign", FALSE),
        width_o = if (isTRUE(input_value("auto_width", TRUE))) NULL else num("width_mm", 120, "Width"),
        height_o = if (isTRUE(input_value("auto_height", TRUE))) NULL else num("height_mm", 180, "Height"),
        size_al = num("font_axis", 6, "Axis font size"), size_ti = num("font_title", 8, "Title font size"),
        fs_leg_text = num("font_legend", 6, "Legend font size"),
        fs_leg_title = num("font_legend_title", 6, "Legend title font size"),
        font_family = input_value("font_family", "sans"),
        rect_size = num("border_pt", 0.25, "Panel border"), size_ticks = num("ticks_pt", 0.25, "Axis ticks"),
        grid_major_size = num("grid_pt", 0.25, "Grid lines"),
        auto_cell_mm = num("cell_mm", 2.95, "Cell spacing"), aspect = num("aspect", 1, "Spacing ratio"),
        png_dpi = num("png_dpi", 300, "PNG resolution"), padj_floor = num("padj_floor", "1e-300", "padj floor")
      )
      list(selected = selected, options = options)
    })
    dirty <- reactive({
      old <- result()
      if (is.null(old)) return(FALSE)
      tryCatch(!identical(old$request, current_request()), error = function(e) TRUE)
    })
    build_now <- function() {
      tryCatch({
        request <- current_request()
        notices <- character()
        built <- withProgress(message = "Creating your plot", value = 0.3, {
          withCallingHandlers(create_balloon_result(request$selected$path,
            request$selected$filename, request$selected$comparison, request$options),
            warning = function(w) { notices <<- c(notices, conditionMessage(w)); invokeRestart("muffleWarning") })
        })
        built$request <- request
        built$warnings <- unique(notices)
        result(built)
        feedback(if (length(notices)) list(kind = "info", message = paste(unique(notices), collapse = "\n")) else NULL)
      }, error = show_error)
    }
    observeEvent(input$update_plot, build_now())
    observeEvent(input$load_example, {
      tryCatch({
        set_inventory(inventory_from_folder("examples", "\\.txt$"), "Example data")
        # Example files use the default schema; reset input-format controls only.
        updateSelectInput(session, "separator", selected = "tab")
        updateTextInput(session, "geneset_column", value = "pathway")
        updateTextInput(session, "nes_column", value = "NES")
        updateTextInput(session, "padj_column", value = "padj")
        updateSelectInput(session, "file_encoding", selected = "UTF-8-BOM")
        pending_example(TRUE)
      }, error = show_error)
    })
    observe({
      if (isTRUE(pending_example()) &&
          identical(input_value("separator", "tab"), "tab") &&
          identical(input_value("geneset_column", "pathway"), "pathway") &&
          identical(input_value("nes_column", "NES"), "NES") &&
          identical(input_value("padj_column", "padj"), "padj") &&
          identical(input_value("file_encoding", "UTF-8-BOM"), "UTF-8-BOM")) {
        pending_example(FALSE)
        isolate(build_now())
      }
    })

    output$file_count <- renderText({
      inv <- inventory()
      if (is.null(inv)) "No files selected" else paste(nrow(inv), "files ·", input_kind())
    })
    output$file_editor <- renderUI({
      inv <- inventory()
      if (is.null(inv)) return(div(class = "empty-files", "Your selected files will appear here."))
      div(class = "file-list", lapply(seq_len(nrow(inv)), function(i) {
        key <- inv$key[i]
        div(class = "file-row",
          checkboxInput(paste0("include_", key), "Include", TRUE),
          textInput(paste0("label_", key), "Comparison", inv$comparison[i]),
          numericInput(paste0("order_", key), "Order", i, min = 1, step = 1),
          p(class = "file-name", inv$filename[i]))
      }))
    })
    output$feedback <- renderUI({
      message <- feedback()
      if (!is.null(message)) return(div(class = paste("notice", message$kind), role = "alert", message$message))
      if (dirty()) div(class = "notice pending", "Settings have changed. Click Update plot to refresh the preview and downloads.")
    })
    output$metrics <- renderUI({
      x <- result()
      if (is.null(x)) return(NULL)
      metric <- function(value, label, class = "") div(class = paste("metric", class), strong(value), span(label))
      div(class = "metric-row", metric(x$stats$comparisons, "COMPARISONS"),
        metric(paste0(x$stats$genesets, " / ", x$stats$shared_genesets), "SHOWN / SHARED GENESETS"), metric(x$stats$circles, "CIRCLES"),
        metric(sprintf("%.1f × %.1f", x$dimensions$width_mm, x$dimensions$height_mm), "PDF SIZE / mm", "dimension"))
    })
    output$plot_state <- renderUI({
      if (is.null(result())) return(NULL)
      span(class = paste("status-pill", if (dirty()) "pending" else ""), if (dirty()) "Update needed" else "Ready to export")
    })
    output$preview_body <- renderUI({
      if (is.null(result())) {
        div(class = "empty-preview", div(class = "dot-matrix", lapply(seq_len(12), function(i) span())),
          h3("Your comparisons, in one view"),
          p("Select your result files and click Update plot, or try the example to explore the controls."))
      } else div(class = "preview-stage", imageOutput("preview_image"))
    })
    output$preview_image <- renderImage({
      x <- result()
      req(x)
      destination <- tempfile(fileext = ".png")
      export_balloon_plot(x, destination, "png", dpi = 144)
      list(src = destination, contentType = "image/png",
        width = round(x$dimensions$width_mm / 25.4 * 96),
        height = round(x$dimensions$height_mm / 25.4 * 96),
        alt = paste("GSEA balloon plot:", x$stats$genesets, "shared genesets across", x$stats$comparisons, "comparisons."))
    }, deleteFile = TRUE)
    output$resolved_ranges <- renderUI({
      x <- result()
      if (is.null(x)) return(NULL)
      format_range <- function(values) paste(format(signif(values, 4), trim = TRUE), collapse = " to ")
      div(class = "range-summary",
        paste0("NES: ", format_range(x$nes_limits), " · -log10(padj): ", format_range(x$padj_size_limits)), br(),
        paste0("Genesets excluded by filters: ", x$selection$excluded, " · Black outlines: ", x$stats$highlighted_cells), br(),
        paste0("Missing cells: ", x$stats$missing, " · Values at display limits: ",
          x$stats$nes_clipped, " NES / ", x$stats$size_clipped, " size · Floored padj: ", x$stats$padj_floored))
    })
    output$input_summary <- renderTable({
      x <- result()
      req(x)
      table <- x$summary
      names(table) <- c("File", "Comparison", "Input genesets", "Shared", "Not shared", "Missing cells")
      table
    }, striped = TRUE, bordered = FALSE, spacing = "s", rownames = FALSE)
    output$download_controls <- renderUI({
      if (is.null(result()) || dirty()) return(p(class = "field-help", "Update the plot to enable downloads."))
      div(class = "download-buttons", balloon_download_button("download_pdf", "PDF", class = "btn-primary"),
        balloon_download_button("download_png", "PNG"), balloon_download_button("download_data", "Plot data"),
        balloon_download_button("download_summary", "Input summary"), balloon_download_button("download_settings", "Settings"))
    })
    export_result <- function() {
      x <- isolate(result())
      if (is.null(x) || isTRUE(isolate(dirty()))) abort("Click Update plot before downloading.")
      x
    }
    # Deliver bytes over the existing Shiny connection; avoid virtual download URLs.
    browser_exports <- list(
      pdf = list(suffix = ".pdf", mime = "application/pdf", write = function(x, f) export_balloon_plot(x, f, "pdf")),
      png = list(suffix = ".png", mime = "image/png", write = function(x, f) export_balloon_plot(x, f, "png")),
      data = list(suffix = "_plot_data.tsv", mime = "text/tab-separated-values", write = function(x, f) export_balloon_table(x$data, f)),
      summary = list(suffix = "_input_summary.tsv", mime = "text/tab-separated-values", write = function(x, f) export_balloon_table(x$summary, f)),
      settings = list(suffix = "_settings.json", mime = "application/json", write = export_balloon_settings))
    if (balloon_browser_downloads()) {
      lapply(names(browser_exports), function(kind) {
        observeEvent(input[[paste0("prepare_download_", kind)]], {
          tryCatch({
            x <- export_result()
            spec <- browser_exports[[kind]]
            f <- tempfile(fileext = spec$suffix)
            on.exit(unlink(f), add = TRUE)
            spec$write(x, f)
            bytes <- readBin(f, "raw", n = file.info(f)$size)
            session$sendCustomMessage("balloon-file", list(
              filename = paste0(x$options$output_prefix, spec$suffix),
              mime = spec$mime, data = jsonlite::base64_enc(bytes)))
          }, error = function(e) showNotification(conditionMessage(e), type = "error"))
        }, ignoreInit = TRUE)
      })
      observe({
        if (is.null(result()) || dirty()) session$sendCustomMessage("balloon-file-clear", list())
      })
    }
    filename <- function(suffix) paste0(export_result()$options$output_prefix, suffix)
    output$download_pdf <- downloadHandler(filename = function() filename(".pdf"), contentType = "application/pdf",
      content = function(file) export_balloon_plot(export_result(), file, "pdf"))
    output$download_png <- downloadHandler(filename = function() filename(".png"), contentType = "image/png",
      content = function(file) export_balloon_plot(export_result(), file, "png"))
    output$download_data <- downloadHandler(filename = function() filename("_plot_data.tsv"), contentType = "text/tab-separated-values",
      content = function(file) export_balloon_table(export_result()$data, file))
    output$download_summary <- downloadHandler(filename = function() filename("_input_summary.tsv"), contentType = "text/tab-separated-values",
      content = function(file) export_balloon_table(export_result()$summary, file))
    output$download_settings <- downloadHandler(filename = function() filename("_settings.json"), contentType = "application/json",
      content = function(file) export_balloon_settings(export_result(), file))
  }
}
