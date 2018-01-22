#!/bin/bash

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

echo "QUERY            \"${QUERY}\""
echo "ALIAS_FILE       \"${ALIAS_FILE}\""
echo "EUC_DIST_PERCENT \"${EUC_DIST_PERCENT}\""
echo "SAMPLE_DIST      \"${SAMPLE_DIST}\""
echo "NUM_SCANS        \"${NUM_SCANS}\""
echo "METADATA_FILE    \"${METADATA_FILE}\""

sh run.sh ${QUERY} ${ALIAS_FILE} ${EUC_DIST_PERCENT} ${SAMPLE_DIST} ${NUM_SCANS} ${METADATA_FILE}
