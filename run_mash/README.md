# Run Mash

This program will run Mash on all your samples, then do an all-vs-all
pairwise comparison and create some visualizations so you can see how 
similar they are.

Required GNU Parallel and some R modules, see "../scripts/install.r."

Designed to be built and run from within a Singularity container 
(see "../singularity"), specifically to run as an "app" on the TACC
Stampede2 cluster (see "../stampede").

# Author

Ken Youens-Clark <kyclark@email.arizona.edu>
