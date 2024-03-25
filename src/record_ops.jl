"""
    resolve_links(base::LocalBase, col; strict = true, unpack = r-> r isa AbstractString ? identity : first)

Resolves a vector of record hashes (or a vector of vectors of record hashes)
into the `uid`s of the linked record.

If the `strict` kwarg is `true`, it is expected that `col` is composed of *either*

1. a record hash
2. a one-element Vector containing a record hash

If `strict` is `false`, it is recommended to pass a custom function
to `unpack`, which will be called on each row of the `col`.

Eg.

```julia-repl
julia> base = LocalBase();

julia> visits = [rec[:visit] for rec in base["Biospecimens"][["FG00004", "FG00006", "FG00008"]]]
3-element Vector{JSON3.Array{String, Base.CodeUnits{UInt8, String}, SubArray{UInt64, 1, Vector{UInt64}, Tuple{UnitRange{Int64}}, true}}}:
 ["recEnxbSPMNZaoySF"]
 ["recT1EUtiUSZaypxl"]
 ["recyHSMZp0HLErHLz"]

 julia> resolve_links(base, visits)
 3-element Vector{Airtable.AirRecord}:
  Airtable.AirRecord("recEnxbSPMNZaoySF", AirTable("Visits"), (uid = "mc03", Biospecimens = ["recdO7nHQI7VY5ynn", #...
  Airtable.AirRecord("recT1EUtiUSZaypxl", AirTable("Visits"), (uid = "ec02", Biospecimens = ["recmuwWA1bkhpxQ4P", #...
  Airtable.AirRecord("recyHSMZp0HLErHLz", AirTable("Visits"), (uid = "mc05", Biospecimens = ["recOlXNl7OMQH6cpF", #...

julia> seqpreps =  [rec[:seqprep] for rec in base["Biospecimens"][["FG00004", "FG00006", "FG00008"]]]
3-element Vector{JSON3.Array{String, Base.CodeUnits{UInt8, String}, SubArray{UInt64, 1, Vector{UInt64}, Tuple{UnitRange{Int64}}, true}}}:
 ["rec33GrUTnfeNTCXe", "recBh1xD1xOw4qkhO"]
 ["recq5fj9BQb7vugUd"]
 ["recbNNM1qWXOLhnye"]
```

Notice that the first record here has 2 entries, so `strict=true` will fail.

```julia-repl
julia> resolve_links(base, seqpreps)
ERROR: ArgumentError: At least one record has multiple entries. Use `strict = false` and `unpack` to handle this.
Stacktrace:
#...
```

If you just pass `strict = false`, the default `unpack` function will simply take the first record:

```julia-repl
julia> resolve_links(base, seqpreps; strict = false)
3-element Vector{Airtable.AirRecord}:
 Airtable.AirRecord("rec33GrUTnfeNTCXe", AirTable("SequencingPrep"), (uid = "SEQ01071", biospecimen = ["recDcm98dkmNP3Zic"] #...
 Airtable.AirRecord("recq5fj9BQb7vugUd", AirTable("SequencingPrep"), (uid = "SEQ00729", biospecimen = ["recL6D53j76R0eRp5"] #...
 Airtable.AirRecord("recbNNM1qWXOLhnye", AirTable("SequencingPrep"), (uid = "SEQ01960", biospecimen = ["rech7m4F33iGWtgOU"] #...
```

If you wish to keep all records, use `Iterators.flatten()`, or pass a custom `unpack` function:

```julia-repl
julia> resolve_links(base, Iterators.flatten(seqpreps); strict = false)
4-element Vector{Airtable.AirRecord}:
 Airtable.AirRecord("rec33GrUTnfeNTCXe", AirTable("SequencingPrep"), (uid = "SEQ01071", biospecimen = ["recDcm98dkmNP3Zic"] #...
 Airtable.AirRecord("recBh1xD1xOw4qkhO", AirTable("SequencingPrep"), (uid = "SEQ02505", biospecimen = ["recDcm98dkmNP3Zic"] #...
 Airtable.AirRecord("recq5fj9BQb7vugUd", AirTable("SequencingPrep"), (uid = "SEQ00729", biospecimen = ["recL6D53j76R0eRp5"] #...
 Airtable.AirRecord("recbNNM1qWXOLhnye", AirTable("SequencingPrep"), (uid = "SEQ01960", biospecimen = ["rech7m4F33iGWtgOU"] #...

julia> resolve_links(base, seqpreps; strict = false, unpack = identity)
3-element Vector{Vector{Airtable.AirRecord}}:
 [Airtable.AirRecord("rec33GrUTnfeNTCXe", AirTable("SequencingPrep"), (uid = "SEQ01071", biospecimen = ["recDcm98dkmNP3Zic"] #...
  Airtable.AirRecord("recBh1xD1xOw4qkhO", AirTable("SequencingPrep"), (uid = "SEQ02505", biospecimen = ["recDcm98dkmNP3Zic"] #...
 ]
 [Airtable.AirRecord("recq5fj9BQb7vugUd", AirTable("SequencingPrep"), (uid = "SEQ00729", biospecimen = ["recL6D53j76R0eRp5"] #...
 [Airtable.AirRecord("recbNNM1qWXOLhnye", AirTable("SequencingPrep"), (uid = "SEQ01960", biospecimen = ["rech7m4F33iGWtgOU"] #...
```

"""
function resolve_links(base::LocalBase, col; strict = true, unpack = r-> ismissing(r) ? missing : r isa AbstractString ? identity(r) : first(r))
    if strict && !all(r-> ismissing(r) || r isa AbstractString || length(r) == 1, col)
       throw(ArgumentError("At least one record has multiple entries. Use `strict = false` and `unpack` to handle this.")) 
    end
    col = unpack.(col)
    return [ismissing(r) ? missing : base[r] for r in col]
