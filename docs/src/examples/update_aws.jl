using VKCComputing
using Chain
using DataFrames
using Airtable
using Preferences
using ThreadsX

key = Airtable.Credential(load_preference(VKCComputing, "readwrite_pat"))
remote = AirBase("appmYwoXIHlen5s0q")
base = LocalBase(; update=true)

#- 

aws_processed = filter(f-> contains(f, r"processed\/.+"), readlines("vkc-sequencing.txt"))
aws_processed = map(f-> replace(f, r"^.+ (processed\/.+$)" => s"\1"), aws_processed)

local_processed = DataFrame(file   = String[],
    dir    = String[],
    sample = Union{Missing, String}[],
    s_well = Union{Missing, String}[],
    suffix = Union{Missing, String}[]
)


for (dir, dirs, files) in walkdir(load_preference(VKCComputing, "mgx_analysis_dir"))
    for file in files
        m = match(r"^([\w\-]+)_(S\d+)_?(.+)", file)
        if isnothing(m)
            push!(local_processed, (; file, dir, sample = missing, s_well = missing, suffix = missing))
        else
            push!(local_processed, (; file, dir, sample = m[1], s_well = m[2], suffix = m[3]))
        end
    end
end


analysis_files = DataFrame(file   = String[],
                           dir    = String[],
                           sample = Union{Missing, String}[],
                           s_well = Union{Missing, String}[],
                           suffix = Union{Missing, String}[]
)

for file in aws_processed
    dir = dirname(file)
    file = basename(file)
    m = match(r"^([\w\-]+)_(S\d+)_?(.+)", file)
    if isnothing(m)
        push!(analysis_files, (; file, dir, sample = missing, s_well = missing, suffix = missing))
    else
        push!(analysis_files, (; file, dir, sample = m[1], s_well = m[2], suffix = m[3]))
    end
end



problems = subset(analysis_files, "suffix" => ByRow(s-> !ismissing(s) && s ∉ (
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
)))

transform!(analysis_files, AsTable(["sample", "file"]) => ByRow(row -> begin
    misrec = (;seqid = missing, remote_s = missing)
    s = row.sample
    ismissing(s) && return misrec
    bsp = get(base["Biospecimens"], s, get(base["Biospecimens"], replace(s, "_"=>"-", "-"=>"_"), missing))
    ismissing(bsp) && return misrec
    !haskey(bsp, :seqprep) && return misrec

    seqprep = base[bsp[:seqprep]]
    filter!(s-> haskey(s, :S_well) && contains(row.file, string("_", s[:S_well], "_")), seqprep)
    if length(seqprep) != 1
        return misrec
    else
        seqid = first(seqprep)[:uid]
        remote_s = first(seqprep)[:S_well]
    end
    return (; seqid, remote_s)
end)=> ["seqid", "remote_s"])

existing = Set(skipmissing(local_processed.file))

#-

for row in eachrow(subset(analysis_files, "seqid" => ByRow(!ismissing)))
    newfile = replace(row.file, row.sample => row.seqid)

    oldpath = joinpath("s3://vkc-sequencing", row.dir, row.file)
    newpath = joinpath("s3://vkc-sequencing", row.dir, replace(row.file, row.sample => row.seqid))

    if newfile ∈ existing
        @info "removing `$oldpath`"
        cmd = Cmd(["aws", "s3", "rm", oldpath])
        run(cmd)
    else
        @info "`$oldpath` => `$newpath`"
        # cmd = Cmd(["aws", "s3", "mv", oldpath, newpath])
    end
    
end

