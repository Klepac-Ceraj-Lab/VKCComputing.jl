module SeqAudit

export rename_map,
       rename_files

using CSV
using DataFrames

function rename_map(file; replacements=[])
    isfile(file) || throw(ArgumentError())
    rename = CSV.read(file, DataFrame)
    rnmap = Dict(row[1] => row[2] for row in eachrow(rename))
    for r in replacements 
        rnmap = Dict(replace(key, r) => rnmap[key] for key in keys(rnmap))
    end
    return rnmap
end

function rename_files(dir, rnmap; dryrun=false, recurse=false, force=false, sep=nothing)
    fs = String[]
    ks = keys(rnmap)
    if recurse
        @info "Recusing into $dir"
        for (root, dirs, files) in walkdir(dir)
            filter!(file-> any(key-> occursin(key, file), ks), files)
            append!(fs, joinpath.(Ref(root), files))
        end
    else
        files = readdir(dir)
        filter!(file-> isfile(file) && any(key-> occursin(key, file), ks), files)
        append!(fs, files)
    end

    ks = collect(ks)
    for f in fs
        idx = findfirst(key-> occursin(key, f), ks)
        newf = replace(f, ks[idx] => "$(rnmap[ks[idx]] * (isnothing(sep) ? "" : sep))")
        @info "Changing `$f` to `$newf`"
        dryrun || mv(f, newf;force)
    end
end


end # module