end

"""
    biospecimens([base::LocalBase, ]project; strict=true)

Get all records from the table `Biospecimens` belonging to `project`.

NOTE: `strict` is set to false by default,
and will exclude any records where `keep != 1`.
"""
function biospecimens(base::LocalBase, project; strict=true)
    _check_project(base, project) # throws error if bad key
    proj = base["Projects", project]
    subs = base[proj[:Subjects]]
    df = DataFrame()
    for rec in base[mapreduce(r-> r[:Biospecimens], vcat, Iterators.filter(s-> haskey(s, :Biospecimens), subs))]
        (strict && rec[:keep] == 0) && continue
        push!(df, rec.fields; cols=:union)
    end

    return df
end

biospecimens(project; strict=true) = biospecimens(LocalBase(), project; strict)

function biospecimens(base::LocalBase=LocalBase(); strict=true)
    mapreduce(p-> biospecimens(base, p.fields[:uid]; strict), (df1, df2) -> vcat(df1, df2; cols=:union), base["Projects"][:])
end

"""
    seqpreps([base::LocalBase, ]project; strict=true)

Get all records from the table `SequencingPrep` belonging to `project`.

NOTE: `strict` is set to false by default,
and will exclude any records where `keep != 1`.
"""
function seqpreps(base::LocalBase, project; strict=true)
    _check_project(base, project) # throws error if bad key
    biosp = biospecimens(base, project; strict)
    df = DataFrame()
    for row in eachrow(biosp)
        if !ismissing(row.seqprep)
            for seq in row.seqprep
                (strict && base[seq][:keep] == 0) && continue
                push!(df, (; base[seq].fields..., biospecimen = row.uid); cols=:union)
            end
        end
    end
    return df
end

seqpreps(project; strict=true) = seqpreps(LocalBase(), project; strict)

function seqpreps(base::LocalBase=LocalBase(); strict=true)
    mapreduce(p-> seqpreps(base, p.fields[:uid]; strict), (df1, df2) -> vcat(df1, df2; cols=:union), base["Projects"][:])
end

"""
    subjects([base::LocalBase, ]project; strict=true)

Get all records from the table `Subjects` belonging to `project`.

NOTE: `strict` is set to false by default,
and will exclude any records where `keep != 1`.
"""
function subjects(base::LocalBase, project; strict=true)
    _check_project(base, project) # throws error if bad key
    proj = base["Projects", project]
    subs = base[proj[:Subjects]]
    df = DataFrame()
    for rec in subs
        (strict && rec[:keep] == 0) && continue
        push!(df, rec.fields; cols=:union)
    end

    return df
end

subjects(project; strict=true) = subjects(LocalBase(), project; strict)

function subjects(base::LocalBase=LocalBase(); strict=true)
    mapreduce(p-> subjects(base, p.fields[:uid]; strict), (df1, df2) -> vcat(df1, df2; cols=:union), base["Projects"][:])
end

function _project_map(base::LocalBase)
    records = base["Projects", :]
    return [(; uid = proj[:uid], airtable_id = proj.id) for proj in records]
end

function _check_project(base, project) 
    uids = (p[:uid] for p in _project_map(base))
    project ∈ uids || throw(
    ArgumentError("""
        \"$project\" is not a valid project. Possible options are $(
            join(["\"$p\"" for p in uids], ", ")
        )""")
    )
end
