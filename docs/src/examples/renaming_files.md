# Renaming files (from biospecimen IDs and aliases)

## Motivation

After changing the way that we label samples,
we sometimes need to update a previous file-name
or table column name to reflect the new system.
This code will not produce the same outputs anymore,
since the state of drives and the database has changed in the meantime.
It's meant more as documentation of the process.

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
julia> rndf = DataFrame(mapreduce(vcat, biosp) do rec
    rows = [(; seqname = base[id][:uid], oldname = rec[:uid]) for id in rec[:seqprep]]
end);
```

It is in principle possible for a single biospecimen ID to refer
to multiple seqprep IDs.
Let's check that:

```julia-repl
julia> transform!(groupby(rndf, :oldname), "seqname"=> length => "n_seqs");

julia> subset(rndf, "n_seqs"=> ByRow(>(1)))
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

Now, we'll build a map of `oldname` -> `seqname`.

```julia-repl
rnmap = dictionary(zip(rndf.oldname, rndf.seqname))
1799-element Dictionary{String, String}
 "FG50159" │ "SEQ01107"
 "FG50160" │ "SEQ01108"
 "FG00846" │ "SEQ01371"
 #...
```

## Finding files to rename

I'm running this on `hopper`, so files are contained
in the `/grace` drive, as well as some other places.
But we'll start there.

The first thing to do is find all of the files
that could plausibly be in `ECHO`.
They all fit the pattern `r"F[EG]\d{5}` -
that is, "FE or "FG" followed by 5 numbers (`\d` stands for "digit").
Let's make sure that's true for our rename map:

```
julia> all(k-> contains(k, r"F[EG]\d{5}"), keys(rnmap))
true
```

So now we'll recurse through the directory,
saving any files that fit the pattern.
While we're at it, we can pull out some relevant info
and push it into a `DataFrame`.


```julia-repl
julia> filedf = DataFrame()

julia>  for (root, dir, files) in walkdir("/grace/sequencing/processed/mgx")
            for file in files
                m = match(r"^(F[EG]\d{5})_(S\d+)_", file)
                isnothing(m) && continue
                newname = get(rnmap, m[1], nothing)
                if isnothing(newname)
                    @warn "$(m[1]) matches the regex, but doesn't have a new name"
                    continue
                end
                push!(filedf, (;
                    oldname = m[1], newname, snum = m[2], oldpath = joinpath(root, file), newpath = joinpath(root, replace(file, m[1]=>newname))
                ))
            end
        end

julia> first(filedf, 5)
5×5 DataFrame
 Row │ oldname    newname   snum       oldpath                            newpath
     │ SubStrin…  String    SubStrin…  String                             String
─────┼──────────────────────────────────────────────────────────────────────────────────────────────────────
   1 │ FE01063    SEQ02371  S93        /grace/sequencing/processed/mgx/…  /grace/sequencing/processed/mgx/…
   2 │ FE01063    SEQ02371  S93        /grace/sequencing/processed/mgx/…  /grace/sequencing/processed/mgx/…
   3 │ FE01063    SEQ02371  S93        /grace/sequencing/processed/mgx/…  /grace/sequencing/processed/mgx/…
   4 │ FE01064    SEQ00905  S10        /grace/sequencing/processed/mgx/…  /grace/sequencing/processed/mgx/…
   5 │ FE01064    SEQ00905  S10        /grace/sequencing/processed/mgx/…  /grace/sequencing/processed/mgx/…

```

Now, we want to double check that all of the `oldname`s
are associated with the same `snum` to avoid ambiguities.
Here, we group by `oldname`, and then look at the `snum` column
to ensure there is only 1
(we check that the length of unique elements in that column is 1).

