function cat_kneads(sample::AbstractString, knead_dir::AbstractString, metaphlan_dir::AbstractString)

    outs = detect_kneaddata_outputs(sample, knead_dir)

    # Choose what goes into the MetaPhlAn “single stream” input
    # From: [0 or] 2 paired cleaned reads + [0 or] 2 unpaired fragments + [0 or] 1 single-run cleaned reads
    infiles = String[]
    for f in (
        outs.prun_paired_r1,
        outs.prun_paired_r2,
        outs.prun_unpaired_r1,
        outs.prun_unpaired_r2,
        outs.srun_unpaired
    )
        f === nothing || push!(infiles, f)
    end

    isempty(infiles) && throw(ArgumentError("No kneaddata outputs found to concatenate for '$sample'"))

    isdir(metaphlan_dir) || mkpath(metaphlan_dir)
    catfile = joinpath(metaphlan_dir, "$sample.joined.fastq.gz")

    if isfile(catfile)
        @info "Cat kneads file found for $sample, skipping"
        return catfile
    end

    @info "Writing combined file to $catfile"
    cmd = Cmd(vcat(["cat"], infiles))
    run(pipeline(cmd; stdout = catfile))

    return catfile
end

# function cat_kneads(sample, knead_dir, metaphlan_dir)
#     infiles = filter(
#         f -> contains(basename(f), sample) && any(p-> contains(basename(f), p), (r"paired_[12]", r"unmatched_[12]")),
#         readdir(abspath(knead_dir); join=true)
#     )
#     isdir(metaphlan_dir) || mkpath(metaphlan_dir)
#     catfile = joinpath(metaphlan_dir, "$sample.joined.fastq.gz")
#     if isfile(catfile)
#         @info "Cat kneads file found for $sample, skipping"
#         return catfile
#     end
#     @info "writing combined file to $catfile"
#     run(pipeline(`cat $infiles`; stdout=catfile))
#     return catfile
# end