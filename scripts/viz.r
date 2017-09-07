#!/usr/bin/env Rscript 

library("optparse")
library("vegan")
library("igraph")
library("networkD3")
library("R.utils")
library("hash")

# --------------------------------------------------
main = function () { 
  cwd = getwd()
  setwd(cwd)

  option_list = list(
    make_option(c("-f", "--file"),
                default="", 
                type="character", 
                help="distance matrix", 
                metavar="character"),
    make_option(c("-o", "--outdir"),
                default="", 
                type="character", 
                help="outdir", 
                metavar="character"),
    make_option(c("-w", "--workdir"),
                default=getwd(), 
                type="character", 
                help="workdir", 
                metavar="character"),
    make_option(c("-a", "--alias"),
                default="",
                type="character", 
                help="aliases", 
                metavar="character")
  ); 
   
  opt_parser = OptionParser(option_list=option_list);
  opt = parse_args(opt_parser);

  if (is.null(opt$file)){
    print_help(opt_parser)
    stop("Missing -f input file.", call=FALSE)
  }

  dist_file = opt$file
  out_dir   = if (nchar(opt$outdir) > 1) opt$outdir else dirname(dist_file)
  dist      = read.table(dist_file)
  work_dir  = opt$workdir

  if (!file.exists(out_dir)) {
    printf("Creating outdir '%s'\n", out_dir)
    dir.create(out_dir)
  }

  setwd(work_dir)

  # create inverse (nearness) matrix for GBME
  matrix_path = file.path(out_dir, 'matrix.tab')
  write.table(1 - dist, matrix_path, quote=F, sep="\t")

  # dendrogram
  png(file.path(out_dir, 'dendrogram.png'), width=max(300, ncol(dist) * 20))
  hc = hclust(as.dist(as.matrix(dist)))
  plot(hc, xlab="Samples", main="Distances")
  dev.off()

  # heatmap
  png(file.path(out_dir, 'heatmap.png'))
  heatmap(as.matrix(dist))
  dev.off()

  # vegan tree
  png(file.path(out_dir, 'vegan-tree.png'))
  tree = spantree(as.dist(as.matrix(dist)))
  plot(tree, type="t")


  printf("Done, see output in '%s'\n", out_dir)
}

main()