```
julia> transform!(groupby(filedf, :oldname), "snum"=> (sn-> length(unique(sn)) != 1) => "ambiguous");

julia> unique(subset(filedf, "ambiguous"=> identity), ["oldname", "snum"])
16×6 DataFrame
 Row │ oldname    newname   snum       oldpath                            newpath                            ambiguous
     │ SubStrin…  String    SubStrin…  String                             String                             Bool
─────┼─────────────────────────────────────────────────────────────────────────────────────────────────────────────────
   1 │ FG00004    SEQ01071  S26        /grace/sequencing/processed/mgx/…  /grace/sequencing/processed/mgx/…       true
   2 │ FG00004    SEQ01071  S46        /grace/sequencing/processed/mgx/…  /grace/sequencing/processed/mgx/…       true
   3 │ FG00005    SEQ01950  S50        /grace/sequencing/processed/mgx/…  /grace/sequencing/processed/mgx/…       true
   4 │ FG00005    SEQ01950  S58        /grace/sequencing/processed/mgx/…  /grace/sequencing/processed/mgx/…       true
   5 │ FG00016    SEQ01110  S52        /grace/sequencing/processed/mgx/…  /grace/sequencing/processed/mgx/…       true
   6 │ FG00016    SEQ01110  S70        /grace/sequencing/processed/mgx/…  /grace/sequencing/processed/mgx/…       true
   7 │ FG00017    SEQ02084  S64        /grace/sequencing/processed/mgx/…  /grace/sequencing/processed/mgx/…       true
   8 │ FG00017    SEQ02084  S82        /grace/sequencing/processed/mgx/…  /grace/sequencing/processed/mgx/…       true
   9 │ FG00021    SEQ01862  S53        /grace/sequencing/processed/mgx/…  /grace/sequencing/processed/mgx/…       true
  10 │ FG00021    SEQ01862  S94        /grace/sequencing/processed/mgx/…  /grace/sequencing/processed/mgx/…       true
  11 │ FG02294    SEQ02303  S1         /grace/sequencing/processed/mgx/…  /grace/sequencing/processed/mgx/…       true
  12 │ FG02294    SEQ02303  S34        /grace/sequencing/processed/mgx/…  /grace/sequencing/processed/mgx/…       true
  13 │ FG02471    SEQ01727  S16        /grace/sequencing/processed/mgx/…  /grace/sequencing/processed/mgx/…       true
  14 │ FG02471    SEQ01727  S89        /grace/sequencing/processed/mgx/…  /grace/sequencing/processed/mgx/…       true
  15 │ FG02614    SEQ01971  S10        /grace/sequencing/processed/mgx/…  /grace/sequencing/processed/mgx/…       true
  16 │ FG02614    SEQ01971  S9         /grace/sequencing/processed/mgx/…  /grace/sequencing/processed/mgx/…       true
```

So for now, we'll leave these out and deal with them later.

## Renaming

```julia-repl
julia>  for grp in groupby(filedf, "oldname")
            old = first(grp.oldname)
            @info "Working on $old"
            if any(grp.ambiguous)
                @warn "$old has multiple sequecing results: $(unique(grp.snum)); skipping!"
            else
                @info "Renaming $(old) to $(first(grp.newname))"
                for row in eachrow(grp)
                    @debug "$(row.oldpath) => $(row.newpath)"
                    mv(row.oldpath, row.newpath)
                end
            end
        end
```

## Dealing with Ambiguities

Let's go back to our ambiguous sequences.

```julia-repl
julia> ambi = subset(filedf, "ambiguous"=> identity);

julia> unique(select(ambi, ["oldname", "newname", "snum"]))
16×3 DataFrame
 Row │ oldname    newname   snum
     │ SubStrin…  String    SubStrin…
─────┼────────────────────────────────
   1 │ FG00004    SEQ01071  S26
   2 │ FG00004    SEQ01071  S46
   3 │ FG00005    SEQ01950  S50
   4 │ FG00005    SEQ01950  S58
   5 │ FG00016    SEQ01110  S52
   6 │ FG00016    SEQ01110  S70
   7 │ FG00017    SEQ02084  S64
   8 │ FG00017    SEQ02084  S82
   9 │ FG00021    SEQ01862  S53
  10 │ FG00021    SEQ01862  S94
  11 │ FG02294    SEQ02303  S1
  12 │ FG02294    SEQ02303  S34
  13 │ FG02471    SEQ01727  S16
  14 │ FG02471    SEQ01727  S89
  15 │ FG02614    SEQ01971  S10
  16 │ FG02614    SEQ01971  S9

```

For the first 12 rows
(samples `FG00004`, `F00005`, `FG00016`, `FG00017`, `FG0021`, and `FG02294`),
the solution is relatively simple.
Each of these had 2 aliquots of the same biospecimen sequenced.
So in each of those cases,
I duplicated the record in the SequencingPrep table
(generating a new `SEQ` id), added the correct S-well number,
and put in the old IDs as aliases. Eg, `FG00004` is now

| uid      | autonumber | biospecimen | swell | alias        |
| -------- | ---------- | ----------- |------ | ------------ |
| SEQ01071 | 1071       | FG00004     | S26   | C0117_4F_1A  |
| SEQ02505 | 2505       | FG00004     | S46   | C0117_4F_1B  |

