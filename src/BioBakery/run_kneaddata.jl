function _run_knead_paired(
    sample::AbstractString,
    inp::RawSequenceInputs,
    knead_dir::AbstractString,
    cfg::KneadDataConfig;
    prefix::String
    )
    
    run(`$(cfg.kd_execline) \
        --input1 $(inp.paired_r1) \
        --input2 $(inp.paired_r2) \
        --reference-db $(cfg.hg_db_dir) \
        --output $knead_dir \
        --threads $(cfg.n_threads) \
        --processes $(cfg.n_processes) \
        --output-prefix $prefix \
        --trimmomatic $(cfg.trimmomatic_path)`)
end

function _run_knead_single(
    sample::AbstractString,
    inp::RawSequenceInputs,
    knead_dir::AbstractString,
    cfg::KneadDataConfig;
    prefix::String
    )

    run(`$(cfg.kd_execline) \
        --unpaired $(inp.unpaired) \
        --reference-db $(cfg.hg_db_dir) \
        --output $knead_dir \
        --threads $(cfg.n_threads) \
        --processes $(cfg.n_processes) \
        --output-prefix $prefix \
        --trimmomatic $(cfg.trimmomatic_path)`)
end

function _cleanup_knead(
    sample::AbstractString,
    knead_dir::AbstractString,
    cfg::KneadDataConfig;
    prefix::String
    )

    rm_files_bowtie2 = filter(f-> ( contains(f, prefix) & contains(f, "bowtie2") ), readdir(knead_dir; join = true))
    rm_files_trimmed = filter(f-> ( contains(f, prefix) & contains(f, "trimmed") ), readdir(knead_dir; join = true))
    rm_files_repeats = filter(f-> ( contains(f, prefix) & contains(f, "repeats") ), readdir(knead_dir; join = true))
    @show rm_files = vcat(rm_files_bowtie2, rm_files_trimmed, rm_files_repeats)
    
    (length(rm_files) > 0) ? map(rm, rm_files) : println("No files to remove!")

end

function run_kneaddata(
    sample::AbstractString,
    rawfastq_dir::AbstractString,
    knead_dir::AbstractString;
    cfg::KneadDataConfig = KneadDataConfig()
    )

    isdir(knead_dir) || mkpath(knead_dir)



    inp = detect_raw_inputs(sample, rawfastq_dir)

    if has_pair(inp)
        if isfile(joinpath(knead_dir, "$(canonical_prefix(sample)).log")) 
            @info "Canonical kneaddata log file found for $sample, skipping"
        else
            _run_knead_paired(sample, inp, knead_dir, cfg; prefix = canonical_prefix(sample))
        end
    end

    if has_orphan(inp)
        if isfile(joinpath(knead_dir, "$(single_prefix(sample)).log")) 
            @info "Single kneaddata log file found for $sample, skipping"
        else
        _run_knead_single(sample, inp, knead_dir, cfg; prefix = single_prefix(sample))
        end
    end

    _cleanup_knead(sample, knead_dir, cfg; prefix = canonical_prefix(sample))
    _cleanup_knead(sample, knead_dir, cfg; prefix = single_prefix(sample))

    for f in filter(f-> contains(basename(f), Regex(string(sample, ".+", "fastq"))), readdir(knead_dir; join=true))
        run(`gzip $f`)
    end

    return nothing
end