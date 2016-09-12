#!/bin/bash

set -u

CONFIG="config.sh"

if [[ $# -eq 1 ]]; then
  CONFIG=$1
fi

if [[ ! -s $CONFIG ]]; then
  echo "Missing CONFIG \"$CONFIG\""
  exit 1
fi

source "$CONFIG"

if [[ ${#OUT_DIR} -lt 1 ]]; then
  echo "OUT_DIR not defined"
  exit 1
fi

ARGS="-i $OUT_DIR/sketches -o $OUT_DIR/sna"

if [[ -n $FILES_LIST ]]; then
  ARGS="$ARGS -l $FILES_LIST"
fi

if [[ -n $ALIAS_FILE ]]; then
  ARGS="$ARGS -a $ALIAS_FILE"
fi

if [[ -n $NUM_GBME_SCANS ]]; then
  ARGS="$ARGS -n $NUM_GBME_SCANS"
fi

if [[ -n $EUC_DIST_PERCENT ]]; then
  ARGS="$ARGS -e $EUC_DIST_PERCENT"
fi

if [[ -n $SAMPLE_DIST ]]; then
  ARGS="$ARGS -s $SAMPLE_DIST"
fi

./scripts/sna.sh $ARGS
