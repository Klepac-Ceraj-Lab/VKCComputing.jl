var documenterSearchIndex = {"docs":
[{"location":"examples/select_subjects/#Selecting-samples-from-list-of-subjects","page":"Selecting samples from list of subjects","title":"Selecting samples from list of subjects","text":"","category":"section"},{"location":"examples/select_subjects/","page":"Selecting samples from list of subjects","title":"Selecting samples from list of subjects","text":"Often, we want to identify all samples from a list of subjects.","category":"page"},{"location":"examples/renaming_files/#Renaming-files-(from-biospecimen-IDs-and-aliases)","page":"Renaming","title":"Renaming files (from biospecimen IDs and aliases)","text":"","category":"section"},{"location":"examples/renaming_files/#Motivation","page":"Renaming","title":"Motivation","text":"","category":"section"},{"location":"examples/renaming_files/","page":"Renaming","title":"Renaming","text":"After changing the way that we label samples, we sometimes need to update a previous file-name or table column name to reflect the new system. This code will not produce the same outputs anymore, since the state of drives and the database has changed in the meantime. It's meant more as documentation of the process.","category":"page"},{"location":"examples/renaming_files/#Getting-current-data","page":"Renaming","title":"Getting current data","text":"","category":"section"},{"location":"examples/renaming_files/","page":"Renaming","title":"Renaming","text":"The first thing to do in most projects is to load the airtable database into memory. If you want to guarantee that you have the most recent version of any particular table, use the update argument of LocalBase.","category":"page"},{"location":"examples/renaming_files/","page":"Renaming","title":"Renaming","text":"julia> using VKCComputing, Dates\n\njulia> base = LocalBase(; update=[\"Biospecimens\"=> Week(1), \"Projects\"=> true]);\n[ Info: Table Aliases does not need updating updating. Use `update = true` or `update = {shorter interval}` to override\n[ Info: Loading records from local JSON file\n[ Info: Table Biospecimens does not need updating updating. Use `update = true` or `update = {shorter interval}` to override\n[ Info: Loading records from local JSON file\n#...","category":"page"},{"location":"examples/renaming_files/","page":"Renaming","title":"Renaming","text":"Let's say I want to find any samples from the ECHO project that need to be updated. I don't remember how the ECHO project is referred to in the database, so I need to check what the uids from the \"Projects\" table are:","category":"page"},{"location":"examples/renaming_files/","page":"Renaming","title":"Renaming","text":"julia> uids(base, \"Projects\") # or `uids(base[\"Projects\"])`\n2-element Dictionaries.Indices{String}\n \"resonance\"\n \"khula\"","category":"page"},{"location":"examples/renaming_files/","page":"Renaming","title":"Renaming","text":"Looks like it's \"resonance\"! Next, I'll get all of the samples associated with that project. There are a couple of ways to do that; I'll use a somewhat roundabout way to show off a couple of features:","category":"page"},{"location":"examples/renaming_files/","page":"Renaming","title":"Renaming","text":"julia> proj = base[\"Projects\", \"resonance\"]; # get the project record\n\njulia> keys(proj); # look at what fields are available... I want :Subjects\n(:uid, :name, :Visits, :Subjects)\n\njulia> first(proj[:Subjects], 5) # verify that these are record hashes\n5-element Vector{String}:\n \"recF3MoP0RZ4EqRrh\"\n \"recnZclKoXvxPbARR\"\n \"recW3HYwsZPYt8rtD\"\n \"recmljdPsUa55j2BS\"\n \"recaRvIXKLtDNQBOb\"","category":"page"},{"location":"examples/renaming_files/","page":"Renaming","title":"Renaming","text":"Once I have a list of records hashes, I can use them to pull records directly:","category":"page"},{"location":"examples/renaming_files/","page":"Renaming","title":"Renaming","text":"julia> subjects = base[proj[:Subjects]]\n770-element Vector{Airtable.AirRecord}:\n Airtable.AirRecord(\"recF3MoP0RZ4EqRrh\", AirTable(\"Subjects\"), (uid = \"1255\", Biospecimens = [\"recnfhuOaRwSfOLOq\", \"recrSIHTxVxj3JXav\", \"rec7j3VFnZb0Uue5k\", \"recrfP0SIqxTjk0Vk\", \"recLsUbcOI32ZjrSN\", \"rec1Ai2Nz0yCmpLpa\", \"receGDNvbRuQpiCNQ\", \"recPVakgZpe01B9ZJ\", \"rec5iE5o92ManNgDG\"], project = [\"recOlnbWbRoJdy4Nq\"]))\n Airtable.AirRecord(\"recnZclKoXvxPbARR\", AirTable(\"Subjects\"), (uid = \"0672\", Biospecimens = [\"recnKOG7QwOKCG8Tk\", \"recisA4suwsc4iq3U\", \"rec98YN0dSis3lxbQ\", \"recV29l0ADxUL2xk5\", \"recLRCssF2ZBC8suZ\", \"rec46VGKOVth2SQ6U\", \"recDUj6DDLyjNSbki\", \"reclzmMkTJiWFCJWI\", \"reczBSh8Vav6D0qQy\", \"reclUM1eREFipQ6ND\"], project = [\"recOlnbWbRoJdy4Nq\"]))\n #...","category":"page"},{"location":"examples/renaming_files/","page":"Renaming","title":"Renaming","text":"Now, I can get all of the biospecimens associated with these subjects:","category":"page"},{"location":"examples/renaming_files/","page":"Renaming","title":"Renaming","text":"julia> mapreduce(rec-> get(rec, :Biospecimens, []), vcat, subjects)\n3317-element Vector{String}:\n \"recnfhuOaRwSfOLOq\"\n \"recrSIHTxVxj3JXav\"\n \"rec7j3VFnZb0Uue5k\"\n \"recrfP0SIqxTjk0Vk\"\n#...","category":"page"},{"location":"examples/renaming_files/","page":"Renaming","title":"Renaming","text":"Then, I can use these record hashes to pull the biospecimen records:","category":"page"},{"location":"examples/renaming_files/","page":"Renaming","title":"Renaming","text":"julia> biosp = base[mapreduce(rec-> get(rec, :Biospecimens, []), vcat, subjects)]\n3317-element Vector{Airtable.AirRecord}:\n Airtable.AirRecord(\"recnfhuOaRwSfOLOq\", AirTable(\"Biospecimens\"), (uid = \"FE50074\", subject = [\"recF3MoP0RZ4EqRrh\"], collection_buffer = [\"recxsTHmTS84TBMPF\"], aliases = [\"recP0jpfk49JXtVp2\"], project = [\"recOlnbWbRoJdy4Nq\"]))\n Airtable.AirRecord(\"recrSIHTxVxj3JXav\", AirTable(\"Biospecimens\"), (uid = \"FE01868\", subject = [\"recF3MoP0RZ4EqRrh\"], collection = 3, collection_buffer = [\"recxsTHmTS84TBMPF\"], visit = [\"recjx3Tb7wf6WXO6t\"], aliases = [\"recsqOcdY54CU5hQT\"], project = [\"recOlnbWbRoJdy4Nq\"]))\n#...","category":"page"},{"location":"examples/renaming_files/","page":"Renaming","title":"Renaming","text":"A more straightforwards approach would have been to look at all of the biospecimen records, and filter on the ones where Project had the id hash for the \"resonance\" project.","category":"page"},{"location":"examples/renaming_files/#Building-the-renaming-map","page":"Renaming","title":"Building the renaming map","text":"","category":"section"},{"location":"examples/renaming_files/","page":"Renaming","title":"Renaming","text":"Now that we have all of the biospecimens for ECHO, let's just get the ones that have been shotgun sequenced, and identify the SequencingPrep records associated with them.","category":"page"},{"location":"examples/renaming_files/","page":"Renaming","title":"Renaming","text":"julia> mapreduce(keys, union, biosp)\n8-element Vector{Symbol}:\n :uid\n :subject\n :collection_buffer\n :aliases\n :project\n :collection\n :visit\n :seqprep\n\njulia> filter!(rec-> haskey(rec, :seqprep), biosp);","category":"page"},{"location":"examples/renaming_files/","page":"Renaming","title":"Renaming","text":"Now, we want to build a mapping of biospecimen => seqprep ID. I'll store this as rows in a DataFrame.","category":"page"},{"location":"examples/renaming_files/","page":"Renaming","title":"Renaming","text":"julia> rndf = DataFrame(mapreduce(vcat, biosp) do rec\n    rows = [(; seqname = base[id][:uid], oldname = rec[:uid]) for id in rec[:seqprep]]\nend);","category":"page"},{"location":"examples/renaming_files/","page":"Renaming","title":"Renaming","text":"It is in principle possible for a single biospecimen ID to refer to multiple seqprep IDs. Let's check that:","category":"page"},{"location":"examples/renaming_files/","page":"Renaming","title":"Renaming","text":"julia> transform!(groupby(rndf, :oldname), \"seqname\"=> length => \"n_seqs\");\n\njulia> subset(rndf, \"n_seqs\"=> ByRow(>(1)))\n6×3 DataFrame\n Row │ seqname   oldname  n_seqs\n     │ String    String   Int64\n─────┼───────────────────────────\n   1 │ SEQ02303  FG02294       2\n   2 │ SEQ02303  FG02294       2\n   3 │ SEQ01232  FE01105       2\n   4 │ SEQ01110  FG00016       2\n   5 │ SEQ01110  FG00016       2\n   6 │ SEQ01232  FE01105       2","category":"page"},{"location":"examples/renaming_files/","page":"Renaming","title":"Renaming","text":"Now, we'll build a map of oldname -> seqname.","category":"page"},{"location":"examples/renaming_files/","page":"Renaming","title":"Renaming","text":"rnmap = dictionary(zip(rndf.oldname, rndf.seqname))\n1799-element Dictionary{String, String}\n \"FG50159\" │ \"SEQ01107\"\n \"FG50160\" │ \"SEQ01108\"\n \"FG00846\" │ \"SEQ01371\"\n #...","category":"page"},{"location":"examples/renaming_files/#Finding-files-to-rename","page":"Renaming","title":"Finding files to rename","text":"","category":"section"},{"location":"examples/renaming_files/","page":"Renaming","title":"Renaming","text":"I'm running this on hopper, so files are contained in the /grace drive, as well as some other places. But we'll start there.","category":"page"},{"location":"examples/renaming_files/","page":"Renaming","title":"Renaming","text":"The first thing to do is find all of the files that could plausibly be in ECHO. They all fit the pattern r\"F[EG]\\d{5} - that is, \"FE or \"FG\" followed by 5 numbers (\\d stands for \"digit\"). Let's make sure that's true for our rename map:","category":"page"},{"location":"examples/renaming_files/","page":"Renaming","title":"Renaming","text":"julia> all(k-> contains(k, r\"F[EG]\\d{5}\"), keys(rnmap))\ntrue","category":"page"},{"location":"examples/renaming_files/","page":"Renaming","title":"Renaming","text":"So now we'll recurse through the directory, saving any files that fit the pattern. While we're at it, we can pull out some relevant info and push it into a DataFrame.","category":"page"},{"location":"examples/renaming_files/","page":"Renaming","title":"Renaming","text":"julia> filedf = DataFrame()\n\njulia>  for (root, dir, files) in walkdir(\"/grace/sequencing/processed/mgx\")\n            for file in files\n                m = match(r\"^(F[EG]\\d{5})_(S\\d+)_\", file)\n                isnothing(m) && continue\n                newname = get(rnmap, m[1], nothing)\n                if isnothing(newname)\n                    @warn \"$(m[1]) matches the regex, but doesn't have a new name\"\n                    continue\n                end\n                push!(filedf, (;\n                    oldname = m[1], newname, snum = m[2], oldpath = joinpath(root, file), newpath = joinpath(root, replace(file, m[1]=>newname))\n                ))\n            end\n        end\n\njulia> first(filedf, 5)\n5×5 DataFrame\n Row │ oldname    newname   snum       oldpath                            newpath\n     │ SubStrin…  String    SubStrin…  String                             String\n─────┼──────────────────────────────────────────────────────────────────────────────────────────────────────\n   1 │ FE01063    SEQ02371  S93        /grace/sequencing/processed/mgx/…  /grace/sequencing/processed/mgx/…\n   2 │ FE01063    SEQ02371  S93        /grace/sequencing/processed/mgx/…  /grace/sequencing/processed/mgx/…\n   3 │ FE01063    SEQ02371  S93        /grace/sequencing/processed/mgx/…  /grace/sequencing/processed/mgx/…\n   4 │ FE01064    SEQ00905  S10        /grace/sequencing/processed/mgx/…  /grace/sequencing/processed/mgx/…\n   5 │ FE01064    SEQ00905  S10        /grace/sequencing/processed/mgx/…  /grace/sequencing/processed/mgx/…\n","category":"page"},{"location":"examples/renaming_files/","page":"Renaming","title":"Renaming","text":"Now, we want to double check that all of the oldnames are associated with the same snum to avoid ambiguities. Here, we group by oldname, and then look at the snum column to ensure there is only 1 (we check that the length of unique elements in that column is 1).","category":"page"},{"location":"examples/renaming_files/","page":"Renaming","title":"Renaming","text":"julia> transform!(groupby(filedf, :oldname), \"snum\"=> (sn-> length(unique(sn)) != 1) => \"ambiguous\");\n\njulia> unique(subset(filedf, \"ambiguous\"=> identity), [\"oldname\", \"snum\"])\n16×6 DataFrame\n Row │ oldname    newname   snum       oldpath                            newpath                            ambiguous\n     │ SubStrin…  String    SubStrin…  String                             String                             Bool\n─────┼─────────────────────────────────────────────────────────────────────────────────────────────────────────────────\n   1 │ FG00004    SEQ01071  S26        /grace/sequencing/processed/mgx/…  /grace/sequencing/processed/mgx/…       true\n   2 │ FG00004    SEQ01071  S46        /grace/sequencing/processed/mgx/…  /grace/sequencing/processed/mgx/…       true\n   3 │ FG00005    SEQ01950  S50        /grace/sequencing/processed/mgx/…  /grace/sequencing/processed/mgx/…       true\n   4 │ FG00005    SEQ01950  S58        /grace/sequencing/processed/mgx/…  /grace/sequencing/processed/mgx/…       true\n   5 │ FG00016    SEQ01110  S52        /grace/sequencing/processed/mgx/…  /grace/sequencing/processed/mgx/…       true\n   6 │ FG00016    SEQ01110  S70        /grace/sequencing/processed/mgx/…  /grace/sequencing/processed/mgx/…       true\n   7 │ FG00017    SEQ02084  S64        /grace/sequencing/processed/mgx/…  /grace/sequencing/processed/mgx/…       true\n   8 │ FG00017    SEQ02084  S82        /grace/sequencing/processed/mgx/…  /grace/sequencing/processed/mgx/…       true\n   9 │ FG00021    SEQ01862  S53        /grace/sequencing/processed/mgx/…  /grace/sequencing/processed/mgx/…       true\n  10 │ FG00021    SEQ01862  S94        /grace/sequencing/processed/mgx/…  /grace/sequencing/processed/mgx/…       true\n  11 │ FG02294    SEQ02303  S1         /grace/sequencing/processed/mgx/…  /grace/sequencing/processed/mgx/…       true\n  12 │ FG02294    SEQ02303  S34        /grace/sequencing/processed/mgx/…  /grace/sequencing/processed/mgx/…       true\n  13 │ FG02471    SEQ01727  S16        /grace/sequencing/processed/mgx/…  /grace/sequencing/processed/mgx/…       true\n  14 │ FG02471    SEQ01727  S89        /grace/sequencing/processed/mgx/…  /grace/sequencing/processed/mgx/…       true\n  15 │ FG02614    SEQ01971  S10        /grace/sequencing/processed/mgx/…  /grace/sequencing/processed/mgx/…       true\n  16 │ FG02614    SEQ01971  S9         /grace/sequencing/processed/mgx/…  /grace/sequencing/processed/mgx/…       true","category":"page"},{"location":"examples/renaming_files/","page":"Renaming","title":"Renaming","text":"So for now, we'll leave these out and deal with them later.","category":"page"},{"location":"examples/renaming_files/#Renaming","page":"Renaming","title":"Renaming","text":"","category":"section"},{"location":"examples/renaming_files/","page":"Renaming","title":"Renaming","text":"julia>  for grp in groupby(filedf, \"oldname\")\n            old = first(grp.oldname)\n            @info \"Working on $old\"\n            if any(grp.ambiguous)\n                @warn \"$old has multiple sequecing results: $(unique(grp.snum)); skipping!\"\n            else\n                @info \"Renaming $(old) to $(first(grp.newname))\"\n                for row in eachrow(grp)\n                    @debug \"$(row.oldpath) => $(row.newpath)\"\n                    mv(row.oldpath, row.newpath)\n                end\n            end\n        end","category":"page"},{"location":"examples/renaming_files/#Dealing-with-Ambiguities","page":"Renaming","title":"Dealing with Ambiguities","text":"","category":"section"},{"location":"examples/renaming_files/","page":"Renaming","title":"Renaming","text":"Let's go back to our ambiguous sequences.","category":"page"},{"location":"examples/renaming_files/","page":"Renaming","title":"Renaming","text":"julia> ambi = subset(filedf, \"ambiguous\"=> identity);\n\njulia> unique(select(ambi, [\"oldname\", \"newname\", \"snum\"]))\n16×3 DataFrame\n Row │ oldname    newname   snum\n     │ SubStrin…  String    SubStrin…\n─────┼────────────────────────────────\n   1 │ FG00004    SEQ01071  S26\n   2 │ FG00004    SEQ01071  S46\n   3 │ FG00005    SEQ01950  S50\n   4 │ FG00005    SEQ01950  S58\n   5 │ FG00016    SEQ01110  S52\n   6 │ FG00016    SEQ01110  S70\n   7 │ FG00017    SEQ02084  S64\n   8 │ FG00017    SEQ02084  S82\n   9 │ FG00021    SEQ01862  S53\n  10 │ FG00021    SEQ01862  S94\n  11 │ FG02294    SEQ02303  S1\n  12 │ FG02294    SEQ02303  S34\n  13 │ FG02471    SEQ01727  S16\n  14 │ FG02471    SEQ01727  S89\n  15 │ FG02614    SEQ01971  S10\n  16 │ FG02614    SEQ01971  S9\n","category":"page"},{"location":"examples/renaming_files/","page":"Renaming","title":"Renaming","text":"For the first 12 rows (samples FG00004, F00005, FG00016, FG00017, FG0021, and FG02294), the solution is relatively simple. Each of these had 2 aliquots of the same biospecimen sequenced. So in each of those cases, I duplicated the record in the SequencingPrep table (generating a new SEQ id), added the correct S-well number, and put in the old IDs as aliases. Eg, FG00004 is now","category":"page"},{"location":"examples/renaming_files/","page":"Renaming","title":"Renaming","text":"uid autonumber biospecimen swell alias\nSEQ01071 1071 FG00004 S26 C01174F1A\nSEQ02505 2505 FG00004 S46 C01174F1B","category":"page"},{"location":"examples/renaming_files/","page":"Renaming","title":"Renaming","text":"For FG02614, there is only a single file (FG02614_S9_pfams.tsv) that has the S9 identifier. Looking at the contents of that file:","category":"page"},{"location":"examples/renaming_files/","page":"Renaming","title":"Renaming","text":"❯ head mgx/humann/regroup/FG02614_S9_pfams.tsv\n# Gene Family   FG02610_S9_Abundance-RPKs\nUNMAPPED        14128546.0\nUNGROUPED       29634105.328100212\nUNGROUPED|g__Adlercreutzia.s__Adlercreutzia_equolifaciens       17608.29535663359\nUNGROUPED|g__Agathobaculum.s__Agathobaculum_butyriciproducens   44303.814025389926\nUNGROUPED|g__Akkermansia.s__Akkermansia_muciniphila     118128.883395747\nUNGROUPED|g__Alistipes.s__Alistipes_finegoldii  125084.06209765507\nUNGROUPED|g__Alistipes.s__Alistipes_indistinctus        24720.017810163998\nUNGROUPED|g__Alistipes.s__Alistipes_putredinis  1052709.4440796026\nUNGROUPED|g__Alistipes.s__Alistipes_shahii      86567.54527132263","category":"page"},{"location":"examples/renaming_files/","page":"Renaming","title":"Renaming","text":"Based on the header, it looks like it belongs to FG02610. We have all of the files for FG02610, so I'm just going to delete these files (the FG02614_S9 ones).","category":"page"},{"location":"examples/renaming_files/","page":"Renaming","title":"Renaming","text":"FG02471 is weirder. We have all of the relevant files for both S16 and S89. Looking at the contents, ","category":"page"},{"location":"examples/renaming_files/","page":"Renaming","title":"Renaming","text":"kevin in vkclab-ada in /lovelace/sequencing/processed on ☁️  (us-east-1)\n❯ head -5 mgx/metaphlan/FG02471_S*_profile.tsv\n==> mgx/metaphlan/FG02471_S16_profile.tsv <==\n#mpa_v30_CHOCOPhlAn_201901\n#/home/vklepacc/miniconda3/envs/biobakery3/bin/metaphlan output/kneaddata/FG02471_S16_kneaddata.fastq output/metaphlan/FG02471_S16_profile.tsv --bowtie2out output/metaphlan/FG02471_S16_bowtie2.tsv --samout output/metaphlan/FG02471_S16.sam --input_type fastq --nproc 8 --bowtie2db /pool001/vklepacc/databases/metaphlan\n#SampleID       Metaphlan_Analysis\n#clade_name     NCBI_tax_id     relative_abundance      additional_species\nk__Bacteria     2       99.08787\n\n==> mgx/metaphlan/FG02471_S89_profile.tsv <==\n#mpa_v30_CHOCOPhlAn_201901\n#/home/vklepacc/miniconda3/envs/biobakery3/bin/metaphlan output/kneaddata/C0477-5F-1A_S89_merged.fastq output/metaphlan/C0477-5F-1A_S89_profile.tsv --bowtie2out output/metaphlan/C0477-5F-1A_S89_bowtie2.tsv --samout output/metaphlan/C0477-5F-1A_S89.sam --input_type fastq --nproc 8\n#SampleID       Metaphlan_Analysis\n#clade_name     NCBI_tax_id     relative_abundance      additional_species\nk__Bacteria     2       99.12309\n\nkevin in vkclab-ada in /lovelace/sequencing/processed on ☁️  (us-east-1)\n❯ head -5 mgx/humann/main/FG02471_*genefamilies.tsv\n==> mgx/humann/main/FG02471_S16_genefamilies.tsv <==\n# Gene Family   FG02471_S16_Abundance-RPKs\nUNMAPPED        4356120.0000000000\nUniRef90_A0A3E2XRX6     15802.1208367696\nUniRef90_A0A3E2XRX6|g__Dorea.s__Dorea_longicatena       15802.1208367696\nUniRef90_A5ZYV3 12866.1165754399\n\n==> mgx/humann/main/FG02471_S89_genefamilies.tsv <==\n# Gene Family   C0477-5F-1A_S89_Abundance-RPKs\nUNMAPPED        3152316.0000000000\nUniRef90_A7V4G2 8649.8613270401\nUniRef90_A7V4G2|g__Bacteroides.s__Bacteroides_uniformis 8552.3697112122\nUniRef90_A7V4G2|unclassified    97.4916158279","category":"page"},{"location":"examples/renaming_files/","page":"Renaming","title":"Renaming","text":"The S89 has the old ID in the header (C0477-5F-1A), which is the correct one according to the old database, but it looks like this same ID was sequenced in a different batch (old batch 11) under the ID FG00757. Given the surrounding S-well IDs, it looks like S16, sequenced in (old) batch 17 is correctly attributed to FG02471 (which will become SEQ01727), while S89 should go with FG00757 (which becomes SEQ02512). ","category":"page"},{"location":"examples/renaming_files/#Conclusion","page":"Renaming","title":"Conclusion","text":"","category":"section"},{"location":"examples/renaming_files/","page":"Renaming","title":"Renaming","text":"This example shows how to download and access the local airtable base, use it to generate a rename mapping, and use that to rename files, taking into account ambiguities.","category":"page"},{"location":"","page":"Home","title":"Home","text":"CurrentModule = VKCComputing","category":"page"},{"location":"#VKCComputing.jl","page":"Home","title":"VKCComputing.jl","text":"","category":"section"},{"location":"","page":"Home","title":"Home","text":"Documentation for VKCComputing.","category":"page"},{"location":"","page":"Home","title":"Home","text":"","category":"page"},{"location":"#Setup-environment","page":"Home","title":"Setup environment","text":"","category":"section"},{"location":"","page":"Home","title":"Home","text":"set_default_preferences!\nset_airtable_dir!\nset_readonly_pat!\nset_readwrite_pat!","category":"page"},{"location":"#VKCComputing.set_default_preferences!","page":"Home","title":"VKCComputing.set_default_preferences!","text":"TODO:\n\nset airtable dir using call to scratch drivbe with user name\nthrow warnings if any of the directories don't exist\n\n\n\n\n\n","category":"function"},{"location":"#VKCComputing.set_airtable_dir!","page":"Home","title":"VKCComputing.set_airtable_dir!","text":"set_airtable_dir!(key)\n\nSets local preferences for airtable_dir to key (defaults to the environmental variable \"AIRTABLE_DIR\" if set).\n\n\n\n\n\n","category":"function"},{"location":"#VKCComputing.set_readonly_pat!","page":"Home","title":"VKCComputing.set_readonly_pat!","text":"set_readonly_pat!(key)\n\nSets local preferences for readonly_pat to key (defaults to the environmental variable \"AIRTABLE_KEY\" if set).\n\n\n\n\n\n","category":"function"},{"location":"#VKCComputing.set_readwrite_pat!","page":"Home","title":"VKCComputing.set_readwrite_pat!","text":"set_readwrite_pat!(key)\n\nSets local preferences for readwrite_pat to key (defaults to the environmental variable \"AIRTABLE_RW_KEY\" if set).\n\n\n\n\n\n","category":"function"},{"location":"#Interacting-with-Airtable","page":"Home","title":"Interacting with Airtable","text":"","category":"section"},{"location":"","page":"Home","title":"Home","text":"VKCAirtable\nLocalAirtable\nLocalBase\nvkcairtable\nlocalairtable\nuids","category":"page"},{"location":"#VKCComputing.VKCAirtable","page":"Home","title":"VKCComputing.VKCAirtable","text":"VKCAirtable(base, name, localpath)\n\nConnecting Airtable tables with local instances. Generally, use vkcairtable to create.\n\n\n\n\n\n","category":"type"},{"location":"#VKCComputing.LocalAirtable","page":"Home","title":"VKCComputing.LocalAirtable","text":"LocalAirtable(table, data, uididx)\n\nPrimary data structure for interacting with airtable-based data.\n\n\n\n\n\n","category":"type"},{"location":"#VKCComputing.LocalBase","page":"Home","title":"VKCComputing.LocalBase","text":"LocalBase(; update=Month(1))\n\nLoad the airtable sample database into memory. Requires that an airtable key with read access and a directory for storing local files are set to preferences. (see set_readonly_pat! and set_airtable_dir!.\n\nUpdating local base files\n\nThe update keyword argument can take a number of different forms.\n\nA boolean value, which will cause updates to all tables if true, and no tables if false.\nAn AbstractTime from Dates (eg Week(1)), which will update any table whose local copy was last updated longer ago than this value.\nA vector of Pairs of the form \"$table_name\"=> x, where x is either of the options from (1) or (2) above.\n\nFor example, to update the \"Biospecimens\" table if it's older than a week, and to update the \"Projects\" table no matter what, call\n\njulia> using VKCComputing, Dates\n\njulia> base = LocalBase(; update=[\"Biospecimens\"=> Week(1), \"Projects\"=> true]);\n\nIndexing\n\nIndexing into the local base can be done either with the name of a table (eg base[\"Biospecimens\"]), which will return a VKCAirtable, or using a record ID hash (eg base[\"recUqEcu3pM8p2jzQ\"]). \n\nwarning: Warning\nNote that record ID hashes are identified based on the regular expression r\"^rec[A-Za-z0-9]{14}$\" - that is, a string starting with \"rec\", followed by exactly 14 alphanumeric characters. In principle, one could name a table as something that matches this regular expression, causing it to be improperly identified as a record hash rather than a table name.\n\nVCKAirtables can also be indexed with the uid column string, so an individual record can be accessed using eg base[\"Projects\"][\"khula\"], but a 2-argument indexing option is provided for convenience, eg base[\"Projects\", \"khula\"].\n\n\n\n\n\n","category":"type"},{"location":"#VKCComputing.vkcairtable","page":"Home","title":"VKCComputing.vkcairtable","text":"vkcairtable(name::String)\n\nReturns a VKCAirtable type based on the table name. Requires that the local preference airtable_dir is set. See VKCComputing.set_preferences!.\n\n\n\n\n\n","category":"function"},{"location":"#VKCComputing.localairtable","page":"Home","title":"VKCComputing.localairtable","text":"localairtable(tab::VKCAirtable; update=Month(1))\n\nCreate an instance of LocalAirtable, optionally updating the local copy from remote.\n\n\n\n\n\n","category":"function"},{"location":"#VKCComputing.uids","page":"Home","title":"VKCComputing.uids","text":"uids(tab::LocalAirtable)\n\nGet the keys for the uid column of table tab.\n\n\n\n\n\nuids(base::LocalBase, tab::String)\n\nGet the keys for the uid column of table tab from base.\n\n\n\n\n\n","category":"function"},{"location":"#Interacting-with-records","page":"Home","title":"Interacting with records","text":"","category":"section"},{"location":"","page":"Home","title":"Home","text":"resolve_links\nbiospecimens\nseqpreps\nsubjects","category":"page"},{"location":"#VKCComputing.resolve_links","page":"Home","title":"VKCComputing.resolve_links","text":"resolve_links(base::LocalBase, col; strict = true, unpack = r-> r isa AbstractString ? identity : first)\n\nResolves a vector of record hashes (or a vector of vectors of record hashes) into the uids of the linked record.\n\nIf the strict kwarg is true, it is expected that col is composed of either\n\na record hash\na one-element Vector containing a record hash\n\nIf strict is false, it is recommended to pass a custom function to unpack, which will be called on each row of the col.\n\nEg.\n\njulia> base = LocalBase();\n\njulia> visits = [rec[:visit] for rec in base[\"Biospecimens\"][[\"FG00004\", \"FG00006\", \"FG00008\"]]]\n3-element Vector{JSON3.Array{String, Base.CodeUnits{UInt8, String}, SubArray{UInt64, 1, Vector{UInt64}, Tuple{UnitRange{Int64}}, true}}}:\n [\"recEnxbSPMNZaoySF\"]\n [\"recT1EUtiUSZaypxl\"]\n [\"recyHSMZp0HLErHLz\"]\n\n julia> resolve_links(base, visits)\n 3-element Vector{Airtable.AirRecord}:\n  Airtable.AirRecord(\"recEnxbSPMNZaoySF\", AirTable(\"Visits\"), (uid = \"mc03\", Biospecimens = [\"recdO7nHQI7VY5ynn\", #...\n  Airtable.AirRecord(\"recT1EUtiUSZaypxl\", AirTable(\"Visits\"), (uid = \"ec02\", Biospecimens = [\"recmuwWA1bkhpxQ4P\", #...\n  Airtable.AirRecord(\"recyHSMZp0HLErHLz\", AirTable(\"Visits\"), (uid = \"mc05\", Biospecimens = [\"recOlXNl7OMQH6cpF\", #...\n\njulia> julia> seqpreps =  [rec[:seqprep] for rec in base[\"Biospecimens\"][[\"FG00004\", \"FG00006\", \"FG00008\"]]]\n3-element Vector{JSON3.Array{String, Base.CodeUnits{UInt8, String}, SubArray{UInt64, 1, Vector{UInt64}, Tuple{UnitRange{Int64}}, true}}}:\n [\"rec33GrUTnfeNTCXe\", \"recBh1xD1xOw4qkhO\"]\n [\"recq5fj9BQb7vugUd\"]\n [\"recbNNM1qWXOLhnye\"]\n\nNotice that the first record here has 2 entries, so strict=true will fail.\n\njulia> resolve_links(base, seqpreps)\nERROR: ArgumentError: At least one record has multiple entries. Use `strict = false` and `unpack` to handle this.\nStacktrace:\n#...\n\nIf you just pass strict = false, the default unpack function will simply take the first record:\n\njulia> resolve_links(base, seqpreps; strict = false)\n3-element Vector{Airtable.AirRecord}:\n Airtable.AirRecord(\"rec33GrUTnfeNTCXe\", AirTable(\"SequencingPrep\"), (uid = \"SEQ01071\", biospecimen = [\"recDcm98dkmNP3Zic\"] #...\n Airtable.AirRecord(\"recq5fj9BQb7vugUd\", AirTable(\"SequencingPrep\"), (uid = \"SEQ00729\", biospecimen = [\"recL6D53j76R0eRp5\"] #...\n Airtable.AirRecord(\"recbNNM1qWXOLhnye\", AirTable(\"SequencingPrep\"), (uid = \"SEQ01960\", biospecimen = [\"rech7m4F33iGWtgOU\"] #...\n\nIf you wish to keep all records, use Iterators.flatten(), or pass a custom unpack function:\n\njulia> resolve_links(base, Iterators.flatten(seqpreps); strict = false)\n4-element Vector{Airtable.AirRecord}:\n Airtable.AirRecord(\"rec33GrUTnfeNTCXe\", AirTable(\"SequencingPrep\"), (uid = \"SEQ01071\", biospecimen = [\"recDcm98dkmNP3Zic\"] #...\n Airtable.AirRecord(\"recBh1xD1xOw4qkhO\", AirTable(\"SequencingPrep\"), (uid = \"SEQ02505\", biospecimen = [\"recDcm98dkmNP3Zic\"] #...\n Airtable.AirRecord(\"recq5fj9BQb7vugUd\", AirTable(\"SequencingPrep\"), (uid = \"SEQ00729\", biospecimen = [\"recL6D53j76R0eRp5\"] #...\n Airtable.AirRecord(\"recbNNM1qWXOLhnye\", AirTable(\"SequencingPrep\"), (uid = \"SEQ01960\", biospecimen = [\"rech7m4F33iGWtgOU\"] #...\n\njulia> resolve_links(base, seqpreps; strict = false, unpack = identity)\n3-element Vector{Vector{Airtable.AirRecord}}:\n [Airtable.AirRecord(\"rec33GrUTnfeNTCXe\", AirTable(\"SequencingPrep\"), (uid = \"SEQ01071\", biospecimen = [\"recDcm98dkmNP3Zic\"] #...\n  Airtable.AirRecord(\"recBh1xD1xOw4qkhO\", AirTable(\"SequencingPrep\"), (uid = \"SEQ02505\", biospecimen = [\"recDcm98dkmNP3Zic\"] #...\n ]\n [Airtable.AirRecord(\"recq5fj9BQb7vugUd\", AirTable(\"SequencingPrep\"), (uid = \"SEQ00729\", biospecimen = [\"recL6D53j76R0eRp5\"] #...\n [Airtable.AirRecord(\"recbNNM1qWXOLhnye\", AirTable(\"SequencingPrep\"), (uid = \"SEQ01960\", biospecimen = [\"rech7m4F33iGWtgOU\"] #...\n\n\n\n\n\n","category":"function"},{"location":"#VKCComputing.biospecimens","page":"Home","title":"VKCComputing.biospecimens","text":"biospecimens([base::LocalBase, ]project; strict=true)\n\nGet all records from the table Biospecimens belonging to project.\n\nNOTE: strict is set to false by default, and will exclude any records where keep != 1.\n\n\n\n\n\n","category":"function"},{"location":"#VKCComputing.seqpreps","page":"Home","title":"VKCComputing.seqpreps","text":"seqpreps([base::LocalBase, ]project; strict=true)\n\nGet all records from the table SequencingPrep belonging to project.\n\nNOTE: strict is set to false by default, and will exclude any records where keep != 1.\n\n\n\n\n\n","category":"function"},{"location":"#VKCComputing.subjects","page":"Home","title":"VKCComputing.subjects","text":"subjects([base::LocalBase, ]project; strict=true)\n\nGet all records from the table Subjects belonging to project.\n\nNOTE: strict is set to false by default, and will exclude any records where keep != 1.\n\n\n\n\n\n","category":"function"},{"location":"#Interacting-with-files","page":"Home","title":"Interacting with files","text":"","category":"section"},{"location":"","page":"Home","title":"Home","text":"get_analysis_files\naudit_analysis_files\naudit_tools","category":"page"},{"location":"#VKCComputing.get_analysis_files","page":"Home","title":"VKCComputing.get_analysis_files","text":"get_analysis_files(dir = @load_preference(\"mgx_analysis_dir\"))\n\nExpects the preference mgx_analysis_dir to be set - see set_default_preferences!.\n\nCreates DataFrame  with the following headers:\n\nmod: DateTime that the file was last modified\nsize: (Int) in bytes\npath: full remote path (eg /grace/sequencing/processed/mgx/metaphlan/SEQ9999_S42_profile.tsv)\ndir: Remote directory for file (eg /grace/sequencing/processed/mgx/metaphlan/), equivalent to dirname(path)\nfile: Remote file name (eg SEQ9999_S42_profile.tsv)\nseqprep: For files that match SEQ\\d+_S\\d+_.+, the sequencing Prep ID (eg SEQ9999). Otherwise, missing.\nS_well: For files that match SEQ\\d+_S\\d+_.+, the well ID, including S (eg S42). Otherwise, missing.\nsuffix: For files that match SEQ\\d+_S\\d+_.+, the remainder of the file name, aside from a leading _ (eg profile.tsv). Otherwise, missing.\n\nSee also aws_ls\n\n\n\n\n\n","category":"function"},{"location":"#VKCComputing.audit_analysis_files","page":"Home","title":"VKCComputing.audit_analysis_files","text":"audit_analysis_files(analysis_files; base = LocalBase())\n\nWIP\n\n\n\n\n\n","category":"function"},{"location":"#VKCComputing.audit_tools","page":"Home","title":"VKCComputing.audit_tools","text":"audit_tools(df::DataFrame; group_col=\"seqprep\")\n\nWIP\n\n\n\n\n\n","category":"function"},{"location":"#Interacting-with-AWS","page":"Home","title":"Interacting with AWS","text":"","category":"section"},{"location":"","page":"Home","title":"Home","text":"aws_ls","category":"page"},{"location":"#VKCComputing.aws_ls","page":"Home","title":"VKCComputing.aws_ls","text":"aws_ls(path=\"s3://vkc-sequencing/processed/mgx/\")\n\nGet a (recurssive) listing of files / dicrectories contained at path,  and return a DataFrame with the following headers:\n\nmod: DateTime that the file was last modified\nsize: (Int) in bytes\npath: full remote path (eg s3://bucket-name/some/SEQ9999_S42_profile.tsv)\ndir: Remote directory for file (eg s3://bucket-name/some/), equivalent to dirname(path)\nfile: Remote file name (eg SEQ9999_S42_profile.tsv)\nseqprep: For files that match SEQ\\d+_S\\d+_.+, the sequencing Prep ID (eg SEQ9999). Otherwise, missing.\nS_well: For files that match SEQ\\d+_S\\d+_.+, the well ID, including S (eg S42). Otherwise, missing.\nsuffix: For files that match SEQ\\d+_S\\d+_.+, the remainder of the file name, aside from a leading _ (eg profile.tsv). Otherwise, missing.\n\n\n\n\n\n","category":"function"}]
}