#!/bin/bash

#SBATCH -J mash
#SBATCH -A iPlant-Collabs
#SBATCH -p normal
#SBATCH -t 24:00:00
#SBATCH -N 1
#SBATCH -n 1

module load tacc-singularity

IMG="/work/05066/imicrobe/singularity/mash-all-vs-all-0.0.4.img"

if [[ ! -e "$IMG" ]]; then
    echo "Missing Singularity image \"$IMG\""
    exit 1
fi

singularity exec $IMG run_mash "$@"

echo "Comments to kyclark@email.arizona.edu"
