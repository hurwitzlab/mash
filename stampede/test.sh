#!/bin/bash

#SBATCH -A iPlant-Collabs
#SBATCH -t 02:00:00
#SBATCH -N 1
#SBATCH -n 1
#SBATCH -J mashtest
#SBATCH -p development
#SBATCH --mail-type BEGIN,END,FAIL
#SBATCH --mail-user kyclark@email.arizona.edu

set -u

FASTA_DIR="$WORK/mouse/fasta"
MER_SIZE="20"
OUT_DIR="$WORK/mouse/mash-test"
METADATA_FILE="$WORK/mouse/meta2.tab"

#./00-controller.sh -f $FASTA_DIR -o $OUT_DIR -m $METADATA_FILE -p development -t 02:00:00
#./run.sh -q $FASTA_DIR -o $OUT_DIR -m $METADATA_FILE

#./run.sh -q $SCRATCH/frischkorn/fasta -o $SCRATCH/frischkorn/mash-out

./run.sh -q $SCRATCH/frischkorn/fastq -o $SCRATCH/frischkorn/mash-out-fq
