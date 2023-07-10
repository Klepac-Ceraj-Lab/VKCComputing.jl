struct AWSRecords
    df::DataFrame
    keys::Dictionary
end

function aws_ls(path="s3://vkc-sequencing/processed/mgx/")
    path_parts = splitpath(path)
    (first(path_parts) == "s3:" && length(path_parts) > 1) || error("Not a valid s3 path: $path")
    basepath = string("s3://", path_parts[2])

    io = IOBuffer()
    @info "Downloading file info from AWS: $path"
    run(pipeline(`aws s3 ls --recursive $path`, io))
    seek(io, 0)
    @info "Building DataFrame"
    df = DataFrame(Iterators.map(eachline(io)) do line
        spl = split(line)
        (mod, size, remotepath) = length(spl) == 4 ? 
                                (ZonedDateTime(DateTime("$(spl[1])T$(spl[2])"), tz"America/New_York"), spl[3], joinpath(basepath, spl[4])) : 
                                (missing,missing,missing)
        # if !ismissing(remotepath)
        #     pparts = splitpath(path)
        #     rpparts = splitpath(remotepath)


        # end
        return (; mod, size, path=remotepath)
    end)

    df = disallowmissing(df[completecases(df), :])

    transform!(df,
        "path" => ByRow(dirname) => "dir",
        "path" => ByRow(basename) => "file",
    )
    transform!(df, "file" => ByRow(f-> begin
        m = match(r"([\w\-]+)_(S\d{1,2})_?(.+)", f)
        (seqprep, S_well, suffix) = isnothing(m) ? (missing, missing, missing) : m.captures
        return (; seqprep, S_well, suffix)
    end) => ["seqprep", "S_well", "suffix"])

    return df
end

function _remove_path_overlap(p1, p2)
    p1parts = splitpath(p1)
    p2parts = splitpath(p2)

end
