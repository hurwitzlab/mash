#!/bin/bash

set -u

FASTA_DIR=""
MER_SIZE="20"
OUT_DIR="mash-out"
METADATA_FILE=""
FILES_LIST=""
ALIAS_FILE=""
PARTITION="normal" # or "development" AKA queue
TIME="24:00:00"
GROUP="iPlant-Collabs"
RUN_STEP=""
MAIL_USER=""
MAIL_TYPE="BEGIN,END,FAIL"
NUM_GBME_SCANS="100000"
EUC_DIST_PERCENT=0.1
SAMPLE_DIST=1000

function HELP() {
  printf "Usage:\n  %s -q INPUT_DIR -o OUT_DIR -m METADATA_FILE\n\n" $(basename $0)

  echo "Required arguments:"
  echo " -f FASTA_DIR"
  echo ""
  echo "Options (default in parentheses):"
  echo " -m METADATA_FILE"
  echo " -o OUT_DIR"
  echo " -l FILES_LIST"
  echo " -a ALIAS_FILE"
  echo " -g GROUP ($GROUP)"
  echo " -n MER_SIZE ($MER_SIZE)"
  echo " -p PARTITION ($PARTITION)"
  echo " -t TIME ($TIME)"
  echo " -r RUN_STEP"
  echo " -e MAIL_USER"
  echo " -x NUM_GBME_SCANS"
  echo " -d EUC_DIST_PERCENT ($EUC_DIST_PERCENT)"
  echo " -s SAMPLE_DIST ($SAMPLE_DIST)"
  echo ""
  exit 0
}

if [[ $# -eq 0 ]]; then
  HELP
fi

function GET_ALT_ENV() {
  env | grep $1 | sed "s/.*=//"
}

while getopts :a:d:e:f:g:l:m:o:p:r:s:t:x:h OPT; do
  case $OPT in
    a)
      ALIAS_FILE="$OPTARG"
      ;;
    d)
      EUC_DIST_PERCENT="$OPTARG"
      ;;
    e)
      MAIL_USER="$OPTARG"
      ;;
    f)
      FASTA_DIR="$OPTARG"
      ;;
    g)
      GROUP="$OPTARG"
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
      MER_SIZE="$OPTARG"
      ;;
    o)
      OUT_DIR="$OPTARG"
      ;;
    p)
      PARTITION="$OPTARG"
      ;;
    r)
      RUN_STEP="$OPTARG"
      ;;
    s)
      SAMPLE_DIST="$OPTARG"
      ;;
    t)
      TIME="$OPTARG"
      ;;
    x)
      NUM_GBME_SCANS="$OPTARG"
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
if [[ ${#FASTA_DIR} -lt 1 ]]; then
  echo "Error: No FASTA_DIR specified."
  exit 1
fi

if [[ ${#OUT_DIR} -lt 1 ]]; then
  echo "Error: No OUT_DIR specified." 
  exit 1
fi

if [[ ! -d "$FASTA_DIR" ]]; then
  echo "Error: FASTA_DIR \"$FASTA_DIR\" does not exist." 
  exit 1
fi

if [[ ! -d "$OUT_DIR" ]]; then
  mkdir -p "$OUT_DIR"
fi

CONFIG=$$.conf
CWD=$(pwd)

echo "export PATH=$PATH:$CWD/bin"                 > $CONFIG
echo "export FASTA_DIR=$FASTA_DIR"               >> $CONFIG
echo "export FILES_LIST=$FILES_LIST"             >> $CONFIG
echo "export ALIAS_FILE=$ALIAS_FILE"             >> $CONFIG
echo "export OUT_DIR=$OUT_DIR"                   >> $CONFIG
echo "export MER_SIZE=$MER_SIZE"                 >> $CONFIG
echo "export METADATA_FILE=$METADATA_FILE"       >> $CONFIG
echo "export NUM_GBME_SCANS=$NUM_GBME_SCANS"     >> $CONFIG
echo "export EUC_DIST_PERCENT=$EUC_DIST_PERCENT" >> $CONFIG
echo "export SAMPLE_DIST=$SAMPLE_DIST"           >> $CONFIG

echo "Run parameters:"
echo "CONFIG             $CONFIG"
echo "FASTA_DIR          $FASTA_DIR"
echo "OUT_DIR            $OUT_DIR"
echo "METADATA_FILE      $METADATA_FILE"
echo "FILES_LIST         ${FILES_LIST:-NA}"
echo "MER_SIZE           $MER_SIZE"
echo "TIME               $TIME"
echo "PARTITION          $PARTITION"
echo "GROUP              $GROUP"
echo "ALIAS_FILE         ${ALIAS_FILE:-NA}"
echo "NUM_GBME_SCANS     ${NUM_GBME_SCANS:-NA}"
echo "RUN_STEP           ${RUN_STEP:-NA}"
echo "EUC_DIST_PERCENT   ${EUC_DIST_PERCENT:-NA}"
echo "SAMPLE_DIST        ${SAMPLE_DIST:-NA}"

PREV_JOB_ID=0
i=0

for STEP in $(ls 0[1-9]*.sh); do
  let i++

  if [[ ${#RUN_STEP} -gt 0 ]] && [[ $(basename $STEP) != $RUN_STEP ]]; then
    continue
  fi

  #
  # Allow overrides for each job in config
  #
  THIS_PARTITION=$PARTITION

  ALT_PARTITION=$(GET_ALT_ENV "OPT_PARTITION_${i}")
  if [[ ${#ALT_PARTITION} -gt 0 ]]; then
    THIS_PARTITION=$ALT_PARTITION
  fi

  THIS_TIME=$TIME

  ALT_TIME=$(GET_ALT_ENV "OPT_TIME${i}")
  if [[ ${#ALT_TIME} -gt 0 ]]; then
    THIS_TIME=$ALT_TIME
  fi

  STEP_NAME=$(basename $STEP '.sh')
  STEP_NAME=$(echo $STEP_NAME | sed "s/.*-//")
  ARGS="-p $THIS_PARTITION -t $THIS_TIME -A $GROUP -N 1 -n 1 -J $STEP_NAME"

  if [[ ${#MAIL_USER} -gt 0 ]]; then
    ARGS="$ARGS --mail-user=$MAIL_USER --mail-type=$MAIL_TYPE"
  fi

  if [[ $PREV_JOB_ID -gt 0 ]]; then
    ARGS="$ARGS --dependency=afterok:$PREV_JOB_ID"
  fi

  CMD="sbatch $ARGS ./$STEP $CONFIG"
  OUT=$($CMD)
  JOB_ID=$(echo $OUT | egrep -e "Submitted batch job [0-9]+" | awk '{print $NF}')

  if [[ $JOB_ID -lt 1 ]]; then 
    echo Failed to get JOB_ID from \"$CMD\"
    echo $OUT
    exit 1
  fi
  
  printf "%3d: %s [%s]\n" $i $STEP $JOB_ID

  PREV_JOB_ID=$JOB_ID
done

echo Done.
