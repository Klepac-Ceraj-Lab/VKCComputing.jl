using VKCComputing
using Chain
using DataFrames
using CSV
using Airtable
using Preferences
using MiniLoggers

MiniLogger(; message_mode=:markdown ) |> global_logger

drives = (
    "/grace",
    "/murray",
    "/tempstore",
    "/vassar",
    "/home/guilherme/",
    "/home/kevin"
)

extensions = (
    "fastq.gz",
    "fastq",
    "tsv",
    "sam.bz2",
    "sam",
    "log"
)

kneaddata_patterns = (
    r"^(.+)_kneaddata\.log$",
    r"^(.+)_kneaddata_(.+)\.fastq\.gz$",
    r"^(.+)_kneaddata\.(.+)\.fastq\.gz$",
)

metaphlan_patterns = (
    r"^(.+)_profile\.tsv$",
    r"^(.+)_bowtie2\.tsv$",
    r"^(.+)\.sam(\.bz2)?$",
)

humann_patterns = (
    r"^(.+)_genefamilies\.tsv$",
    r"^(.+)_pathabundance\.tsv$",
    r"^(.+)_pathcoverage\.tsv$",
    r"^(.+)_rename\.tsv$",
    r"^(.+)_names\.tsv$",
    r"^(.+)_relab\.tsv$",
    r"^(.+)_kos\.tsv$",
    r"^(.+)_ecs\.tsv$",
    r"^(.+)_pfams\.tsv$",
)


all_files = DataFrame()

foreach(drives) do drive
    for (path, dirs, files) in walkdir(drive; onerror = e-> @warn e)
        for file in files
            any(ext-> endswith(file, ext), extensions) || continue
            contains(path, "/OSU_coassembly/") && continue
            contains(path, "/OSU_data/") && continue
            contains(path, "/pypoetry/") && continue
            contains(path, "/.cargo/") && continue
            contains(path, "/.cmdstan/") && continue
            contains(path, "/.julia/") && continue
            contains(path, "/.vscode-server/") && continue
            contains(path, "/Software/") && continue


            if any(pattern-> contains(file, pattern), kneaddata_patterns)
                type = "kneaddata"
            elseif any(pattern-> contains(file, pattern), metaphlan_patterns)
                type = "metaphlan"
            elseif any(pattern-> contains(file, pattern), humann_patterns)
                type = "humann"
            elseif endswith(file, "fastq.gz")
                type = "sequencing"
            else
                type = "other"
            end

            push!(all_files, (; type, drive, file, path))
        end
    end
end

CSV.write("/home/kevin/Downloads/hopper_audit_other_files.csv", subset(all_files, "type"=>ByRow(==("other"))))

maybeseq = subset(all_files, "type"=> ByRow(!=("other")))

transform!(maybeseq, "file"=> ByRow(file->begin
    seqmatch = match(r"^(SEQ\d+)_(S\d+)?", file)
    (seqid, s_well) = isnothing(seqmatch) ? (nothing,nothing) : seqmatch.captures
    
    sampleid = nothing
    if isnothing(s_well)
        wellmatch = match(r"^(.+)_(S\d+)_", file)
        (sampleid, s_well) = isnothing(wellmatch) ? (nothing, nothing) : wellmatch.captures
    end

    if isnothing(s_well)
        wellmatch = match(r"_(S\d+)_", file)
        !isnothing(wellmatch) && (s_well = wellmatch[1])
    end

    isnothing(sampleid) && (sampleid = first(split(file, '_')))
    return (; seqid=something(seqid, missing), sampleid = String(sampleid), s_well=something(s_well, missing))

end)=> ["seqid", "sampleid", "s_well"])

transform!(maybeseq, "sampleid" => ByRow(
    sampleid-> contains(sampleid, r"^F[EG]\d+") ||
               contains(sampleid, r"[CM]\d+[\-_]\d+[EF]")
        ) => "need2fixID")

CSV.write("/home/kevin/Downloads/hopper_audit_files.csv", sort(maybeseq, "sampleid"))


#-


#-

key = Airtable.Credential(load_preference(VKCComputing, "readwrite_pat"))
remote = AirBase("appmYwoXIHlen5s0q")
base = LocalBase()
analysis_files = get_analysis_files()

#-

tofix = subset(maybeseq, "need2fixID"=> identity)
subset!(tofix, "path" => ByRow(path-> !contains(path, "amplicon")))

transform!(tofix, ["sampleid", "s_well"]=> ByRow((sampleid, s_well)-> begin
    empty_nt = (; biospecimen_recid=missing, seqpreps = missing)
    biospecimen = get(base["Biospecimens"], sampleid, nothing)

    isnothing(biospecimen) && return empty_nt
    seqpreps = collect(get(biospecimen, :seqprep, String[]))
    return (; biospecimen_recid = biospecimen.id, seqpreps)
    
end)=> ["biospecimen_recid", "seqpreps"])

transform!(tofix, ["seqpreps", "s_well"] => ByRow((seqpreps, s_well) -> begin
    seqid = missing
    if !ismissing(seqpreps)
        seqids = [base[seqprep][:uid] for seqprep in seqpreps]
        s_wells = [get(base[seqprep], :S_well, missing) for seqprep in seqpreps]
        well_match = findall(==(s_well), s_wells)

        if !isnothing(well_match)
            if length(well_match) == 1
                seqid = only(seqids[well_match])
            end
        end
        return (; seqid, seqids, s_wells)
    else
        return (; seqid, seqids=String[], s_wells=String[])
    end
end)=> ["seqid", "seqids", "s_wells"])

subset(tofix, "seqid"=> ByRow(!ismissing))
#-

CSV.write(
    "/home/kevin/Downloads/hopper_name_changes.csv",
    sort(subset(tofix, "seqid"=> ByRow(!ismissing)), "path")
)


#-

local_seqids = subset(maybeseq, "seqid"=> ByRow(!ismissing))

length(unique(local_seqids.seqid))

#-

missing_seqids = DataFrame(seqprep=String[],
                           biosp=Union{Missing,String}[],
                           seqbatch=Union{Missing,String}[])
for seq in setdiff(uids(base["SequencingPrep"]), unique(local_seqids.seqid))
    seqprep = base["SequencingPrep", seq]
    biosp = get(seqprep, :biospecimen, missing)
    !ismissing(biosp) && (biosp = base[only(biosp)][:uid])
    seqbatch = get(seqprep, :sequencing_batch, missing)
    !ismissing(seqbatch) && (seqbatch = only([rec[:uid] for rec in base[seqbatch]]))
    push!(missing_seqids, (; seqprep=seqprep[:uid], biosp, seqbatch))
end

subset!(missing_seqids, "seqbatch"=> ByRow(batch -> !ismissing(batch) && !(batch ∈ ("mgx034", "rna035"))))

#-

check_outputs = groupby(subset(local_seqids, "seqid"=> ByRow(seqid-> begin
    seqid ∉ missing_seqids.seqprep
end)), "seqid")

combine(check_outputs, "path"  => length=> "n_files",
                              "drive" => (d-> length(unique(d))) => "n_drives",
                              "path"  => (d-> length(unique(d))) => "n_paths"
               )

file_audit = combine(check_outputs, "file"=> (file-> begin
    has_knead = any(f-> contains(f, "kneaddata_paired"), file)
    has_mp = any(f-> contains(f, "_profile"), file)
    has_human = any(f-> contains(f, "_genefamilies"), file)
    flagged = !all([has_knead, has_mp, has_human])
    return (; has_knead, has_mp, has_human, flagged)
end) => ["has_knead", "has_mp", "has_human", "flagged"]
