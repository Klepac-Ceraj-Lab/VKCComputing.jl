const rawfastq_patterns = ["L00$(ln)_R$(rn)_001.fastq.gz" for ln in 1:4 for rn in 1:2]

const analysispatterns = (
    metaphlan = ["_profile.tsv", "_bowtie2.tsv", ".sam"],
    humann = ["_genefamilies.tsv", "_pathcoverage.tsv", "_pathabundance.tsv"],
    kneaddata = ["_kneaddata_paired_1.fastq.gz", "_kneaddata_paired_2.fastq.gz"]
)

function _files_to_tab(dir; recursive=true)
    nts = Iterators.map(recursive ? walkpath(Path(dir)) : readpath(Path(dir))) do fp
        dir = dirname(fp)
        "links" in dir.segments && return missing

        filename = basename(fp)
        pats = match(r"([a-zA-Z0-9]+)_(S\d+)(_([^.]+))?\.(.+)", filename)
        isnothing(pats) && return missing
        
        sample = pats.captures[1]
        well = pats.captures[2]
        filetype = pats.captures[4]
        ext = pats.captures[5]

        isnothing(filetype) && (filetype = "")
        if count(==('.'), ext) > 1 && endswith(ext, ".fastq.gz")
            filetype *= "." * replace(ext, ".fastq.gz" => "")
            ext = "fastq.gz"
        end

        return (; sample, well, filename, dir, filetype, ext)
    end

    return DataFrame([row for row in nts if !ismissing(row)])
end


function find_raw(dir, ids; recursive=true)
    # pbar = ProgressBar(; N = length(ids), description="Missing raw fastqs")

    notfound=0
    for id in track(ids)
        startswith(id, "FE") && continue
        patterns = [Regex(string(id, raw"_S\d+_", p)) for p in rawfastq_patterns]
        
        notfound += count(p-> any(f-> contains(f, p), allfiles), patterns)
    end

    expected = length(rawfastq_patterns) * length(ids)
    return (; expected, notfound)

end

function _files_from_pattern(df, pgroup; complete = true)
    fs = String[]
    for p in analysispatterns[pgroup]
        idx = findall(row-> contains(row.filename, p), eachrow(df))
        isempty(idx) && (complete=false)
        append!(fs, [joinpath(row.dir, row.filename) for row in eachrow(df[idx, :])])
    end
    return fs, complete
end

function find_analysis_files(dir, sids=nothing; recursive=true)
    allfiles = _files_to_tab(dir; recursive)
    stats = NamedTuple[]
    if isnothing(sids)
        base = AirBase("appSWOVVdqAi5aT5u")
        stab = AirTable("Samples", base)
        recs = Airtable.query(stab; filterByFormula="{Project} = 'ECHO'")
        sids = [rec[:sample] for rec in recs if haskey(rec, Symbol("MGX Batches"))]
    end

    sgroup = groupby(allfiles, :sample)

    @track for sid in sids
        if !haskey(sgroup, (; sample=sid))
            push!(stats, (; sample=sid, status = :notfound, metaphlan=String[], humann=String[], kneaddata=String[]))
        else
            stat = true
            sdf = sgroup[(; sample=sid)]
            (metaphlan, stat) = _files_from_pattern(sdf, :metaphlan; complete=stat)
            (humann, stat) = _files_from_pattern(sdf, :humann; complete=stat)
            (kneaddata, stat) = _files_from_pattern(sdf, :kneaddata; complete=stat)

            status = stat ? :complete : :incomplete
            push!(stats, (; sample=sid, status, metaphlan, humann, kneaddata))
        end

    end

    return stats
end
