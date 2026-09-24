# Run from repository root: Rscript tests/test_features.R
app_dir <- if (dir.exists('app/R')) 'app' else 'gsea-balloon-app'
for (f in c('balloon_core.R','input_adapters.R','export_helpers.R','server.R','ui.R')) source(file.path(app_dir,'R',f))
expect_error <- function(expr, pattern) {
  msg <- tryCatch({force(expr);''},error=conditionMessage)
  stopifnot(grepl(pattern,msg,fixed=TRUE))
}
d <- tempfile('geneset-tests-');dir.create(d)
genes <- c('C','A','B','D','E')
padj <- list(c(.05,.02,.05,.9,NA), c(NA,.8,.05,.8,NA))
paths <- file.path(d,c('X_example.txt','Y_example.txt'))
for(i in 1:2) write.table(data.frame(pathway=genes,NES=c(1,-2,3,-1,1)*i,padj=padj[[i]]),paths[i],sep='\t',row.names=FALSE,quote=FALSE)
make <- function(opts=list(),indices=1:2) suppressWarnings(create_balloon_result(paths[indices],basename(paths[indices]),options=opts))
x <- make();stopifnot(x$stats$genesets==5,x$stats$shared_genesets==5)
y <- make(list(geneset_padj_cutoff=.05,top_n_genesets=2,highlight_padj=TRUE,highlight_padj_cutoff=.05))
stopifnot(identical(y$common_genesets,c('A','B')),y$stats$genesets==2,y$stats$highlighted_cells==3,
  y$selection$excluded==3,y$selection$after_cutoff==3)
stopifnot(identical(y$data$padj,c(.02,.05,.8,.05)),identical(y$data$NES,c(-2,3,-4,6)))
z <- make(list(geneset_padj_cutoff=.05));stopifnot(identical(z$common_genesets,c('C','A','B')))
z <- make(list(top_n_genesets=99));stopifnot(z$stats$genesets==4)
z <- make(list(geneset_padj_cutoff=.05,top_n_genesets=2),indices=2);stopifnot(identical(z$common_genesets,'B'))
expect_error(make(list(geneset_padj_cutoff=0)), 'No genesets match')
for(n in list(0,-1,1.5,NA,Inf)) expect_error(make(list(top_n_genesets=n)), 'Top N')
for(n in list(-.1,1.1,NA,Inf)) expect_error(make(list(geneset_padj_cutoff=n)), 'between 0 and 1')
z <- make(list(geneset_padj_cutoff=.05,top_n_genesets=2,cluster_genesets=TRUE,cluster_samples=TRUE))
stopifnot(z$clustering$genesets$status=='clustered',length(z$clustering$genesets_top_to_bottom)==2,length(z$clustering$samples_left_to_right)==2)
layer <- ggplot2::ggplot_build(y$plot)$data[[1]]
stopifnot(sum(layer$colour=='black')==3,all(abs(layer$stroke[layer$colour=='black']*.75*ggplot2::.stroke/2-.5)<1e-12))
m <- balloon_manifest(y);stopifnot(m$app_version=='1.2.0',m$selection$displayed==2,m$options$highlight_padj_cutoff==.05)
export_balloon_plot(y,Sys.getenv('BALLOON_TEST_PDF',tempfile(fileext='.pdf')))
# Native and browser button paths, dirty downloads, and reactive filter updates.
suppressPackageStartupMessages(library(shiny))
upload <- data.frame(name=basename(paths),datapath=paths,size=file.info(paths)$size,type='text/plain')
testServer(balloon_server(FALSE), {
  session$setInputs(files=upload,update_plot=1)
  session$setInputs(geneset_padj_cutoff='0.05',top_n_genesets='2',highlight_padj=TRUE)
  stopifnot(dirty())
  session$setInputs(update_plot=2)
  stopifnot(!dirty(),result()$stats$genesets==2,result()$stats$highlighted_cells==3)
  session$setInputs(top_n_genesets='0',update_plot=3)
  stopifnot(is.null(result()),grepl('Top N',feedback()$message))
})
options(gsea.balloon.browser_downloads=TRUE)
testServer(balloon_server(FALSE), {
  messages <- list()
  session$sendCustomMessage <- function(type,message) messages[[length(messages)+1L]] <<- list(type=type,message=message)
  session$setInputs(files=upload,geneset_padj_cutoff='0.05',top_n_genesets='2',highlight_padj=TRUE,update_plot=1)
  session$setInputs(prepare_download_pdf=1)
  msg <- tail(Filter(function(x)x$type=='balloon-file',messages),1)[[1]]$message
  stopifnot(rawToChar(jsonlite::base64_dec(msg$data)[1:5])=='%PDF-')
})
cat('PASS: cutoff boundaries, ranking/ties, missing values, comparison selection, clustering, outlines, settings, reactive inputs and browser PDF payload.\n')
