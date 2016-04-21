#!/bin/bash

set -u

# 
# Argument defaults
# 
BIN="$( readlink -f -- "${0%/*}" )"
if [ -f $BIN ]; then
  BIN=$(dirname $BIN)
fi

IN_DIR=""
OUT_DIR=""
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
  echo " -i IN_DIR (where the dist files are)"
  echo " -o OUT_DIR (where to put SNA files)"
  echo
  exit 0
}

if [[ $# == 0 ]]; then
  HELP
fi

#
# Setup
#
PROG=$(basename "$0" ".sh")
LOG="$BIN/launcher-$PROG.log"
PARAMS_FILE="$BIN/${PROG}.params"

if [[ -e $LOG ]]; then
  rm $LOG
fi

if [[ -e $PARAMS_FILE ]]; then
  echo Removing previous PARAMS_FILE \"$PARAMS_FILE\" >> $LOG
  rm $PARAMS_FILE
fi

echo $BAR >> $LOG
echo "Invocation: $0 $@" >> $LOG

#
# Get args
#
while getopts :i:o:h OPT; do
  case $OPT in
    i)
      IN_DIR="$OPTARG"
      ;;
    h)
      HELP
      ;;
    o)
      OUT_DIR="$OPTARG"
      ;;
    :)
      echo "Error: Option -$OPTARG requires an argument." >> $LOG
      exit 1
      ;;
    \?)
      echo "Error: Invalid option: -${OPTARG:-""}" >> $LOG
      exit 1
  esac
done

#
# Check args
#
if [[ ${#IN_DIR} -lt 1 ]]; then
  echo "Error: No IN_DIR specified." >> $LOG
  exit 1
fi

if [[ ${#OUT_DIR} -lt 1 ]]; then
  echo "Error: No OUT_DIR specified." >> $LOG
  exit 1
fi

if [[ ! -d $IN_DIR ]]; then
  echo "Error: IN_DIR \"$IN_DIR\" does not exist." >> $LOG
  exit 1
fi

if [[ ! -d $OUT_DIR ]]; then
  mkdir -p $OUT_DIR
fi

# 
# Find input files
# 
DIST_FILES=$(mktemp)
find $IN_DIR -type f > $DIST_FILES
NUM_FILES=$(lc $DIST_FILES)

if [ $NUM_FILES -lt 1 ]; then
  echo "Error: Found no files in IN_DIR \"$IN_DIR\"" >> $LOG
  exit 1
fi

echo $BAR                  >> $LOG
echo Settings for run:     >> $LOG
echo "IN_DIR     $IN_DIR"  >> $LOG
echo "OUT_DIR    $OUT_DIR" >> $LOG
echo $BAR                  >> $LOG
echo "Will process $NUM_FILES dist files" >> $LOG
cat -n $DIST_FILES          >> $LOG

MATRIX=$OUT_DIR/matrix.tab
META_DIR=$OUT_DIR/meta
$BIN/make-matrix.pl -d $IN_DIR -o $MATRIX
$BIN/make-metadata-dir.pl -f $METADATA_FILE -d $META_DIR
$BIN/sna.pl -o $OUT_DIR -m $META_DIR -s $MATRIX

echo Done.
