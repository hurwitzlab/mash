module load tacc-singularity

IMG="/work/05066/imicrobe/singularity/mash-all-vs-all-0.0.6.img"

if [[ ! -e "$IMG" ]]; then
    echo "Missing Singularity image \"$IMG\""
    exit 1
fi

singularity exec $IMG run_mash ${ALIAS_FILE} ${QUERY} ${KMER_SIZE} ${SKETCH_SIZE}
