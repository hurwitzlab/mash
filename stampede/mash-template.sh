#!/bin/bash

set -u

./00-controller.sh -q ${FASTA_DIR} -m ${METADATA_FILE} -o ${OUT_DIR:-"mash-out"} 
