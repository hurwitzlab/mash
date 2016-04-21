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

source $CONFIG

module load launcher/2.0

export PATH=$PATH:./bin

./scripts/dist.sh -i $OUT_DIR/sketches -o $OUT_DIR/dists
