function fasterq_dump(
    sample,
    rawfastq_dir;
    cfg::PrefetchConfig = PrefetchConfig()
    )

    isdir(rawfastq_dir) || mkpath(rawfastq_dir)

    found_files = filter(f-> contains(basename(f), sample), readdir(rawfastq_dir; join = true))
    (length(found_files) > 0) && println("Found $(length(found_files)) mapping to sample ID")  

    run(
        `$(cfg.fasterq_dump_execline) \
        $sample \
        -O $rawfastq_dir \
        $(cfg.split_strat) \
        -e $(cfg.n_threads)`
    )

    # Detect all fastqs pertaining to this sample
    fastqs = filter(f -> contains(basename(f), Regex(string(sample, ".+", "fastq"))),
                readdir(rawfastq_dir; join=true))

    for f in fastqs
        println("Gzipping $(f)...")
        run(`gzip $f`)
    end

end

## Assuming all went well, we now have to deal with the following predicament:
# When unpaired reads are submitted to SRA alongside paired reads on a paired-end experiment,
# `fasterq-dump` will produce 3 files - 2 paired _1 and _2, and 1 unpaired, suffix-less file.
#
# Example:
#
# spots read      : 1,150,133
# reads read      : 2,126,045
# reads written   : 2,126,045
# Gzipping /Processing/rawfastq/SRR30334738.fastq...    ## Unpaired reads
# Gzipping /Processing/rawfastq/SRR30334738_1.fastq...  ## Paired reads _1
# Gzipping /Processing/rawfastq/SRR30334738_2.fastq...  ## Paired reads _2
# 
# Because we do not want to discard unpaired reads,
# the kneaddata interface processes paired AND unpaired reads
# (independently, so fits either/or cases). See `run_kneaddata` for more info.