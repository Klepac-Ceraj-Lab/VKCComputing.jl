function get_analysis_files(dir = @load_preference("mgx_analysis_dir"))
    analysis_files = DataFrame(file   = String[],
                           dir    = String[],
                           sample = Union{Missing, String}[],
                           s_well = Union{Missing, String}[],
                           suffix = Union{Missing, String}[]
    )

    for (root, dirs, files) in walkdir(dir)
        for f in files
            m = match(r"^([\w\-]+)_(S\d+)_?(.+)", basename(f))
            if isnothing(m)
                push!(analysis_files, (; file = basename(f), dir = root, sample = missing, s_well = missing, suffix = missing))
            else
                push!(analysis_files, (; file = basename(f), dir = root, sample = m[1], s_well = m[2], suffix = m[3]))
            end
        end
    end
    return analysis_files
end