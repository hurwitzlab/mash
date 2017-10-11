#!/bin/bash

#SBATCH -J mash
#SBATCH -A iPlant-Collabs
#SBATCH -p normal
#SBATCH -t 24:00:00
#SBATCH -N 1
#SBATCH -n 1

set -u

ALIAS_FILE=""
EUC_DIST_PERCENT=0.1
METADATA_FILE=""
NUM_SCANS=10000
NUM_THREADS=12
OUT_DIR="$PWD/mash-out"
QUERY=""
FILES_LIST=""
SAMPLE_DIST=1000
IMG="mash-2.0.0.img"

export LAUNCHER_DIR="$HOME/src/launcher"
export LAUNCHER_PLUGIN_DIR="$LAUNCHER_DIR/plugins"
export LAUNCHER_WORKDIR="$PWD"
export LAUNCHER_RMI="SLURM"
export LAUNCHER_SCHED="interleaved"

function lc() {
  wc -l "$1" | cut -d ' ' -f 1
}

function HELP() {
  printf "Usage:\n  %s -q QUERY -o OUT_DIR\n\n" "$(basename "$0")"

  echo "Required arguments:"
  echo " -q QUERY (input FASTA file[s] or directory)"
  echo ""
  echo "Options (default in parentheses):"
  echo " -a ALIAS_FILE"
  echo " -d SAMPLE_DIST ($SAMPLE_DIST)"
  echo " -e EUC_DIST_PERCENT ($EUC_DIST_PERCENT)"
  echo " -m METADATA_FILE"
  echo " -o OUT_DIR ($OUT_DIR)"
  echo " -s NUM_SCANS ($NUM_SCANS)"
  echo " -t NUM_THREADS ($NUM_THREADS)"
  echo " -l FILES_LIST"
  echo ""
  exit 0
}

if [[ $# -eq 0 ]]; then
  HELP
fi

while getopts :a:d:e:l:m:o:q:s:t:h OPT; do
  case $OPT in
    a)
      ALIAS_FILE="$OPTARG"
      ;;
    d)
      SAMPLE_DIST="$OPTARG"
      ;;
    e)
      EUC_DIST_PERCENT="$OPTARG"
      ;;
    h)
      HELP
      ;;
    l)
      FILES_LIST="$OPTARG"
      ;;
    m)
      METADATA_FILE="$OPTARG"
      ;;
    o)
      OUT_DIR="$OPTARG"
      ;;
    q)
      QUERY="$QUERY $OPTARG"
      ;;
    s)
      NUM_SCANS="$OPTARG"
      ;;
    t)
      NUM_THREADS="$OPTARG"
      ;;
    :)
      echo "Error: Option -$OPTARG requires an argument."
      exit 1
      ;;
    \?)
      echo "Error: Invalid option: -${OPTARG:-""}"
      exit 1
  esac
done

if [[ ! -e "$IMG" ]]; then
    echo "Missing Singularity image \"$IMG\""
    exit 1
fi

#
# Mash sketching
#
if [[ -z "$QUERY" ]]; then
    echo "Must have a -q QUERY argument"
    exit 1
fi

IN_DIR=""
QUERY_FILES=$(mktemp)
for QRY in $QUERY; do
    if [[ -d "$QRY" ]]; then
        IN_DIR=$QRY
        find "$QRY" -type f -not -name .\* >> "$QUERY_FILES"
    elif [[ -f "$QRY" ]]; then
        IN_DIR=$(dirname "$QRY")
        echo "$QRY" >> "$QUERY_FILES"
    else 
        echo "QUERY ARG \"$QRY\" is neither dir nor file"
    fi
done

NUM_FILES=$(lc "$QUERY_FILES")

echo "Found \"$NUM_FILES\" files to index from \"$QUERY\""

if [[ $NUM_FILES -lt 1 ]]; then
    echo "No input files"
    exit 1
fi

[[ ! -d "$OUT_DIR" ]] && mkdir -p "$OUT_DIR"

SKETCH_DIR="$OUT_DIR/sketches"
[[ ! -d "$SKETCH_DIR" ]] && mkdir -p "$SKETCH_DIR"

#
# Sketch the input files
#
SKETCH_PARAM="$$.sketch.param"
cat /dev/null > "$SKETCH_PARAM"

