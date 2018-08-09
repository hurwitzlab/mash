#!/usr/bin/env Rscript

suppressMessages(library("optparse"))
suppressMessages(library("ggdendro"))
suppressMessages(library("ggplot2"))
suppressMessages(library("vegan"))
suppressMessages(library("R.utils"))
suppressMessages(library("reshape2"))
suppressMessages(library("ape"))

# set arguments
option_list = list (
  make_option(c("-m", "--matrix"),
              type = "character",
              default = "",
              help = "Matrix file",
              metavar="character"
  ),
  make_option(c("-o", "--out_dir"),
              type = "character",
              default = '',
              help = "Output directory (--file dir)"
  ),
  make_option(c("-s", "--sort"),
              type = "logical",
              default = FALSE,
              action = "store_true",
              help = "Sort columns/rows"
  )
);

opt_parser  = OptionParser(option_list = option_list)
opt         = parse_args(opt_parser)
out.dir     = normalizePath(opt$out_dir)
matrix.file = normalizePath(opt$matrix)
sort.names  = opt$sort

# check arguments
if (nchar(matrix.file) == 0) {
  stop("Missing --matrix")
}

if (!file.exists(matrix.file)) {
  stop(paste("Bad matrix file", matrix.file))
}

if (nchar(out.dir) == 0) {
  out.dir = dirname(matrix.file)
}

if (!dir.exists(out.dir)) {
  dir.create(out.dir)
}

df = read.table(file = matrix.file, header = TRUE, check.names = F)

if (sort.names) {
  df = df[order(colnames(df)), order(colnames(df))]
}

#
# Dendrogram
#
print("Writing dendrogram")
dist.matrix = as.dist(1 - df)
fit = hclust(dist.matrix, method = "ward.D2")
dg = ggdendro::ggdendrogram(fit, rotate=T) + ggtitle("Dendrogram")
img.height = 5
num.samples = nrow(df)

if (num.samples > 25) {
  img.height = num.samples * .25
}

#options(bitmapType='cairo')
ggsave(file = file.path(out.dir, "dendrogram.png"),
       limitsize = FALSE, 
       width = 5, 
       height = img.height, 
       plot = dg)

#
# Write Newick, fan dendrogram
#
print("Writing dendrogram in Newick format")
write.tree(phy = as.phylo(fit), file = file.path(out.dir, "tree.newick"))
png(filename = file.path(out.dir, "dendrogram_fan.png"))
plot(as.phylo(fit), type = "fan")
invisible(dev.off())

#
# PCOA plot
#
print("Writing PCOA")
fiz_pcoa = rda(df)
p1 = round(fiz_pcoa$CA$eig[1]/sum(fiz_pcoa$CA$eig)*100, digits = 2)
p2 = round(fiz_pcoa$CA$eig[2]/sum(fiz_pcoa$CA$eig)*100, digits = 2)
xlabel = paste0("PCoA1 (", p1, "%)")
ylabel = paste0("PCoA2 (", p2, "%)")

pdf(file.path(out.dir, "pcoa.pdf"), 7, 7)
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
title(main = "PCOA")
invisible(dev.off())

# Heatmap
print("Writing heatmap")
tri.df = df
tri.df[upper.tri(tri.df)] = NA
counts = na.omit(melt(as.matrix(tri.df)))
colnames(counts) = c("s1", "s2", "value")

hm = ggplot(counts, aes(s1, s2)) +
  ggtitle('Shared Reads (Normalized)') +
  theme_bw() +
  xlab('Sample1') +
  ylab('Sample2') +
  geom_tile(aes(fill = value), color='white') +
  scale_fill_gradient(low = 'white',
                      high = 'darkblue',
                      space = 'Lab',
                      limits = c(0, 1)) +
  theme(axis.text.x = element_text(angle=45, hjust = 1),
        axis.ticks = element_blank(),
        axis.title.x = element_blank(),
        axis.title.y = element_blank(),
        axis.line = element_blank(),
        panel.border = element_blank(),
        panel.grid.major = element_blank())

ggsave(file = file.path(out.dir, "heatmap.png"), width = 5, height = 5, plot=hm)

printf("Done, see output in '%s'\n", out.dir)
