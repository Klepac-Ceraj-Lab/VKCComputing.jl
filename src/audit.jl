const rawfastq_patterns = ["L00$(ln)_R$(rn)_001.fastq.gz" for ln in 1:4 for rn in 1:2]


const analysispatterns = (
    metaphlan = ["_profile.tsv", "_bowtie2.tsv", ".sam"],
    humann = ["_genefamilies.tsv", "_pathcoverage.tsv", "_pathabundance.tsv"],
    kneaddata = ["_kneaddata_paired_1.fastq.gz", "_kneaddata_paired_2.fastq.gz"]
)

_find_files(dir; recursive=true) = Set(string.(basename.(filter(isfile, 
                                                                collect(recursive ? walkpath(Path(dir)) : 
                                                                                    readpath(Path(dir))
                                                                )))))


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

function find_analysis_files(dir, ids; recursive=true)
    allfiles = _find_files(dir; recursive)
    allmissing = NamedTuple[]
    for id in ids
        startswith(id, "FE") && continue
        missing_patterns = NamedTuple[]
        for tool in keys(analysispatterns)
            for pattern in analysispatterns[tool]
                p = Regex(string(id, raw"_S\d+", pattern))
                any(f-> contains(f, p), allfiles) || push!(missing_patterns, (;tool, pattern, id))
            end
        end
        
        if !isempty(missing_patterns)
            @warn "Analysis file(s) missing for `$id`"
            append!(allmissing, missing_patterns)
            for pattern in missing_patterns
                @info "    missing $(pattern.tool) file: $(pattern.pattern) for id: $(pattern.id)"
            end
        end
    end
    return allmissing
end

function summarize(log; print_samples=false)
    samples = String[]
    filedict = Dict(string(tool) => Dict(pat=> 0 for pat in analysispatterns[tool]) for tool in keys(analysispatterns))
    for line in eachline(log)
        if contains(line, "Analysis file(s) missing")
            m = match(r"missing for `(\w+)`", line)
            push!(samples, m.captures[1])
        elseif contains(line, r"missing \w+ file:")
            m = match(r"missing (\w+) file: ([\w\.]+) for id", line)
            tool = m.captures[1]
            pat = m.captures[2]
            filedict[tool][pat] += 1
        end 
    end

    @info "Missing file(s) for $(length(samples)) samples"
    @info "Missing detail:"
    JSON3.pretty(filedict)
    if print_samples
        open("samples.txt", "w") do io
            println.(Ref(io), samples)
        end
    end
    return nothing
end