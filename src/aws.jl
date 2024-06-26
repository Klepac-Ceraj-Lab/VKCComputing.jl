# struct AWSRecords
#     df::DataFrame
#     keys::Dictionary
# end


"""
    aws_ls(path="s3://vkc-sequencing/processed/mgx/")

Get a (recurssive) listing of files / dicrectories contained at `path`, 
and return a `DataFrame` with the following headers:

- `mod`: `DateTime` that the file was last modified
- `size`: (`Int`) in bytes
- `path`: full remote path (eg `s3://bucket-name/some/SEQ9999_S42_profile.tsv`)
- `dir`: Remote directory for file (eg `s3://bucket-name/some/`), equivalent to `dirname(path)`
- `file`: Remote file name (eg `SEQ9999_S42_profile.tsv`)
- `seqprep`: For files that match `SEQ\\d+_S\\d+_.+`, the sequencing Prep ID (eg `SEQ9999`). Otherwise, `missing`.
- `S_well`: For files that match `SEQ\\d+_S\\d+_.+`, the well ID, including `S` (eg `S42`). Otherwise, `missing`.
- `suffix`: For files that match `SEQ\\d+_S\\d+_.+`, the remainder of the file name, aside from a leading `_` (eg `profile.tsv`). Otherwise, `missing`.
"""
function aws_ls(path="s3://vkc-sequencing/processed/mgx/"; recursive=true, kwargs...)
    if startswith(path, "s3")
        path_parts = splitpath(path)
        (first(path_parts) == "s3:" && length(path_parts) > 1) || error("Not a valid s3 path: $path")
        basepath = string("s3://", path_parts[2])

        io = IOBuffer()
        @info "Downloading file info from AWS: $path"
        run(pipeline(Cmd([
                "aws", "s3", "ls", path, Iterators.flatten(
                    [(val isa Bool && val) ? ("--$arg",) : ("--$arg", string(val)) for (arg, val) in [[:recursive=>recursive]; kwargs...]]
                   )...]), io)
        )
        seek(io, 0)
    else
        io = open(path, "r")
    end
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

