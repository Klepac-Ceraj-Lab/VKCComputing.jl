using ArgParse
using Dates
using VKCComputing

function this_args()
    s = ArgParseSettings()
    @add_arg_table s begin
        "--sample", "-s"
            help = "Sample ID to process"
            required = true
    end
    return parse_args(ARGS, s)
end

if abspath(PROGRAM_FILE) == @__FILE__
    args = this_args()
    sample = args["sample"]

    # sample_list = "$(ENV["HOME"])/Processing/samples.txt"
    rawfastq_dir = "$(ENV["HOME"])/Processing/rawfastq"
    knead_dir = "$(ENV["HOME"])/Processing/kneaddata"
    metaphlan_dir = "$(ENV["HOME"])/Processing/metaphlan"
    humann_dir = "$(ENV["HOME"])/Processing/humann"

    # 0. fetch fastq from repository
    fasterq_dump(
        sample,
        rawfastq_dir;
        fasterq_dump_execline = `apptainer run --bind $(ENV["HOME"])/Processing:$(ENV["HOME"])/Processing /home/gz101/containers/bzip2.sif fasterq-dump`,
    )

end