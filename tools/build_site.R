# Open in RStudio and click Source, or: Rscript tools/build_site.R
balloon_build_file <- local({
  args <- grep('^--file=', commandArgs(FALSE), value=TRUE)
  if(length(args)) sub('^--file=', '', args[1]) else {
    files <- vapply(sys.frames(), function(x) if(is.null(x$ofile)) '' else x$ofile, character(1))
    files <- files[nzchar(files)]
    if(length(files)) tail(files,1) else 'tools/build_site.R'
  }
})
balloon_repo <- dirname(dirname(normalizePath(balloon_build_file, mustWork=TRUE)))
local({
  if (!requireNamespace('shinylive',quietly=TRUE)) stop('Install shinylive first: install.packages("shinylive")')
  app <- file.path(balloon_repo,'app')
  stage <- tempfile('balloon-source-');site <- tempfile('balloon-site-')
  dir.create(stage)
  on.exit(unlink(c(stage,site),recursive=TRUE),add=TRUE)
  # Only app code and synthetic examples are exported; tests and developer files are excluded.
  for(entry in c('app.R','R','www','examples')) {
    if(!all(file.copy(file.path(app,entry),stage,recursive=TRUE))) stop('Cannot stage ',entry)
  }
  shinylive::export(stage,site,wasm_packages=TRUE,template_params=list(title='GSEA Balloon Plot'))
  file.create(file.path(site,'.nojekyll'))
  version_env <- new.env();sys.source(file.path(app,'R/balloon_core.R'),version_env)
  version <- version_env$balloon_version()
  writeLines(c('GSEA Balloon Plot',paste('App version:',version),
    paste('Built with shinylive:',utils::packageVersion('shinylive')),
    paste('Shinylive assets:',shinylive::assets_version()),
    'Static site files are generated. Edit app/ and rebuild with tools/build_site.R.',
    'In the browser: click PDF, then the Save link to save your file.'),file.path(site,'README.txt'))
  # Keep the existing main / (root) Pages setting. Never write into .git or app/.
  entries <- list.files(site,all.files=TRUE,no..=TRUE)
  allowed <- c('index.html','app.json','shinylive-sw.js','shinylive','edit','.nojekyll','README.txt')
  if(length(setdiff(entries,allowed))) stop('Unexpected exporter output: ',paste(setdiff(entries,allowed),collapse=', '))
  for(entry in entries) {
    if(!all(file.copy(file.path(site,entry),balloon_repo,recursive=TRUE,overwrite=TRUE))) stop('Cannot copy ',entry)
  }
  writeLines(version,file.path(balloon_repo,'VERSION'))
  message('Updated local site files for v',version,'. Review changes, then Commit and Push when ready.')
})
