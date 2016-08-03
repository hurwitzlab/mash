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

module load launcher/2.0

LIST_ARG=""
if [[ -n $FILES_LIST ]]; then
  LIST_ARG="-l $FILES_LIST"
fi

ALIAS_FILE_ARG=""
if [[ -n $ALIAS_FILE ]]; then
  ALIAS_FILE_ARG="-a $ALIAS_FILE"
fi

./scripts/sna.sh -i "$OUT_DIR/sketches" -o "$OUT_DIR/sna" -n $NUM_GBME_SCANS $LIST_ARG $ALIAS_FILE_ARG
