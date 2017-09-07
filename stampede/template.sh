#!/bin/bash

set -u

# Usage:
#   run.sh -q QUERY -o OUT_DIR
# 
# Required arguments:
#  -q QUERY (input FASTA file[s] or directory)
# 
# Options (default in parentheses):
#  -a ALIAS_FILE
#  -d SAMPLE_DIST (1000)
#  -e EUC_DIST_PERCENT (0.1)
#  -m METADATA_FILE
#  -o OUT_DIR (/work/03137/kyclark/mash-0.0.4/stampede)
#  -s NUM_SCANS (10000)
#  -t NUM_THREADS (12)

ARGS="-q ${QUERY}"

if [[ -n $ALIAS_FILE ]]; then
  ARGS="$ARGS -a ${ALIAS_FILE}"
fi

if [[ -n $METADATA_FILE ]]; then
  ARGS="$ARGS -m ${METADATA_FILE}"
fi

sh run.sh $ARGS -o ${OUT_DIR:-"mash-out"} -e ${EUC_DIST_PERCENT:-0.1} -d ${SAMPLE_DIST:-1000} -s ${NUM_SCANS:-100000}
