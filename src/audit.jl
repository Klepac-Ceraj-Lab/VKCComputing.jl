const rawfastq_patterns = ["L00$(ln)_R$(rn)_001.fastq.gz" for ln in 1:4 for rn in 1:2]


const analysispatterns = (
    metaphlan = ["_profile.tsv", "_bowtie2.tsv", ".sam"],
    humann = ["_genefamilies.tsv", "_pathcoverage.tsv", "_pathabundance.tsv"],
    kneaddata = ["_kneaddata_paired_1.fastq.gz", "_kneaddata_paired_2.fastq.gz"]
)

function _find_files(dir; recursive=true)
    allfiles = Set(String[])
    if recursive
        for (root, d, files) in walkdir(dir)
            union!(allfiles, files)
        end
    else
        union!(allfiles, filter(f-> isfile(joinpath(dir, f)), readdir(dir)))
    end
    return allfiles
end


function find_raw(dir, ids; recursive=true)
    allfiles = _find_files(dir; recursive)

    for id in ids
        startswith(id, "FE") && continue
        patterns = [Regex(string(id, raw"_S\d+_", p)) for p in rawfastq_patterns]
        if !all(p-> any(f-> occursin(p, f), allfiles), patterns)
            @warn "At least one raw fastq missing for $id"
        end
    end
end

function find_analysis_files(dir, ids; recursive=true)
    allfiles = _find_files(dir; recursive)

    for id in ids
        startswith(id, "FE") && continue
        for tool in keys(analysispatterns)
            patterns = [Regex(string(id, raw"_S\d+", p)) for p in analysispatterns[tool]]
            if !all(p-> any(f-> occursin(p, f), allfiles), patterns)
                @warn "At least one $tool file missing for $id"
            end
        end
    end
end