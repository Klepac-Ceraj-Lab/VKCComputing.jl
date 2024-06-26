"""
    get_analysis_files(dir = @load_preference("mgx_analysis_dir"))

Expects the preference `mgx_analysis_dir` to be set -
see [`set_default_preferences!`](@ref).

Creates DataFrame  with the following headers:

- `mod`: `DateTime` that the file was last modified
- `size`: (`Int`) in bytes
- `path`: full path (eg `/grace/sequencing/processed/mgx/metaphlan/SEQ9999_S42_profile.tsv`)
- `dir`: Directory for file (eg `/grace/sequencing/processed/mgx/metaphlan/`), equivalent to `dirname(path)`
- `file`: File name (eg `SEQ9999_S42_profile.tsv`)
- `seqprep`: For files that match `SEQ\\d+_S\\d+_.+`, the sequencing Prep ID (eg `SEQ9999`). Otherwise, `missing`.
- `S_well`: For files that match `SEQ\\d+_S\\d+_.+`, the well ID, including `S` (eg `S42`). Otherwise, `missing`.
- `suffix`: For files that match `SEQ\\d+_S\\d+_.+`, the remainder of the file name, aside from a leading `_` (eg `profile.tsv`). Otherwise, `missing`.

See also [`aws_ls`](@ref)
"""
function get_analysis_files(dir = @load_preference("mgx_analysis_dir"))
    analysis_files = DataFrame(mod     = ZonedDateTime[],
                               size    = Int[],
                               path    = String[],
                               dir     = String[],
                               file    = String[],
                               seqprep = Union{Missing, String}[],
                               s_well  = Union{Missing, String}[],
                               suffix  = Union{Missing, String}[]
    )

    for (root, dirs, files) in walkdir(dir)
        for f in files
            path = joinpath(root, f)
            st = stat(path)
            mod = astimezone(ZonedDateTime(Dates.unix2datetime(st.mtime), tz"UTC"), tz"America/New_York")
            size = st.size
            base_nt = (; mod, size, path, dir=root, file=f)

            m = match(r"^([\w\-]+)_(S\d+)_?(.+)", basename(f))
            if isnothing(m)
                push!(analysis_files, (; base_nt..., seqprep = missing, s_well = missing, suffix = missing))
            else
                push!(analysis_files, (; base_nt..., seqprep = m[1], s_well = m[2], suffix = m[3]))
            end
        end
    end
    return analysis_files
end

"""
    audit_analysis_files(analysis_files; base = LocalBase())

WIP
"""
function audit_analysis_files(analysis_files; base = LocalBase())
    remote_seq = DataFrame()
    for seq in Iterators.filter(seq-> haskey(seq, :sequencing_batch), base["SequencingPrep"][:])
        push!(remote_seq, (; id = seq.id, seq.fields...); cols=:union)
    end
    remote_seq.kneaddata = coalesce.(remote_seq.kneaddata, false)
    remote_seq.metaphlan = coalesce.(remote_seq.metaphlan, false)
    remote_seq.humann    = coalesce.(remote_seq.humann, false)

    grp = groupby(analysis_files, "seqprep")

    transform!(grp, "s_well" => (col-> length(unique(col)) != 1)                    => "s_well_ambiguity",
                    "suffix" => ByRow(row-> ismissing(row) || row ∉ _good_suffices) => "bad_suffix",
                    "seqprep" => ByRow(row-> ismissing(row) || row ∉ remote_seq.uid)  => "bad_uid"
        ; ungroup=false)
    
    problem_files  = subset(analysis_files,
        AsTable(["s_well_ambiguity", "bad_suffix", "bad_uid"])=> ByRow(row-> any(row))
    )
    good_files     = subset(analysis_files,
        AsTable(["s_well_ambiguity", "bad_suffix", "bad_uid"])=> ByRow(row-> !any(row))
    )

    local_seq = audit_tools(rename(good_files, "s_well"=>"S_well"); group_col="seqprep")
    
    return remote_seq, local_seq, good_files, problem_files
end

"""
    audit_tools(df::DataFrame; group_col="seqprep")

WIP
"""
function audit_tools(df::DataFrame; group_col="seqprep")
    @chain df begin
        groupby(group_col)
        combine(
            "S_well"=> (s-> first(s)) => "S_well",
            "suffix"=> (suffix-> "kneaddata.log" in suffix)     => "kneaddata_complete",
            "suffix"=> (suffix-> "profile.tsv" in suffix)       => "has_taxprofile",
            "suffix"=> (suffix-> "bowtie2.tsv" in suffix)       => "has_bowtie2",
            "suffix"=> (suffix-> ".sam.bz2" in suffix)          => "has_sam",
            "suffix"=> (suffix-> "genefamilies.tsv" in suffix)  => "has_genefamilies",
            "suffix"=> (suffix-> "pathabundance.tsv" in suffix) => "has_pathabundance",
            "suffix"=> (suffix-> "pathcoverage.tsv" in suffix)  => "has_pathcoverage",
            "suffix"=> (suffix-> "ecs.tsv" in suffix)           => "has_ecs",
            "suffix"=> (suffix-> "kos.tsv" in suffix)           => "has_kos",
            "suffix"=> (suffix-> "pfams.tsv" in suffix)         => "has_pfams",
            "suffix"=> (suffix-> "ecs_rename.tsv" in suffix)    => "has_ecs_rename",
            "suffix"=> (suffix-> "kos_rename.tsv" in suffix)    => "has_kos_rename",
            "suffix"=> (suffix-> "pfams_rename.tsv" in suffix)  => "has_pfams_rename",
        )
        
        transform!(
        AsTable([
            "has_taxprofile",
            "has_bowtie2",
            "has_sam",
        ]) => ByRow(all) => "metaphlan_complete")
    
        transform!(
            AsTable([
                "has_genefamilies", 
                "has_pathabundance", 
                "has_pathcoverage", 
            ]) => ByRow(all) => "humann_basic_complete"
        )
    
        transform!( 
            AsTable([
                "has_ecs", 
                "has_kos", 
                "has_pfams", 
                "has_ecs_rename", 
                "has_kos_rename", 
                "has_pfams_rename"
            ]) => ByRow(all) => "humann_complete"
        )
    end
