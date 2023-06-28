"""
    resolve_links!(base::LocalBase, col; strict = true, unpack = r-> r isa AbstractString ? identity : first)

Resolves a vector of record hashes (or a vector of vectors of record hashes)
into the `uid`s of the linked record.
Eg.

```julia

```

The `strict` keyword argument will ensure that the column
contains a single record, and that the record is a hash.
"""
function resolve_links(base::LocalBase, col; strict = true, unpack = r-> ismissing(r) ? missing : r isa AbstractString ? identity(r) : first(r))
    strict && @assert all(r-> ismissing(r) || r isa AbstractString || length(r) == 1, col)
    col = unpack.(col)
    return [ismissing(r) ? missing : base[r] for r in col]
end

function biospecimens(base::LocalBase, project)
    proj = base["Projects", project]
    subs = base[proj[:Subjects]]
    df = DataFrame()
    for rec in base[mapreduce(r-> r[:Biospecimens], vcat, subs)]
        push!(df, rec.fields; cols=:union)
    end

    return df
end

function seqpreps(base::LocalBase, project)
    biosp = biospecimens(base, project)
    df = DataFrame()
    for row in eachrow(biosp)
        if !ismissing(row.seqprep)
            for seq in row.seqprep
                push!(df, (; base[seq].fields..., biospecimen = row.uid); cols=:union)
            end
        end
    end
    return df
end

function subjects(base::LocalBase, project)
    proj = base["Projects", project]
    subs = base[proj[:Subjects]]
    df = DataFrame()
    for rec in subs
        push!(df, rec.fields; cols=:union)
    end

    return df
end

function _project_map(base::LocalBase)
    records = base["Projects", :]

end
