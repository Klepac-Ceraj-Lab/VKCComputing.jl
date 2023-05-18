# Renaming files (from biospecimen IDs and aliases)

## Motivation

After changing the way that we label samples,
we sometimes need to update a previous file-name
or table column name to reflect the new system.

## Getting current data

The first thing to do in most projects is to load
the airtable database into memory.
If you want to guarantee that you have the most recent
version of any particular table, use the `update` argument
of [`LocalBase`](@ref).

```julia-repl
julia> using VKCComputing, Dates

julia> base = LocalBase(; update=["Biospecimens"=> Week(1), "Projects"=> true]);
[ Info: Table Aliases does not need updating updating. Use `update = true` or `update = {shorter interval}` to override
[ Info: Loading records from local JSON file
[ Info: Table Biospecimens does not need updating updating. Use `update = true` or `update = {shorter interval}` to override
[ Info: Loading records from local JSON file
#...
```

Let's say I want to find any samples from the ECHO project that need to be updated.
I don't remember how the ECHO project is referred to in the database,
so I need to check what the `uid`s from the "Projects" table are:

```julia-repl
julia> uids(base, "Projects") # or `uids(base["Projects"])`
2-element Dictionaries.Indices{String}
 "resonance"
 "khula"
```

Looks like it's "resonance"!
Next, I'll get all of the samples associated with that project.
There are a couple of ways to do that;
I'll use a somewhat roundabout way to show off a couple of features:

```julia-repl
julia> proj = base["Projects", "resonance"]; # get the project record

julia> keys(proj); # look at what fields are available... I want :Subjects
(:uid, :name, :Visits, :Subjects)

julia> first(proj[:Subjects], 5) # verify that these are record hashes
5-element Vector{String}:
 "recF3MoP0RZ4EqRrh"
 "recnZclKoXvxPbARR"
 "recW3HYwsZPYt8rtD"
 "recmljdPsUa55j2BS"
 "recaRvIXKLtDNQBOb"
```

Once I have a list of records hashes,
I can use them to pull records directly:

```julia-repl
julia> subjects = base[proj[:Subjects]]
770-element Vector{Airtable.AirRecord}:
 Airtable.AirRecord("recF3MoP0RZ4EqRrh", AirTable("Subjects"), (uid = "1255", Biospecimens = ["recnfhuOaRwSfOLOq", "recrSIHTxVxj3JXav", "rec7j3VFnZb0Uue5k", "recrfP0SIqxTjk0Vk", "recLsUbcOI32ZjrSN", "rec1Ai2Nz0yCmpLpa", "receGDNvbRuQpiCNQ", "recPVakgZpe01B9ZJ", "rec5iE5o92ManNgDG"], project = ["recOlnbWbRoJdy4Nq"]))
 Airtable.AirRecord("recnZclKoXvxPbARR", AirTable("Subjects"), (uid = "0672", Biospecimens = ["recnKOG7QwOKCG8Tk", "recisA4suwsc4iq3U", "rec98YN0dSis3lxbQ", "recV29l0ADxUL2xk5", "recLRCssF2ZBC8suZ", "rec46VGKOVth2SQ6U", "recDUj6DDLyjNSbki", "reclzmMkTJiWFCJWI", "reczBSh8Vav6D0qQy", "reclUM1eREFipQ6ND"], project = ["recOlnbWbRoJdy4Nq"]))
 #...
```

Now, I can get all of the biospecimens associated with these subjects:

```julia-repl
julia> mapreduce(rec-> get(rec, :Biospecimens, []), vcat, subjects)
3317-element Vector{String}:
 "recnfhuOaRwSfOLOq"
 "recrSIHTxVxj3JXav"
 "rec7j3VFnZb0Uue5k"
 "recrfP0SIqxTjk0Vk"
#...
```

Then, I can use these record hashes to pull the biospecimen records:

```julia-repl
julia> biosp = base[mapreduce(rec-> get(rec, :Biospecimens, []), vcat, subjects)]
3317-element Vector{Airtable.AirRecord}:
 Airtable.AirRecord("recnfhuOaRwSfOLOq", AirTable("Biospecimens"), (uid = "FE50074", subject = ["recF3MoP0RZ4EqRrh"], collection_buffer = ["recxsTHmTS84TBMPF"], aliases = ["recP0jpfk49JXtVp2"], project = ["recOlnbWbRoJdy4Nq"]))
 Airtable.AirRecord("recrSIHTxVxj3JXav", AirTable("Biospecimens"), (uid = "FE01868", subject = ["recF3MoP0RZ4EqRrh"], collection = 3, collection_buffer = ["recxsTHmTS84TBMPF"], visit = ["recjx3Tb7wf6WXO6t"], aliases = ["recsqOcdY54CU5hQT"], project = ["recOlnbWbRoJdy4Nq"]))
#...
```

A more straightforwards approach would have been to look at all of the biospecimen records,
and filter on the ones where `Project` had the id hash for the `"resonance"` project.

## Building the renaming map

Now that we have all of the biospecimens for ECHO,
let's just get the ones that have been shotgun sequenced,
and identify the `SequencingPrep` records associated with them.

```julia-repl
julia> mapreduce(keys, union, biosp)
8-element Vector{Symbol}:
 :uid
 :subject
 :collection_buffer
 :aliases
 :project
 :collection
 :visit
 :seqprep

julia> filter!(rec-> haskey(rec, :seqprep), biosp);
```

Now, we want to build a mapping of biospecimen => seqprep ID.
I'll store this as rows in a `DataFrame`.

```julia-repl
julia> rnmap = DataFrame(mapreduce(vcat, biosp) do rec
    rows = [(; seqname = base[id][:uid], oldname = rec[:uid]) for id in rec[:seqprep]]
end);
```

Unfortunately, some of these are ambiguous -
that is, the same biospecimen can refer to multiple seqprep IDs.
Let's check that:

```julia-repl
julia> transform!(groupby(rnmap, :oldname), "seqname"=> length => "n_seqs");

julia> subset(rnmap, "n_seqs"=> ByRow(>(1)))
6×3 DataFrame
 Row │ seqname   oldname  n_seqs
     │ String    String   Int64
─────┼───────────────────────────
   1 │ SEQ02303  FG02294       2
   2 │ SEQ02303  FG02294       2
   3 │ SEQ01232  FE01105       2
   4 │ SEQ01110  FG00016       2
   5 │ SEQ01110  FG00016       2
   6 │ SEQ01232  FE01105       2
```

It looks like these aren't ambiguous after all,
though it's unclear how they ended up in the table twice.
In any case, we can ignore them for now, since 