#!/bin/bash

set -u

ALIAS_FILE=""
EUC_DIST_PERCENT=0.1
METADATA_FILE=""
NUM_SCANS=10000
NUM_THREADS=12
OUT_DIR=$(pwd)
QUERY=""
SAMPLE_DIST=1000

function lc() {
  wc -l "$1" | cut -d ' ' -f 1
}

function HELP() {
  printf "Usage:\n  %s -q QUERY -o OUT_DIR\n\n" $(basename $0)

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
  echo ""
  exit 0
}

if [[ $# -eq 0 ]]; then
  HELP
fi

while getopts :a:d:e:m:o:q:s:t:h OPT; do
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
    m)
      METADATA_FILE="$OPTARG"
      ;;
    o)
      OUT_DIR="$OPTARG"
      ;;
    q)
      QUERY="$OPTARG"
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

CWD=$(cd $(dirname $0) && pwd)
SCRIPTS="$CWD/scripts.tgz"
if [[ -e $SCRIPTS ]]; then
  echo "Untarring $SCRIPTS to bin"
  if [[ ! -d bin ]]; then
    mkdir bin
  fi
  tar -C bin -xvf $SCRIPTS
fi

if [[ -e "$CWD/bin" ]]; then
  PATH="$CWD/bin:$PATH"
fi

#
# Mash sketching
#
QUERY_FILES=$(mktemp)
if [[ -d $QUERY  ]]; then
  find $QUERY -type f -not -name .\* > $QUERY_FILES
else
  echo $QUERY > $QUERY_FILES
fi

NUM_FILES=$(lc "$QUERY_FILES")

if [[ $NUM_FILES -lt 1 ]]; then
  echo "No input files"
  exit 1
fi

if [[ ! -d $OUT_DIR ]]; then
  mkdir -p "$OUT_DIR"
fi

SKETCH_DIR="$OUT_DIR/sketches"

if [[ ! -d $SKETCH_DIR ]]; then
  mkdir -p "$SKETCH_DIR"
fi

#
# Sketch the input files
#
PARAM="$$.param"
i=0
while read FILE; do
  let i++
  SKETCH_FILE="$SKETCH_DIR/$(basename $FILE)"
  if [[ -s "${SKETCH_FILE}.msh" ]]; then
    printf "%3d: SKETCH_FILE %s exists already.\n" $i $SKETCH_FILE.msh
  else
    printf "%3d: Will sketch %s\n" $i $(basename $FILE)
    echo "mash sketch -p $NUM_THREADS -o $SKETCH_FILE $FILE" >> $PARAM
  fi
done < $QUERY_FILES
rm "$QUERY_FILES"

ALL_QUERY="$OUT_DIR/all"

NJOBS=$(lc $PARAM)
export LAUNCHER_DIR="$HOME/src/launcher"
#export LAUNCHER_NJOBS=$(lc $PARAM)
#export LAUNCHER_NHOSTS=4
export LAUNCHER_PLUGIN_DIR=$LAUNCHER_DIR/plugins
export LAUNCHER_WORKDIR=$(pwd)
export LAUNCHER_RMI=SLURM
export LAUNCHER_JOB_FILE=$PARAM
export LAUNCHER_PPN=4
export LAUNCHER_SCHED=interleaved
echo "Starting launcher for \"$NJOBS\" sketch jobs"
$LAUNCHER_DIR/paramrun
echo "Ended launcher for sketching"
#rm $PARAM

SNA_ARGS="-i $SKETCH_DIR -o $OUT_DIR/sna -n $NUM_SCANS"
if [[ -n $ALIAS_FILE ]]; then
  SNA_ARGS="$SNA_ARGS -a $ALIAS_FILE"
fi

if [[ -n $EUC_DIST_PERCENT ]]; then
  SNA_ARGS="$SNA_ARGS -e $EUC_DIST_PERCENT"
fi

if [[ -n $METADATA_FILE ]]; then
  SNA_ARGS="$SNA_ARGS -m $METADATA_FILE"
fi

if [[ -n $SAMPLE_DIST ]]; then
  SNA_ARGS="$SNA_ARGS -s $SAMPLE_DIST"
fi

echo "sna.sh $SNA_ARGS" > $PARAM
#export LAUNCHER_NJOBS=1
#export LAUNCHER_NHOSTS=1
export LAUNCHER_PPN=1
echo "Starting launcher for SNA"
$LAUNCHER_DIR/paramrun
echo "Ended launcher for SNA"

exit

#
# Check for outliers, run again if necessary
#
for ITERATION in `seq 1 10`; do
  echo "ITERATION \"$ITERATION\" OUT_DIR \"$OUT_DIR\" FILES_LIST \"$FILES_LIST\""

  run-mash.sh "$REF_SKETCH_DIR" "$SKETCH_DIR" "$OUT_DIR" "$ITERATION" "$NUM_SCANS" "$FILES_LIST"

  if [[ ! -f $DIST ]]; then
    echo "Cannot find distance file \"$DIST\""
    exit 1
  fi

  echo "Checking for outliers ($ITERATION)"

  NO_OUTLIERS="$OUT_DIR/no-outliers-${ITERATION}.txt"
  RESULT=$(outliers.py -d "$DIST" -o "$NO_OUTLIERS")

  echo -e "$RESULT"

  if [[ $RESULT == "No outliers" ]]; then
    break
  elif [[ -s "$NO_OUTLIERS" ]]; then
    echo "Re-run Mash with \"$NO_OUTLIERS\""
    FILES_LIST="$NO_OUTLIERS"
  fi
done

echo "Done."
echo "Comments to kyclark@email.arizona.edu"