i=0
while read -r FILE; do
    let i++
    BASENAME=$(basename "$FILE")
    #SKETCH_FILE="$SKETCH_DIR/$BASENAME"

    SKETCH_FILE=$(echo "$FILE" | perl -pe "s{$IN_DIR}{$SKETCH_DIR}")
    BASEDIR=$(dirname "$SKETCH_FILE")
    [[ ! -d "$BASEDIR" ]] && mkdir -p "$BASEDIR"

    if [[ -s "${SKETCH_FILE}.msh" ]]; then
        printf "%6d: Skipping %s \(sketch exists\)\n" $i "$BASENAME"
    else
        printf "%6d: Will sketch %s\n" $i "$(basename "$FILE")"
        echo "singularity exec $IMG mash sketch -p $NUM_THREADS -o $SKETCH_FILE $FILE" >> "$SKETCH_PARAM"
    fi
done < "$QUERY_FILES"
rm "$QUERY_FILES"

NJOBS=$(lc "$SKETCH_PARAM")
if [[ "$NJOBS" -gt 0 ]]; then
    echo "Starting launcher for \"$NJOBS\" sketch jobs"
    [[ $NJOBS -ge 16 ]] && export LAUNCHER_PPN=16
    [[ $NJOBS -ge 4 ]] && export LAUNCHER_PPN=4
    export LAUNCHER_JOB_FILE="$SKETCH_PARAM"
    "$LAUNCHER_DIR/paramrun"
    echo "Ended launcher for sketching"
fi
rm "$SKETCH_PARAM"

# 
# Find input files
# 
MSH_FILES=$(mktemp)
find "$SKETCH_DIR" -type f -name \*.msh > "$MSH_FILES"

NUM_MSH=$(lc "$MSH_FILES")

if [[ "$NUM_MSH" -lt 1 ]]; then
    echo "Error: Found no MSH files in SKETCH_DIR \"$SKETCH_DIR\"" 
    exit 1
fi

#
# Make SNA dir for all this
#
SNA_DIR="$OUT_DIR/sna"
[[ ! -d "$SNA_DIR" ]] && mkdir -p "$SNA_DIR"

ALL="$SNA_DIR/all"

if [[ ! -e "$ALL.msh" ]]; then
    echo "Will now paste \"$NUM_MSH\" Mash files."
    singularity exec "$IMG" mash paste -l "$ALL" "$MSH_FILES"
fi
ALL="$ALL.msh"

MASH_DISTANCE_MATRIX="$SNA_DIR/mash-dist.tab"
if [[ ! -e "$MASH_DISTANCE_MATRIX" ]]; then
    echo "Calculating distance"
    singularity exec "$IMG" mash dist -t "$ALL" "$ALL" > "$MASH_DISTANCE_MATRIX"
fi

rm "$ALL"
rm "$MSH_FILES"

META_DIR="$OUT_DIR/meta"
[[ ! -d "$META_DIR" ]] && mkdir -p "$META_DIR"

LIST_ARG=""
[[ -n "$FILES_LIST" ]] && LIST_ARG="-l $FILES_LIST"

if [[ -e "$METADATA_FILE" ]]; then
    echo "I see you have a metadata file make_metadata_dir.py"
    singularity exec "$IMG" make_metadata_dir.py \
        -f "$METADATA_FILE" \
        -d "$META_DIR" \
        --eucdistper "$EUC_DIST_PERCENT" \
        --sampledist "$SAMPLE_DIST" $LIST_ARG
fi

ALIAS_FILE_ARG=""
[[ -n "$ALIAS_FILE" ]] && ALIAS_FILE_ARG="-a $ALIAS_FILE"

echo "Fixing the matrix output from Mash fix_matrix.py"
singularity exec "$IMG" fix_matrix.py -m "$MASH_DISTANCE_MATRIX" -o "$SNA_DIR" $ALIAS_FILE_ARG

DIST_MATRIX="$SNA_DIR/distance.tab"
NEAR_MATRIX="$SNA_DIR/nearness.tab"

for F in $DIST_MATRIX $NEAR_MATRIX; do
    if [[ ! -e $F ]]; then
        echo "fix_matrix.py failed to create \"$F\""
        exit 1
    fi
done

echo "Running sna.r"
singularity exec "$IMG" sna.r -o "$SNA_DIR" -f "$NEAR_MATRIX" -n "$NUM_SCANS" $ALIAS_FILE_ARG

find "$SNA_DIR" \( -name Rplots.pdf -o -name Z -o -name gbme.out \) -exec rm {} \;

echo "Done, see OUT_DIR \"$OUT_DIR\""
echo "Comments to kyclark@email.arizona.edu"
