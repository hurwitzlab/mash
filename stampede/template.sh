#!/bin/bash

BIN=$(cd $(dirname $0) && pwd)

META=""
if [[ ${#METADATA_FILE} -gt 0 ]]; then
  META="-m ${METADATA_FILE}"
fi

$BIN/00-controller.sh -f ${FASTA_DIR} -o ${OUT_DIR:-"mash-out"} -d ${EUC_DIST_PERCENT:-0.1} -s ${SAMPLE_DIST:-1000} -x ${NUM_SCANS:-100000} ${META}
