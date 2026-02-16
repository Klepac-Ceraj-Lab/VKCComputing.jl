#!/bin/bash

SAMPLES="/home/gz101/Processing/samples.txt"
SLURM_JOB_DIR="/home/gz101/Processing/slurm-jobs"
VKCCOMPUTING_PROJECTHOME="/home/gz101/Repos/VKCComputing.jl"
PROCESSING_SCRIPT="/home/gz101/Repos/VKCComputing.jl/notebooks/process_local.jl"

mkdir -p "$SLURM_JOB_DIR"

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

echo "Starting TEST RUN"
julia --project=${VKCCOMPUTING_PROJECTHOME} ${PROCESSING_SCRIPT} -s $sample

EOF

    echo "Submitting job for $sample"
    #  sbatch "$jobfile"
done < "$SAMPLES"

## Old flags
# SBATCH --exclude node1
