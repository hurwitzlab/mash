#!/bin/bash

set -u

META=""
if [[ ${#METADATA_FILE} -gt 0 ]]; then
  META="-m ${METADATA_FILE}"
fi

./00-controller.sh -f ${FASTA_DIR} -o ${OUT_DIR:-"mash-out"} -d ${EUC_DIST_PERCENT:-0.1} -s ${SAMPLE_DIST:-1000} -x ${NUM_SCANS:-100000} $META
