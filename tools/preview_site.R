# Open in RStudio and click Source, or: Rscript tools/preview_site.R
command <- grep('^--file=',commandArgs(FALSE),value=TRUE)
files <- vapply(sys.frames(),function(x) if(is.null(x$ofile)) '' else x$ofile,character(1))
files <- files[nzchar(files)]
script <- if(length(command)) sub('^--file=','',command[1]) else if(length(files)) tail(files,1) else 'tools/preview_site.R'
repo <- dirname(dirname(normalizePath(script,mustWork=TRUE)))
if(!requireNamespace('httpuv',quietly=TRUE)) stop('Run install.packages("httpuv") first.')
httpuv::runStaticServer(repo,host='127.0.0.1',port=4786,browse=TRUE)
