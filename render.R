local({
  knitr::opts_chunk$set(
    cache.path = "../cache/",
    collapse = TRUE
  )
  
  rmds = list.files("./R", "[.]Rmd$", recursive = TRUE, full.names = TRUE)
  
  render_the_file <- function(file) {
    fn <- tail(strsplit(file, "/")[[1]], 1)
    outMarkdown <- gsub(".Rmd", ".md", fn)
    outPrefix <- gsub(".Rmd", "_", fn)
    outFile <- file.path(".", "_posts", outMarkdown)
    
    base.dir <- "~/workspace/hrodmn.github.io"
    base.url <- "/"
    fig.path <- file.path("assets/images", outPrefix)
    
    rmarkdown::render(file,
                      output_file = outMarkdown,
                      output_options = list(self_contained = TRUE))
    file.rename(file.path("./R", outMarkdown),
                file.path("./_posts", outMarkdown))
  }
  
  lapply(rmds, render_the_file)
})
