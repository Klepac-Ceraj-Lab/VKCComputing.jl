#!/bin/bash

SAMPLES="/home/$USER/Processing/samples.txt"
SLURM_JOB_DIR="/home/$USER/Processing/slurm-jobs"
VKCCOMPUTING_PROJECTHOME="/home/$USER/Repos/VKCComputing.jl"
PROCESSING_SCRIPT="/home/$USER/Repos/VKCComputing.jl/notebooks/process_local.jl"
CANONICAL_STORAGE_PREFIX="/home/$USER/Processing"
CANONICAL_DATABASE_PREFIX="/home/$USER/Databases"
CANONICAL_CONTAINER_PREFIX="/home/$USER/containers"
WORKDIR_PREFIX="/scratch/$USER"

while IFS= read -r sample; do
    sample=$(echo "$sample" | xargs)
    jobfile="${SLURM_JOB_DIR}/$(date +%F)_${sample}.sbatch"

    cat > "$jobfile" <<EOF
#!/bin/bash
#SBATCH -p day-long-cpu
#SBATCH -c 20
#SBATCH --mem 64G
#SBATCH -J ${sample}_KMH
#SBATCH -o ${SLURM_JOB_DIR}/slurm.${sample}.%j.out
#SBATCH -e ${SLURM_JOB_DIR}/slurm.${sample}.%j.err

echo "Starting run for sample ${sample}"

WORKDIR_JOB="${WORKDIR_PREFIX}/\${SLURM_JOB_ID}"

mkdir -p "\${WORKDIR_JOB}/rawfastq"

rsync -avm \
  --include='*/' \
  --include='${sample}*' \
  --exclude='*' \
  ${CANONICAL_STORAGE_PREFIX}/ \${WORKDIR_JOB}/

julia --project=${VKCCOMPUTING_PROJECTHOME} ${PROCESSING_SCRIPT} \
  -s $sample \
  -c ${CANONICAL_CONTAINER_PREFIX} \
  -d ${CANONICAL_DATABASE_PREFIX} \
  -p \${WORKDIR_JOB}

rsync -avm \
  --include='*/' \
  --include='${sample}*' \
  --exclude='*' \
  \${WORKDIR_JOB}/ ${CANONICAL_STORAGE_PREFIX}/

rm -rf \${WORKDIR_JOB}

EOF

    echo "Submitting job for $sample"
    #  sbatch "$jobfile"
done < "$SAMPLES"

## Old flags
# SBATCH --exclude node1
