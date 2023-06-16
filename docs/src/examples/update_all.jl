# # Updating all files paths
#
# Check all sequencing files, and rename if necessary.
#-
# Start logging record, using @localdev environment:

using MiniLoggers, LoggingExtras

ratelimitlogger(log_args) = !contains(log_args.message, "Pausing for rate-limiting")

consolelogger = MiniLogger(; minlevel=MiniLoggers.Info, message_mode=:markdown)
filelogger = ActiveFilteredLogger(ratelimitlogger, MiniLogger(; minlevel=MiniLoggers.Info, append=true, io="rename_all.log"))

global_logger(TeeLogger(consolelogger, filelogger))

@info "Session started"

#-

using VKCComputing
using Preferences
using CSV
using DataFrames
using Airtable

@info "Updating local airtable files"
base = LocalBase(; update = true)

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

@info "Working with $(length(sample_groups)) samples"

#-

transform!(sample_groups, "sample"=> ByRow(s-> startswith(s, "SEQ")) => "is_seqrecord")
@info "$(length(unique(subset(sample_groups, "is_seqrecord"=> ByRow(identity)).sample))) samples are SEQ records"
@info "$(length(unique(subset(sample_groups, "is_seqrecord"=> ByRow(!identity)).sample))) samples are NOT SEQ records"

#-

analysis_files.biospecimen = [rec[:uid] for rec in resolve_links(base, [seq[:biospecimen] for seq in base["SequencingPrep", analysis_files.sample]])]

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

transform!(sample_groups, AsTable(["file", "dir", "suffix"]) => ByRow(row-> begin
    row.suffix == "profile.tsv" || return missing
    defline = first(eachline(joinpath(row.dir, row.file)))
    m = match(r"mpa_v(\d+)_CHOCOPhlAn", defline)
    if isnothing(m)
        @warn "$(row.file) has no MP version: $defline"
        return missing
    else
        return String(m[1])
    end
end) => "mpa_v")

oldmetaphlan = subset(analysis_files, "mpa_v"=> ByRow(v-> !ismissing(v) && v == "30"))
oldmp_biosp = Set(oldmetaphlan.biospecimen)


remote_knead = let
    awsknead = Iterators.filter(l-> contains(l, r"kneaddata_paired"), eachline("aws_processed.txt")) |> collect
    DataFrame(mapreduce(vcat, eachindex(awsknead)) do i
        m = match(r"([\w\-]+)_(S\d+)_kneaddata_paired", awsknead[i])
        @assert !isnothing(m)
        return [(; biospecimen = m[1], s = m[2], file = string(m[1], "_", m[2], "_kneaddata_paired_1.fastq.gz"))
                (; biospecimen = m[1], s = m[2], file = string(m[1], "_", m[2], "_kneaddata_paired_2.fastq.gz"))]
    end)
end

subset!(remote_knead, "biospecimen" => ByRow(b-> !isempty(Set([b, replace(b, "-"=>"_", "_"=>"-")]) ∩ oldmp_biosp)))
subset!(remote_knead, "biospecimen" => ByRow(b-> !startswith(b, "FE")))

leftjoin!(remote_knead, rename(unique(select(analysis_files, "biospecimen", "s_well", "sample")), "s_well"=> "s"); on=["biospecimen", "s"])
subset!(remote_knead, "sample"=> ByRow(!ismissing))
unique!(remote_knead, "file")

transform!(remote_knead, AsTable(["biospecimen", "file", "sample"])=> ByRow(row-> begin
    replace(row.file, row.biospecimen => row.sample)
end) => "newfile")

for row in eachrow(remote_knead[51:150, :])
    cmd = Cmd(["aws", "s3", "cp",
                joinpath("s3://vkc-sequencing/processed/mgx/kneaddata/", row.file),
                joinpath("s3://vkc-nextflow/rawfastq/", row.newfile)]
    )

    run(cmd)
end

# # ## Uploading records to Airtable

# key = Airtable.Credential(load_preference(VKCComputing, "readwrite_pat"))

# #-

# biosp_remote = AirTable("Biospecimens", VKCComputing.newbase)
# seqprep_remote = AirTable("SequencingPrep", VKCComputing.newbase)

# rename_targets = subset(analysis_files, "has_biospecimen"=> identity, "is_unique_swell"=> identity)
# transform!(rename_targets, "sample"=> ByRow(s -> begin
#     bsrec = base["Biospecimens", s]
#     (!haskey(bsrec, :seqprep) || length(bsrec[:seqprep]) > 2) ? missing : first(base[bsrec[:seqprep]])[:uid]
# end)=> "seqid")

# rename_targets[findall(==("KMZ43460"), rename_targets.sample), :seqid] .= "SEQ00211"

# biospecimens = base["Biospecimens"][rename_targets.sample]

# #-

# for row in eachrow(subset(rename_targets, "seqid"=> ByRow(!ismissing)))
#     oldpath = joinpath(row.dir, row.file)
#     newpath = joinpath(row.dir, replace(row.file, row.sample=> row.seqid))
#     @info "Renameing $oldpath to $newpath"
#     mv(oldpath, newpath)
# end

# # ## Ambiguities

# CSV.write("/lovelace/sequencing/20230602_file_renaming.csv", rename_targets)
