#!/bin/bash

CWD=$(dirname "$0")
IMG="$CWD/mash-all-vs-all-0.0.6.img"
OUT_DIR="$(dirname $CWD)/data/mash-out"

if [[ ! -e "$IMG" ]]; then
    echo "Missing Singularity image \"$IMG\""
    exit 1
fi

echo run_mash "$@"
singularity exec -B /data:/data $IMG run_mash -o $OUT_DIR "$@"

