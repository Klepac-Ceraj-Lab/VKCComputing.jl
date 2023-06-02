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

transform!(sample_groups, "sample"=> (s-> haskey(base["Biospecimens"], first(s)) || haskey(base["Biospecimens"], replace(first(s), "_"=> "-", "-"=> "_")))=> "has_biospecimen")

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

biosp_remote = AirTable("Biospecimens", VKCComputing.newbase)
seqprep_remote = AirTable("SequencingPrep", VKCComputing.newbase)

rename_targets = subset(analysis_files, "has_biospecimen"=> identity, "is_unique_swell"=> identity)
transform!(rename_targets, "sample"=> ByRow(s -> begin
    bsrec = base["Biospecimens", s]
    (!haskey(bsrec, :seqprep) || length(bsrec[:seqprep]) > 2) ? missing : first(base[bsrec[:seqprep]])[:uid]
end)=> "seqid")

rename_targets[findall(==("KMZ43460"), rename_targets.sample), :seqid] .= "SEQ00211"

biospecimens = base["Biospecimens"][rename_targets.sample]

#-

for row in eachrow(subset(rename_targets, "seqid"=> ByRow(!ismissing)))
    oldpath = joinpath(row.dir, row.file)
    newpath = joinpath(row.dir, replace(row.file, row.sample=> row.seqid))
    @info "Renameing $oldpath to $newpath"
    mv(oldpath, newpath)
end

# ## Ambiguities

CSV.write("/lovelace/sequencing/20230602_file_renaming.csv", rename_targets)
