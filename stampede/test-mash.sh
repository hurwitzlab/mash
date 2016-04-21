#!/bin/bash

set -u

FASTA_DIR="$WORK/mouse/fasta"
MER_SIZE="20"
OUT_DIR="$WORK/mouse/mash-test"
METADATA_FILE="$WORK/mouse/meta2.tab"

./00-controller.sh -q $FASTA_DIR -o $OUT_DIR -m $METADATA_FILE
