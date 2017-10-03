#!/bin/bash

set -u

if [[ $# -ne 2 ]]; then
  printf " Usage: %s QRY_DIR OUT_DIR\n" $(basename $0)
  exit 1
fi

QRY_DIR=$1
OUT_DIR=$2

QUEUE="development"
TIME="02:00:00"

#QUEUE="normal"
#TIME="24:00:00"

sbatch -A iPlant-Collabs -N 1 -n 1 -t $TIME -p $QUEUE -J mash run.sh -q "$QRY_DIR" -o "$OUT_DIR"
