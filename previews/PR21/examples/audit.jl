using VKCComputing
using Chain
using DataFrames
using Airtable
using Preferences

key = Airtable.Credential(load_preference(VKCComputing, "readwrite_pat"))
remote = AirBase("appmYwoXIHlen5s0q")
base = LocalBase(; update=true)
analysis_files = get_analysis_files()

#-

samples = @chain analysis_files begin
    groupby("sample", )
    transform("s_well" => (s-> length(unique(s)) != 1) => "s_well_ambiguity"; ungroup=false)
    @aside any(combine(_, "s_well_ambiguity" => any => "s").s) && throw(ArgumentError("Some files had ambiguous wells"))
    combine(
        "s_well"=> (s-> first(s)) => "s_well",
        "suffix"=> (suffix-> "kneaddata.log" in suffix)     => "kneaddata_complete",
        "suffix"=> (suffix-> "profile.tsv" in suffix)       => "has_taxprofile",
        "suffix"=> (suffix-> "bowtie2.tsv" in suffix)       => "has_bowtie2",
        "suffix"=> (suffix-> ".sam.bz2" in suffix)          => "has_sam",
        "suffix"=> (suffix-> "genefamilies.tsv" in suffix)  => "has_genefamilies",
        "suffix"=> (suffix-> "pathabundance.tsv" in suffix) => "has_pathabundance",
        "suffix"=> (suffix-> "pathcoverage.tsv" in suffix)  => "has_pathcoverage",
        "suffix"=> (suffix-> "ecs.tsv" in suffix)           => "has_ecs",
        "suffix"=> (suffix-> "kos.tsv" in suffix)           => "has_kos",
        "suffix"=> (suffix-> "pfams.tsv" in suffix)         => "has_pfams",
        "suffix"=> (suffix-> "ecs_rename.tsv" in suffix)    => "has_ecs_rename",
        "suffix"=> (suffix-> "kos_rename.tsv" in suffix)    => "has_kos_rename",
        "suffix"=> (suffix-> "pfams_rename.tsv" in suffix)  => "has_pfams_rename",
    )
    transform!(
    AsTable([
        "has_taxprofile",
        "has_bowtie2",
        "has_sam",
    ]) => ByRow(all) => "metaphlan_complete")

    transform!(
        AsTable([
            "has_genefamilies", 
            "has_pathabundance", 
            "has_pathcoverage", 
        ]) => ByRow(all) => "humann_basic_complete"
    )

    transform!( 
        AsTable([
            "has_ecs", 
            "has_kos", 
            "has_pfams", 
            "has_ecs_rename", 
            "has_kos_rename", 
            "has_pfams_rename"
        ]) => ByRow(all) => "humann_complete"
    )
end


count(!, samples.kneaddata_complete)
count(!, samples.metaphlan_complete)
count(!, samples.humann_complete)

#-

patches = DataFrame()


for row in eachrow(samples)
    sample = row.sample
    seqrec = get(base["SequencingPrep"], sample, missing)
    if ismissing(seqrec)
        @warn "$sample does not have an entry in $SequencingPrep"
        continue
    end
    
    S_well = get(seqrec, :S_well, missing)
    if ismissing(S_well)
        @info "$sample had no recorded S_well, using one from file"
        S_well = row.s_well
    end

    if S_well != row.s_well
        @warn "local copy of $sample has s_well `$(row.s_well)`, remote has $S_well"
        continue
    end

    remote_kneaddata = get(seqrec, :kneaddata, false)
    remote_metaphlan = get(seqrec, :metaphlan, false)
    remote_humann = get(seqrec, :humann, false)

    if remote_kneaddata ⊻ row.kneaddata_complete
        @warn "Local and remote disagree on completion of KneadData for $sample, local: $(row.kneaddata_complete), remote: $remote_kneaddata"
        !remote_kneaddata && push!(patches, (; seqrec, kneaddata = true, S_well); cols=:union)
    end
    if remote_metaphlan ⊻ row.metaphlan_complete
        @warn "Local and remote disagree on completion of MetaPhlAn for $sample, local: $(row.metaphlan_complete), remote: $remote_metaphlan"
        !remote_metaphlan && push!(patches, (; seqrec, metaphlan = true, S_well); cols=:union)    
    end
    if remote_humann ⊻ row.humann_complete
        @warn "Local and remote disagree on completion of HUMAnN for $sample, local: $(row.humann_complete), remote: $remote_humann"
        !remote_humann && push!(patches, (; seqrec, humann = true, S_well); cols=:union)
    end

end

#-

patches = @chain patches begin
    transform(:seqrec => ByRow(s-> s.id) => "hashid")
    groupby(:hashid)
    combine("seqrec"    => first => "seqrec",
            "S_well"    => first => "S_well",
            "kneaddata" => (col -> coalesce(col...)) => "kneaddata",
            "metaphlan" => (col -> coalesce(col...)) => "metaphlan",
            "humann"    => (col -> coalesce(col...)) => "humann"
    )
end

for row in eachrow(patches)
    rec = row.seqrec
    tools = NamedTuple(row[Not("seqrec")])
    Airtable.patch!(key, rec, tools)
end