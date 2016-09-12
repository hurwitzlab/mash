#!/usr/bin/env Rscript 

library("optparse")
library("vegan")
library("igraph")
library("networkD3")
library("R.utils")

# --------------------------------------------------
fix_dist = function (file, alias_file) {
  lines = readLines(file)
  n = length(lines)
  delim = "\t"
  fixed = file.path(dirname(file), paste0(basename(file), '.fixed'))

  aliases = ""
  if (length(alias_file) > 0 & file.exists(alias_file)) {
    printf("Using alias file '%s'\n", alias_file)
    aliases = read.table(alias_file, header=T, as.is=T)
    for (i in 1:length(labels)) {
      label = labels[i]
      alias = aliases[aliases$name == label, "alias"]
      if (length(alias) > 0) {
        printf("Alias '%s' -> '%s'\n", label, alias)
        labels[i] = alias
      }
    }
  }

  sink(fixed)
  for (i in 1:n) {
    flds = strsplit(lines[i], delim)[[1]]
    
    # the header line has a comment char "#" we need to strip
    # also, the fields are full paths we need to reduce to basenames
    if (i == 1) {
      header = flds[2:n]
      basenames = unlist(lapply(header, basename))
      cat(paste(c("", basenames), collapse=delim), sep="\n")
    }
    # the first column has full path, so convert to basename
    else {
      cat(paste(c(basename(flds[1]), flds[2:n]), collapse=delim), sep="\n")
    }
  }
  sink()
  return(read.table(fixed))
}

# --------------------------------------------------
main = function () { 
  cwd = getwd()
  setwd(cwd)

  option_list = list(
    make_option(c("-f", "--file"),
                default=NULL, 
                type="character", 
                help="distance matrix", 
                metavar="character"),
    make_option(c("-o", "--outdir"),
                default=NULL, 
                type="character", 
                help="outdir", 
                metavar="character"),
    make_option(c("-w", "--workdir"),
                default=getwd(), 
                type="character", 
                help="workdir", 
                metavar="character"),
    make_option(c("-a", "--alias"),
                default=NULL,
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
  out_dir   = if (length(opt$outdir) > 1) opt$outdir else dirname(dist_file)
  dist      = fix_dist(dist_file, opt$alias)
  work_dir  = opt$workdir

  if (!file.exists(out_dir)) {
    printf("Creating outdir '%s'\n", out_dir)
    dir.create(out_dir)
  }

  setwd(work_dir)

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

  # create inverse (nearness) matrix for GBME
  matrix_path = file.path(out_dir, 'matrix.tab')
  write.table(1 - dist, matrix_path, quote=F, sep="\t")

  printf("Done, see output in '%s'\n", out_dir)
}

main()
