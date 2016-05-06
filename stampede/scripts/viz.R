#!/usr/bin/env Rscript 

library("optparse")
library("vegan")
library("igraph")
library("networkD3")

# --------------------------------------------------
fix_dist = function (file) {
  lines = readLines(file)
  n = length(lines)
  delim = "\t"
  fixed = file.path(dirname(file), paste0(basename(file), '.fixed'))
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
    make_option(c("-f", "--file"), type="character", default=NULL, 
                help="dataset file name", metavar="character"),
    make_option(c("-o", "--out"), type="character", default=cwd, 
                help="output file name [default= %default]", metavar="character")
  ); 
   
  opt_parser = OptionParser(option_list=option_list);
  opt = parse_args(opt_parser);

  if (is.null(opt$file)){
    print_help(opt_parser)
    stop("Missing -f input file.", call=FALSE)
  }

  if (!file.exists(opt$out)) {
    dir.create(opt$out)
  }

  dist_file = opt$file
  out_dir   = opt$out

  # file = "dist.tab"
  # dist = fix_dist(file)
  # dist = fix_dist("pov.dist.tab")
  # dist = fix_dist("foo.tab")
  dist = fix_dist(dist_file)
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

  # igraph tree
  #d = dist
  #d[d < .89] = 0
  #g = graph.adjacency(as.matrix(d), weighted=TRUE)
  #plot(g, vertex.color=NA, vertex.size=10, edge.arrow.size=0.5)
#  g_mst <- mst(dist, algorithm=prim)
#  png(file.path(out_dir, 'igraph-plot.png'))
#  plot(g_mst, vertex.color=NA, vertex.size=10, edge.arrow.size=0.5)
#  dev.off()

  # D3 viz
  #radialNetwork(as.radialNetwork(hc))

#  chordNetwork(as.matrix(g_mst))
#  dendroNetwork(hc)
#
#  library(reshape2)
#  nodes = colnames(dist)
#  links = melt(data.matrix(dist))
#
#  colnames(links) = c("source", "target", "value")
#  links$source = as.character(links$source)
#  links$target = as.character(links$target)
#  links = links[links$value > 0.7,]
#
#  for (i in 1:length(nodes)) {
#    node = nodes[i]
#    for (f in c("source", "target")) {
#      links[ links[[f]] == node, f] = i - 1
#    }
#  }
#  links$source = as.integer(links$source)
#  links$target = as.integer(links$target)
#
#  mynodes = data.frame(name=nodes)
#  mynodes$group = as.integer(substr(mynodes$name, 2, 2))
#
#  forceNetwork(Links = links, Nodes = mynodes, Source="source", Target="target",
#               Value = 'value', NodeID = "name", linkWidth = 1, Group = 'group',
#               linkColour = "#afafaf", fontSize=12, zoom=T, legend=T,
#               Nodesize=6, opacity = 0.8, charge=-300, 
#               width = 600, height = 400)
#
#  sankeyNetwork(Links = links, Nodes = mynodes, Source = 'source', Target = 'target', 
#    Value = 'value', NodeID = 'name', fontSize = 12, nodeWidth = 30)

  # create inverse (nearness) matrix for GBME
  write.table(1 - dist, file.path(out_dir, 'matrix.tab'), quote=F, sep="\t")
}

main()
