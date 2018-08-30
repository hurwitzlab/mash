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

FASTA_DIR="$WORK/data/dolphin/fasta"
ALIAS="$WORK/data/dolphin/alias.csv"
OUT_DIR="$WORK/data/dolphin/mash-out"

[[ -d "$OUT_DIR" ]] && rm -rf "$OUT_DIR"

#./run.sh -q "$FASTA_DIR" -o "$OUT_DIR" -a "$ALIAS"

./run.sh -q "$FASTA_DIR/Dolphin_1_z04.fa" "$FASTA_DIR/Dolphin_2_z09.fa" \
    "$FASTA_DIR/Dolphin_3_z11.fa" "$FASTA_DIR/Dolphin_4_z12.fa" \
    -o "$OUT_DIR" -a "$ALIAS"
