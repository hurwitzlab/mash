#!/bin/bash

set -u

./00-controller.sh -f ${FASTA_DIR} -m ${METADATA_FILE} -o ${OUT_DIR:-"mash-out"} -d ${EUC_DIST_PERCENT:0.1} -s ${SAMPLE_DIST:1000}