For FG02614, there is only a single file (`FG02614_S9_pfams.tsv`)
that has the S9 identifier.
Looking at the contents of that file:

```
❯ head mgx/humann/regroup/FG02614_S9_pfams.tsv
# Gene Family   FG02610_S9_Abundance-RPKs
UNMAPPED        14128546.0
UNGROUPED       29634105.328100212
UNGROUPED|g__Adlercreutzia.s__Adlercreutzia_equolifaciens       17608.29535663359
UNGROUPED|g__Agathobaculum.s__Agathobaculum_butyriciproducens   44303.814025389926
UNGROUPED|g__Akkermansia.s__Akkermansia_muciniphila     118128.883395747
UNGROUPED|g__Alistipes.s__Alistipes_finegoldii  125084.06209765507
UNGROUPED|g__Alistipes.s__Alistipes_indistinctus        24720.017810163998
UNGROUPED|g__Alistipes.s__Alistipes_putredinis  1052709.4440796026
UNGROUPED|g__Alistipes.s__Alistipes_shahii      86567.54527132263
```

Based on the header, it looks like it belongs to `FG02610`.
We have all of the files for `FG02610`, so I'm just going to delete these
files (the `FG02614_S9` ones).

`FG02471` is weirder. We have all of the relevant files for both `S16` and `S89`.
Looking at the contents, 

```
kevin in vkclab-ada in /lovelace/sequencing/processed on ☁️  (us-east-1)
❯ head -5 mgx/metaphlan/FG02471_S*_profile.tsv
==> mgx/metaphlan/FG02471_S16_profile.tsv <==
#mpa_v30_CHOCOPhlAn_201901
#/home/vklepacc/miniconda3/envs/biobakery3/bin/metaphlan output/kneaddata/FG02471_S16_kneaddata.fastq output/metaphlan/FG02471_S16_profile.tsv --bowtie2out output/metaphlan/FG02471_S16_bowtie2.tsv --samout output/metaphlan/FG02471_S16.sam --input_type fastq --nproc 8 --bowtie2db /pool001/vklepacc/databases/metaphlan
#SampleID       Metaphlan_Analysis
#clade_name     NCBI_tax_id     relative_abundance      additional_species
k__Bacteria     2       99.08787

==> mgx/metaphlan/FG02471_S89_profile.tsv <==
#mpa_v30_CHOCOPhlAn_201901
#/home/vklepacc/miniconda3/envs/biobakery3/bin/metaphlan output/kneaddata/C0477-5F-1A_S89_merged.fastq output/metaphlan/C0477-5F-1A_S89_profile.tsv --bowtie2out output/metaphlan/C0477-5F-1A_S89_bowtie2.tsv --samout output/metaphlan/C0477-5F-1A_S89.sam --input_type fastq --nproc 8
#SampleID       Metaphlan_Analysis
#clade_name     NCBI_tax_id     relative_abundance      additional_species
k__Bacteria     2       99.12309

kevin in vkclab-ada in /lovelace/sequencing/processed on ☁️  (us-east-1)
❯ head -5 mgx/humann/main/FG02471_*genefamilies.tsv
==> mgx/humann/main/FG02471_S16_genefamilies.tsv <==
# Gene Family   FG02471_S16_Abundance-RPKs
UNMAPPED        4356120.0000000000
UniRef90_A0A3E2XRX6     15802.1208367696
UniRef90_A0A3E2XRX6|g__Dorea.s__Dorea_longicatena       15802.1208367696
UniRef90_A5ZYV3 12866.1165754399

==> mgx/humann/main/FG02471_S89_genefamilies.tsv <==
# Gene Family   C0477-5F-1A_S89_Abundance-RPKs
UNMAPPED        3152316.0000000000
UniRef90_A7V4G2 8649.8613270401
UniRef90_A7V4G2|g__Bacteroides.s__Bacteroides_uniformis 8552.3697112122
UniRef90_A7V4G2|unclassified    97.4916158279
```

The `S89` has the old ID in the header (`C0477-5F-1A`),
which is the correct one according to the old database,
but it looks like this same ID was sequenced in a different batch (old batch 11)
under the ID `FG00757`. Given the surrounding S-well IDs,
it looks like `S16`, sequenced in (old) batch 17 is correctly attributed
to `FG02471` (which will become `SEQ01727`),
while `S89` should go with `FG00757` (which becomes `SEQ02512`). 

## Conclusion

This example shows how to download and access the local airtable base,
use it to generate a rename mapping, and use that to rename files,
taking into account ambiguities.