#!/bin/bash

set -u

# 
# Argument defaults
# 
BIN="$( readlink -f -- "${0%/*}" )"
if [ -f $BIN ]; then
  BIN=$(dirname $BIN)
fi

FASTA_DIR=""
OUT_DIR=""
FILES_LIST=""
WORK_DIR=$BIN
MER_SIZE=20
BAR="# ----------------------"

#
# Functions
#
function lc() {
  wc -l $1 | cut -d ' ' -f 1
}

function HELP() {
  printf "Usage:\n  %s -f FASTA_DIR -o OUT_DIR\n\n" $(basename $0)

  echo "Required Arguments:"
  echo " -f FASTA_DIR"
  echo " -o OUT_DIR (where to put sketches)"
  echo
  echo "Options (default in parentheses):"
  echo " -l FILES_LIST"
  echo " -m MER_SIZE ($MER_SIZE)"
  echo " -w WORK_DIR ($WORK_DIR)"
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
while getopts :f:l:m:o:w:h OPT; do
  case $OPT in
    f)
      FASTA_DIR="$OPTARG"
      ;;
    h)
      HELP
      ;;
    l)
      FILES_LIST="$OPTARG"
      ;;
    m)
      MER_SIZE="$OPTARG"
      ;;
    o)
      OUT_DIR="$OPTARG"
      ;;
    w)
      WORK_DIR="$OPTARG"
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
if [[ ${#FASTA_DIR} -lt 1 ]]; then
  echo "Error: No FASTA_DIR specified." >> $LOG
  exit 1
fi

if [[ ${#OUT_DIR} -lt 1 ]]; then
  echo "Error: No OUT_DIR specified." >> $LOG
  exit 1
fi

if [[ ! -d $FASTA_DIR ]]; then
  echo "Error: FASTA_DIR \"$FASTA_DIR\" does not exist." >> $LOG
  exit 1
fi

if [[ ! -d $OUT_DIR ]]; then
  mkdir -p $OUT_DIR
fi

# 
# Find input files
# 
FASTA_FILES=$(mktemp)

if [[ -n $FILES_LIST ]]; then
  echo Taking files from list \"$FILES_LIST\" >> $LOG
  while read FILE; do
    BASENAME=$(basename $FILE);
    FILE_PATH="$FASTA_DIR/$BASENAME"
    if [[ -e $FILE_PATH ]]; then
      echo $FILE_PATH >> $FASTA_FILES
    else
      echo Cannot find \"$BASENAME\" in \"$FASTA_DIR\" >> $LOG
    fi
  done < $FILES_LIST
else 
  find $FASTA_DIR -type f > $FASTA_FILES
fi

NUM_FILES=$(lc $FASTA_FILES)

if [ $NUM_FILES -lt 1 ]; then
  echo "Error: Found no files in FASTA_DIR \"$FASTA_DIR\"" >> $LOG
  exit 1
fi

echo $BAR                        >> $LOG
echo Settings for run:           >> $LOG
echo "FASTA_DIR     $FASTA_DIR"  >> $LOG
echo "OUT_DIR       $OUT_DIR"    >> $LOG
echo "MER_SIZE      $MER_SIZE"   >> $LOG
echo "FILES_LIST    $FILES_LIST" >> $LOG
echo $BAR                        >> $LOG
echo "Will process $NUM_FILES FASTA files" >> $LOG
cat -n $FASTA_FILES >> $LOG

i=0
while read FILE; do
  let i++
  BASENAME=$(basename $FILE)
  OUT_FILE=$OUT_DIR/$BASENAME 

  printf "%3d: %s\n" $i $BASENAME >> $LOG

  if [[ -s "${OUT_FILE}.msh" ]]; then
    echo Mash for $OUT_FILE exists, skipping.
    continue
  fi

  echo "mash sketch -p 12 -o $OUT_FILE $FILE" >> $PARAMS_FILE
done < $FASTA_FILES

NUM_JOBS=$(lc $PARAMS_FILE)

if [[ $NUM_JOBS -gt 0 ]]; then
  echo "Submitting \"$NUM_JOBS\" jobs" >> $LOG

  export TACC_LAUNCHER_NPHI=0
  export TACC_LAUNCHER_PPN=2
  export EXECUTABLE=$TACC_LAUNCHER_DIR/init_launcher
  export WORKDIR=$BIN
  export TACC_LAUNCHER_SCHED=interleaved

  echo "Starting parallel job..." >> $LOG
  echo $(date) >> $LOG
  $TACC_LAUNCHER_DIR/paramrun SLURM $EXECUTABLE $WORKDIR $PARAMS_FILE
  echo $(date) >> $LOG
  echo "Done" >> $LOG
else
  echo "Error: No jobs to submit." >> $LOG
fi

#rm $PARAMS_FILE
#rm $FASTA_FILE
echo Done.