end


"""
    audit_update_remote!(remote_seq, local_seq)

WIP
"""
function audit_update_remote!(remote_seq, local_seq; dryrun=true)
    if @has_preference("readwrite_pat")
        pat = @load_preference("readwrite_pat")
    else 
        pat = get(ENV, "AIRTABLE_KEY", nothing)
    end
    isnothing(pat) && throw(ErrorException("No airtable key available - set preference for 'readonly_pat' or 'readwrite_pat', or the environmental variable 'AIRTABLE_KEY'"))
    cred = Airtable.Credential(pat)
    rem = select(remote_seq, "id", "uid", "S_well", "kneaddata", "metaphlan", "humann")
    loc = select(local_seq, "seqprep"=>"uid", "s_well"=>"S_well", "kneaddata_complete", "metaphlan_complete", "humann_complete")

    grem = groupby(rem, "uid") # group
    gloc = groupby(loc, "uid") # group

    patches = AirRecord[]
    for key in keys(gloc)
        key = NamedTuple(key)
        !haskey(grem, key) && throw(ErrorException("Airtable SequencingPrep table does not contain key $key"))
        dfrem = grem[key]
        dfloc = gloc[key]
        any(df-> size(df, 1) != 1, [dfrem, dfloc]) && throw(ErrorException("Key $key has multiple entries in one of the dataframes"))

        rrem = dfrem[1,:]
        rloc = dfloc[1,:]

        # check S well
        !ismissing(rrem.S_well) && rrem.S_well != rloc.S_well && throw(ErrorException("Key $key has mismatch between local and remote S-well"))
        S_well = rloc.S_well

        kneaddata = rrem.kneaddata          || rloc.kneaddata_complete
        kneaddata ⊻ rrem.kneaddata          && @info "planning to update $(key.uid) kneaddata -> true"
        kneaddata ⊻ rloc.kneaddata_complete && @warn "$(key.uid) kneaddata is `true` on remote, but missing locally"

        metaphlan = rrem.metaphlan          || rloc.metaphlan_complete
        metaphlan ⊻ rrem.metaphlan          && @info "planning to update $(key.uid) metaphlan -> true"
        metaphlan ⊻ rloc.metaphlan_complete && @warn "$(key.uid) metaphlan is `true` on remote, but missing locally"

        humann    = rrem.humann             || rloc.humann_complete
        humann    ⊻ rrem.humann             && @info "planning to update $(key.uid) humann -> true"
        humann    ⊻ rloc.humann_complete    && @warn "$(key.uid) humann is `true` on remote, but missing locally"

        (any([kneaddata, metaphlan, humann]) || ismissing(rrem.S_well)) && push!(patches, 
                                                                            AirRecord(
                                                                                rrem.id,
                                                                                AirTable("SequencingPrep", newbase),
                                                                                (; kneaddata, metaphlan, humann, S_well)
                                                                                )
                                                                            )
    end
    
    if dryrun
        @warn "Dry-run complete! Use `; dryrun=false` to update"
    else
        Airtable.patch!(cred, AirTable("SequencingPrep", AirBase("appmYwoXIHlen5s0q")), patches)
    end
end


const _good_suffices = (
    "genefamilies.tsv",
    "pathabundance.tsv",
    "pathcoverage.tsv",
    "ecs.tsv",
    "kos.tsv",
    "pfams.tsv",
    "ecs_rename.tsv",
    "kos_rename.tsv",
    "pfams_rename.tsv",
    "kneaddata.log",
    "kneaddata.repeats.removed.1.fastq.gz",
    "kneaddata.repeats.removed.2.fastq.gz",
    "kneaddata.repeats.removed.unmatched.1.fastq.gz",
    "kneaddata.repeats.removed.unmatched.2.fastq.gz",
    "kneaddata.trimmed.1.fastq.gz",
    "kneaddata.trimmed.2.fastq.gz",
    "kneaddata.trimmed.single.1.fastq.gz",
    "kneaddata.trimmed.single.2.fastq.gz",
    "kneaddata_paired_1.fastq.gz",
    "kneaddata_paired_2.fastq.gz",
    "kneaddata_unmatched_1.fastq.gz",
    "kneaddata_unmatched_2.fastq.gz",
    "kneaddata_hg37dec_v0.1_bowtie2_paired_contam_1.fastq.gz",
    "kneaddata_hg37dec_v0.1_bowtie2_paired_contam_2.fastq.gz",
    "kneaddata_hg37dec_v0.1_bowtie2_unmatched_1_contam.fastq.gz",
    "kneaddata_hg37dec_v0.1_bowtie2_unmatched_2_contam.fastq.gz",
    "kneaddata_hg37_v0.1_bowtie2_paired_contam_1.fastq.gz",
    "kneaddata_hg37_v0.1_bowtie2_paired_contam_2.fastq.gz",
    "kneaddata_hg37_v0.1_bowtie2_unmatched_1_contam.fastq.gz",
    "kneaddata_hg37_v0.1_bowtie2_unmatched_2_contam.fastq.gz",
    ".log",
    ".sam.bz2",
    "bowtie2.tsv",
    "profile.tsv",
    ".sam",
)
