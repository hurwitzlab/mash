#!/bin/bash

ARGS="-q ${QUERY}"

if [[ -n $METADATA_FILE ]]; then
  ARGS="$ARGS -m ${METADATA_FILE}"
fi

if [[ -n $ALIAS_FILE ]]; then
  ARGS="$ARGS -a ${ALIAS_FILE}"
fi

run.sh $ARGS -o ${OUT_DIR:-"mash-out"} -d ${EUC_DIST_PERCENT:-0.1} -s ${SAMPLE_DIST:-1000} -x ${NUM_SCANS:-100000} ${META}
