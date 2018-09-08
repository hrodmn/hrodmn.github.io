local({
  knitr::opts_chunk$set(
    fig.path   = "./assets/images/",
    cache.path = "./cache/",
    collapse = TRUE
  )
  
  rmds = list.files('.', '[.]Rmd$', recursive = TRUE, full.names = TRUE)
  
  render_the_file <- function(file) {
    fn <- tail(strsplit(file, '/')[[1]], 1)
    outMarkdown <- gsub('.Rmd', '.md', fn)
    
    outFile <- file.path('..', '_posts', outMarkdown)
    
    rmarkdown::render(file, output_file = outFile)
  }
  
  lapply(rmds, render_the_file)
})