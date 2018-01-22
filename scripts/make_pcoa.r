#!/usr/bin/env Rscript

library("optparse")
library("vegan")

# set arguments
option_list = list (
    make_option(c("-d", "--dir"), 
                type = "character", 
                default = getwd(),
                help = "set work directory (%default)"
                ),  
    make_option(c("-f", "--file"), 
                type = "character", 
                default = "",
                help = "Input file", 
                metavar="character"
                ),
    make_option(c("-o", "--out"), 
                type = "character", 
                default = "pcoa.pdf",
                help="output file name (%default)"
                ),
    make_option(c("-n", "--number"), 
                type = "integer", 
                default = 1,
                help = "Total number of reads per sample (%default)"
                ),
    make_option(c("-t", "--title"), 
                type = "character", 
                default = "PCOA",
                help = "Title of PCoA plot (%default)"
                )
);

opt_parser = OptionParser(option_list = option_list)
opt        = parse_args(opt_parser)
out_dir    = opt$dir
infile     = opt$file
nreads     = opt$number
out_file   = opt$out
title      = opt$title

if (!dir.exists(out_dir)) {
    printf("Creating outdir '%s'\n", out_dir)
    dir.create(out_dir)
}

setwd(out_dir)

# check arguments
if (nchar(infile) == 0) {
    stop("Missing --file")
}

if (nreads < 1) {
    stop("--number (of reads) must be a positive integer")
}

# input fizkin matrix
fiz = as.data.frame(read.table(infile, header = TRUE))
#fiz = as.data.frame(read.table(infile, sep = ',', row.names = 1, header = TRUE))
#colnames(fiz) = row.names(fiz)

#print(fiz)

# scaling to mash range (0 to 1)
fiz = fiz/nreads

# make euclidean distance matrix 
fiz_dis = as.data.frame(as.matrix(dist(fiz, method = "euclidean")))

# calculate PCoA 
fiz_pcoa = rda(fiz_dis)

# calculating PCoA1% and PCoA2%
pcoa1_number = round(fiz_pcoa$CA$eig[1]/sum(fiz_pcoa$CA$eig)*100, digits = 2)
pcoa2_number = round(fiz_pcoa$CA$eig[2]/sum(fiz_pcoa$CA$eig)*100, digits = 2)

# make x-y label name
xlabel = paste("PCoA1", paste('(', pcoa1_number, '%', ')', sep=''))
ylabel = paste("PCoA2", paste('(', pcoa2_number, '%', ')', sep=''))

# plot PCoA
pdf(out_file, width = 6, height = 6)
biplot(fiz_pcoa,
       display = "sites",
       col     = "black",
       cex     = 2,
       xlab    = paste(xlabel),
       ylab    = paste(ylabel)
       )
points(fiz_pcoa,
       display = "sites",
       col     = "black",
       cex     = .5,
       pch     = 20
       )
title(main = title)
dev.off()
print(paste("Done, see", out_file))
