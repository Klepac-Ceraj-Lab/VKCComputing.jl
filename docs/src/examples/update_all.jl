# # Updating all files paths
#
# Check all sequencing files, and rename if necessary.
#-
# Start logging record, using @localdev environment:

using MiniLoggers, LoggingExtras

consolelogger = MiniLogger(; minlevel=MiniLoggers.Info, message_mode=:markdown)
filelogger = MiniLogger(; minlevel=MiniLoggers.Info, append=true, io="rename_all.log")

global_logger(TeeLogger(consolelogger, filelogger))

@info "Session started"

#-

using VKCComputing
using Preferences
using CSV
using DataFrames
using Airtable

@info "Updating local airtable files"
Base.with_logger(consolelogger) do
    base = LocalBase(; update = true)
end

analysis_dir = load_preference(VKCComputing, "mgx_analysis_dir")
@info "Using analysis directory $analysis_dir"

#-

analysis_files = DataFrame(file   = String[],
                           dir    = String[],
                           sample = Union{Missing, String}[],
                           s_well = Union{Missing, String}[],
                           suffix = Union{Missing, String}[]
)

for (root, dirs, files) in walkdir(analysis_dir)
    for f in files
        m = match(r"^([\w\-]+)_(S\d+)_?(.+)", basename(f))
        if isnothing(m)
            push!(analysis_files, (; file = basename(f), dir = root, sample = missing, s_well = missing, suffix = missing))
        else
            push!(analysis_files, (; file = basename(f), dir = root, sample = m[1], s_well = m[2], suffix = m[3]))
        end
    end
end

#-

@assert nrow(subset(analysis_files, "sample"=> ByRow(ismissing))) == 0
@info "All files in analysis directory match regex"

#-

transform!(analysis_files, "dir"=> ByRow(dir-> first(splitpath(replace(dir, analysis_dir=> "")))) => "tool")
sample_groups = groupby(analysis_files, "sample")

@info "Working with $(length(sample_groups)) files"

#-

transform!(sample_groups, "sample"=> ByRow(s-> startswith(s, "SEQ")) => "is_seqrecord")
@info "$(length(unique(subset(sample_groups, "is_seqrecord"=> ByRow(identity)).sample))) samples are SEQ records"
@info "$(length(unique(subset(sample_groups, "is_seqrecord"=> ByRow(!identity)).sample))) samples are NOT SEQ records"

#-

transform!(sample_groups, "s_well"=> (s-> length(unique(s)) == 1) => "is_unique_swell")
@assert isempty(subset(sample_groups, "is_unique_swell"=> ByRow(!identity)))
@info "No sample / Swell ambiguities"

completion = combine(sample_groups,
    "s_well"=> (s-> first(s)) => "s_well",
    "suffix"=> (suffix-> "kneaddata.log" in suffix)     => "has_kneaddata",
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

transform!(completion,
    AsTable([
        "has_taxprofile",
        "has_bowtie2",
        "has_sam",
]) => ByRow(all) => "metaphlan_complete")

transform!(completion,
    AsTable([
        "has_genefamilies", 
        "has_pathabundance", 
        "has_pathcoverage", 
    ]) => ByRow(all) => "humann_basic_complete"
)

transform!(completion, 
    AsTable([
        "has_ecs", 
        "has_kos", 
        "has_pfams", 
        "has_ecs_rename", 
        "has_kos_rename", 
        "has_pfams_rename"
    ]) => ByRow(all) => "humann_grprn_complete"
)

@info "kneaddata complete: $(nrow(subset(completion, "has_kneaddata"=> identity)))"
@info "metaphlan complete: $(nrow(subset(completion, "metaphlan_complete"=> identity)))"
@info "taxonomic profile complete: $(nrow(subset(completion, "has_taxprofile"=> identity)))"
@info "humann basic complete: $(nrow(subset(completion, "humann_basic_complete"=> identity)))"
@info "humann grprn complete: $(nrow(subset(completion, "humann_grprn_complete"=> identity)))"

#-

# ## Uploading records to Airtable

key = Airtable.Credential(load_preference(VKCComputing, "readwrite_pat"))

#-

testdf = completion[1:1000:end, :]

ukrow = first(eachrow(testdf))
sqrow = last(first(eachrow(testdf), 2))
fgrow = last(eachrow(testdf))

biosp_remote = AirTable("Biospecimens", VKCComputing.newbase)
seqprep_remote = AirTable("SequencingPrep", VKCComputing.newbase)

for row in eachrow(completion[3002:end, :])
    if haskey(base["SequencingPrep"], row.sample)
        seqrec = base["SequencingPrep", row.sample]
        smprec = seqrec[:biospecimen]
        if length(smprec) > 1
            @warn "$(seqrec[:uid]) has more than one biospecimen, skipping"
            continue
        else
            smprec = first(smprec)
        end
    elseif haskey(base["Biospecimens"], row.sample)
        smprec = base["Biospecimens", row.sample]
        if haskey(smprec, :seqprep)
            seqrec = base["SequencingPrep", smprec[:seqprep]]
            if length(seqrec) > 1
                @warn "$(smprec[:uid]) has more than one sequencing prep, skipping"
                continue
            else
                seqrec = first(seqrec)
            end
        end
    else
        smprec = Airtable.post!(key, biosp_remote, (; uid = row.sample))
        seqrec = Airtable.post!(key, seqprep_remote, (; biospecimen = [smprec.id]))
    end

    if !haskey(base["SequencingPrep"], row.sample)
        files = sample_groups[(; sample=smprec[:uid])]
        newnames = replace.(files.file, smprec[:uid]=> seqrec[:uid])
        for (i, row) in enumerate(eachrow(files))
            oldfile = joinpath(row.dir, row.file)
            newfile = joinpath(row.dir, newnames[i])
            if isfile(newfile)
                @warn "$newfile already exists, deleting $oldfile"
                rm(oldfile; force=true)
            else
                mv(oldfile, newfile)
            end
        end
    end
    Airtable.patch!(key, seqrec, (; S_well=row.s_well, kneaddata = row.has_kneaddata, metaphlan = row.metaphlan_complete, humann = row.humann_basic_complete))
end