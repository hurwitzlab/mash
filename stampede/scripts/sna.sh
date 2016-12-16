#!/bin/bash

set -u

echo "INVOCATION: $0 $@"

# 
# Argument defaults
# 
BIN="$( readlink -f -- "${0%/*}" )"
if [ -f $BIN ]; then
  BIN=$(dirname $BIN)
fi

IN_DIR=""
OUT_DIR=""
FILES_LIST=""
ALIAS_FILE=""
NUM_GBME_SCANS=""
SAMPLE_DIST=1000
EUC_DIST_PERCENT=0.1
METADATA_FILE=""
BAR="# ----------------------"

#
# Functions
#
function lc() {
  wc -l $1 | cut -d ' ' -f 1
}

function HELP() {
  printf "Usage:\n  %s -i IN_DIR -o OUT_DIR\n\n" $(basename $0)

  echo "Required Arguments:"
  echo " -i IN_DIR (where the msh files are)"
  echo " -o OUT_DIR (where to put SNA files)"
  echo " -n NUM_GBME_SCANS"
  echo
  echo "Options"
  echo " -a ALIAS_FILE"
  echo " -l FILES_LIST"
  echo " -m METADATA_FILE"
  echo " -s SAMPLE_DIST"
  echo " -e EUC_DIST_PERCENT"
  exit 0
}

if [[ $# == 0 ]]; then
  HELP
fi

#
# Setup
#
PROG=$(basename "$0" ".sh")
PARAMS_FILE="$BIN/${PROG}.params"

if [[ -e $PARAMS_FILE ]]; then
  echo Removing previous PARAMS_FILE \"$PARAMS_FILE\"
  rm $PARAMS_FILE
fi

echo "Invocation: $0 $@" 

#
# Get args
#
while getopts :a:e:i:l:m:n:o:s:h OPT; do
  case $OPT in
    a)
      ALIAS_FILE="$OPTARG"
      ;;
    e)
      EUC_DIST_PERCENT="$OPTARG"
      ;;
    i)
      IN_DIR="$OPTARG"
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
    n)
      NUM_GBME_SCANS="$OPTARG"
      ;;
    o)
      OUT_DIR="$OPTARG"
      ;;
    s)
      SAMPLE_DIST="$OPTARG"
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

#
# Check args
#
if [[ ${#IN_DIR} -lt 1 ]]; then
  echo "Error: No IN_DIR specified." 
  exit 1
fi

if [[ ${#OUT_DIR} -lt 1 ]]; then
  echo "Error: No OUT_DIR specified." 
  exit 1
fi

if [[ ! -d $IN_DIR ]]; then
  echo "Error: IN_DIR \"$IN_DIR\" does not exist." 
  exit 1
fi

echo OUT_DIR \"$OUT_DIR\"
if [[ -d $OUT_DIR ]]; then
  rm -rf $OUT_DIR/*
else 
  mkdir -p $OUT_DIR
fi

# 
# Find input files
# 
MSH_FILES=$(mktemp)
if [[ -n $FILES_LIST ]]; then
  echo Taking files from list \"$FILES_LIST\" 
  cat -n $FILES_LIST
  while read FILE; do
    BASENAME=$(basename $FILE)
    FILE_PATH="$IN_DIR/$BASENAME.msh"
    if [[ -e $FILE_PATH ]]; then
      echo $FILE_PATH >> $MSH_FILES
    else
      echo Cannot find \"$BASENAME\" in \"$IN_DIR\" 
    fi
  done < $FILES_LIST
else 
  find $IN_DIR -type f -name \*.msh > $MSH_FILES
fi

NUM_FILES=$(lc $MSH_FILES)

if [[ $NUM_FILES -lt 1 ]]; then
  echo "Error: Found no MSH files in IN_DIR \"$IN_DIR\"" 
  exit 1
fi

echo $BAR                  
echo Settings for run:     
echo "IN_DIR     $IN_DIR"  
echo "OUT_DIR    $OUT_DIR" 
echo $BAR                  
echo "Will process $NUM_FILES msh files" 
cat -n $MSH_FILES          

ALL=$OUT_DIR/all
if [[ -e $ALL.msh ]]; then
  rm $ALL.msh
fi

mash paste -l $ALL $MSH_FILES
ALL=$ALL.msh
MASH_DISTANCE_MATRIX=$OUT_DIR/mash-dist.tab
mash dist -t $ALL $ALL > $MASH_DISTANCE_MATRIX
rm $ALL

META_DIR=$OUT_DIR/meta
LIST_ARG=""
if [[ -n $FILES_LIST ]]; then
  LIST_ARG="-l $FILES_LIST"
fi

if [[ -e $METADATA_FILE ]]; then
  echo ">>> make-metadata-dir.pl"
  $BIN/make-metadata-dir.pl -f $METADATA_FILE -d $META_DIR $LIST_ARG --eucdistper $EUC_DIST_PERCENT --sampledist $SAMPLE_DIST
fi

ALIAS_FILE_ARG=""
if [[ ${#ALIAS_FILE} -gt 0 ]]; then
  ALIAS_FILE_ARG="--alias=$ALIAS_FILE"
fi

# this will fix the matrix
$BIN/fix-matrix.pl6 --matrix=$MASH_DISTANCE_MATRIX --precision=4 $ALIAS_FILE_ARG

DIST_MATRIX=$OUT_DIR/distance.tab
NEAR_MATRIX=$OUT_DIR/distance.tab

for F in $DIST_MATRIX $NEAR_MATRIX; do
  if [[ ! -e $F ]]; then
    echo "fix-matrix.pl6 failed to create \"$F\""
    exit 1
  fi
done

# this will invert distance into nearness
echo ">>> viz.r"
$BIN/viz.r -f $DIST_MATRIX -o $OUT_DIR

echo ">>> sna.r"
echo $BIN/sna.r -o $OUT_DIR -f $NEAR_MATRIX -n $NUM_GBME_SCANS $ALIAS_FILE_ARG
$BIN/sna.r -o "$OUT_DIR" -f "$NEAR_MATRIX" -n $NUM_GBME_SCANS $ALIAS_FILE_ARG

for F in Rplots.pdf Z gbme.out; do
  P=$OUT_DIR/$F
  if [[ -e $P ]]; then
    rm $P
  fi
done

echo Done.
