# GSEA Balloon Plot — local Shiny and Shinylive entry point.
# Original plotting template: Motohiko Oshima.
suppressPackageStartupMessages({
  library(shiny)
  library(ggplot2)
  library(scales)
  library(jsonlite)
})
if (utils::packageVersion("ggplot2") < "4.0.0") {
  stop('This app requires ggplot2 >= 4.0.0. Run install.packages("ggplot2") and restart R.')
}

for (file in c("balloon_core.R", "input_adapters.R", "export_helpers.R", "ui.R", "server.R")) {
  source(file.path("R", file), local = TRUE)
}
options(shiny.maxRequestSize = 100 * 1024^2)
local_folder_enabled <- isTRUE(getOption("gsea.balloon.local_folder", FALSE)) &&
  !grepl("emscripten|wasm", paste(R.version$platform, R.version$os), ignore.case = TRUE)
shinyApp(balloon_ui(local_folder_enabled), balloon_server(local_folder_enabled))
