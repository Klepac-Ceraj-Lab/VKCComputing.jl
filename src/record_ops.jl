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
function resolve_links(base::LocalBase, col; strict = true, unpack = r-> r isa AbstractString ? identity(r) : first(r))
    strict && @assert all(r-> r isa AbstractString || length(r) == 1, col)
    col = unpack.(col)
    return base[col]
end