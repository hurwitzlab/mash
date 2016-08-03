#!/bin/bash

set -u

CONFIG="config.sh"

if [[ $# -eq 1 ]]; then
  CONFIG=$1
fi

if [[ ! -s "$CONFIG" ]]; then
  echo "Missing CONFIG \"$CONFIG\""
  exit 1
fi

source "$CONFIG"

module load launcher/2.0

LIST_ARG=""

if [[ -n $FILES_LIST ]]; then
  LIST_ARG="-l $FILES_LIST"
fi

./scripts/sketch.sh -f "$FASTA_DIR" -o "$OUT_DIR/sketches" $LIST_ARG
