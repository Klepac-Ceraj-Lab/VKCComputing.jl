function get_analysis_files(dir = @load_preference("mgx_analysis_dir"))
    analysis_files = DataFrame(file   = String[],
                           dir    = String[],
                           sample = Union{Missing, String}[],
                           s_well = Union{Missing, String}[],
                           suffix = Union{Missing, String}[]
    )

    for (root, dirs, files) in walkdir(dir)
        for f in files
            m = match(r"^([\w\-]+)_(S\d+)_?(.+)", basename(f))
            if isnothing(m)
                push!(analysis_files, (; file = basename(f), dir = root, sample = missing, s_well = missing, suffix = missing))
            else
                push!(analysis_files, (; file = basename(f), dir = root, sample = m[1], s_well = m[2], suffix = m[3]))
            end
        end
    end
    return analysis_files
end

function audit_analysis_files(analysis_files)

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
    
    return samples
end