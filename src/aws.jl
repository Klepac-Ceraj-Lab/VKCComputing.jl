struct AWSRecords
    df::DataFrame
    keys::Dictionary
end

function aws_ls(path="s3://vkc-sequencing/processed/mgx/")
    io = IOBuffer()
    @info "Downloading file info from AWS: $path"
    run(pipeline(`aws s3 ls --recursive $path`, io))
    seek(io, 0)
    @info "Building DataFrame"
    df = DataFrame(Iterators.map(Iterators.filter(l-> contains(l, "mgx/"), eachline("vkc-sequencing.txt"))) do line
        (d, t, s, p) =  split(line)
        (; mod = ZonedDateTime(DateTime("$(d)T$(t)"), tz"America/New_York"), size=s, path=p)
    end)

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
