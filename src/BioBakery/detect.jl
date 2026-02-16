function detect_raw_inputs(sample::AbstractString, rawfastq_dir::AbstractString)::RawSequenceInputs
    files = readdir(rawfastq_dir; join=true)

    candidates = filter(f ->
        occursin(sample, basename(f)) &&
        occursin(r"\.(fastq|fq)(\.gz)?$", lowercase(basename(f))),
        files
    )

    r1_pat = Regex("^" * sample * raw"_1\.(fastq|fq)(\.gz)?$", "i")
    r2_pat = Regex("^" * sample * raw"_2\.(fastq|fq)(\.gz)?$", "i")
    orphan_pat = Regex("^" * sample * raw"\.(fastq|fq)(\.gz)?$", "i")  # fasterq-dump-style

    r1s = filter(f -> occursin(r1_pat, basename(f)), candidates)
    r2s = filter(f -> occursin(r2_pat, basename(f)), candidates)

    # upstream guarantee: never multiple; enforce it
    r1 = isempty(r1s) ? nothing : only(r1s)
    r2 = isempty(r2s) ? nothing : only(r2s)

    # orphan is "sample.fastq(.gz)" but not mates
    orphans = filter(f ->
        occursin(orphan_pat, basename(f)) &&
        !occursin(r1_pat, basename(f)) &&
        !occursin(r2_pat, basename(f)),
        candidates
    )
    orphan = isempty(orphans) ? nothing : only(orphans)

    # sanity checks
    if (r1 === nothing) ⊻ (r2 === nothing)
        throw(ArgumentError("Only one mate found for sample '$sample' (r1=$r1, r2=$r2)"))
    end
    if (r1 === nothing) && (orphan === nothing)
        throw(ArgumentError("No FASTQ inputs found for sample '$sample' in '$rawfastq_dir'"))
    end

    return RawSequenceInputs(r1, r2, orphan)
end

function detect_kneaddata_outputs(sample::AbstractString, knead_dir::AbstractString)::KneadDataOutputs
    files = readdir(abspath(knead_dir); join=true)
    files = filter(f -> occursin(sample, basename(f)), files)

    # accept fastq/fq with optional .gz
    files = filter(f -> occursin(r"\.(fastq|fq)(\.gz)?$", lowercase(basename(f))), files)

    # helpers: pick exactly one or nothing
    pick_or_nothing(rx::Regex) = begin
        hits = filter(f -> occursin(rx, basename(f)), files)
        isempty(hits) ? nothing : only(hits)  # you said you guarantee uniqueness; enforce it
    end

    # paired-run outputs (canonical prefix)
    prun_paired_r1   = pick_or_nothing(Regex("^" * sample * raw"_kneaddata.*paired_1.*\.(fastq|fq)(\.gz)?$", "i"))
    prun_paired_r2   = pick_or_nothing(Regex("^" * sample * raw"_kneaddata.*paired_2.*\.(fastq|fq)(\.gz)?$", "i"))
    prun_unpaired_r1 = pick_or_nothing(Regex("^" * sample * raw"_kneaddata.*unmatched_1.*\.(fastq|fq)(\.gz)?$", "i"))
    prun_unpaired_r2 = pick_or_nothing(Regex("^" * sample * raw"_kneaddata.*unmatched_2.*\.(fastq|fq)(\.gz)?$", "i"))

    # single-run outputs
    # Here we hit a sort of hurdle because whenever we have a ; we match “_single” and *not* paired/unmatched.
    srun_unpaired = begin
        hits = filter(f ->
            occursin(Regex("^" * sample * raw"_kneaddata.*_single.*\.(fastq|fq)(\.gz)?$", "i"), basename(f)) &&
            !occursin(r"paired_[12]", basename(f)) &&
            !occursin(r"unmatched_[12]", basename(f)),
            files
        )
        isempty(hits) ? nothing : only(hits)
    end

    # sanity checks: if one paired mate exists, require the other
    if (prun_paired_r1 === nothing) ⊻ (prun_paired_r2 === nothing)
        throw(ArgumentError("Detected only one paired output mate for '$sample' in '$knead_dir'"))
    end

    return KneadDataOutputs(
        prun_paired_r1,
        prun_paired_r2,
        prun_unpaired_r1,
        prun_unpaired_r2,
        srun_unpaired
    )
end