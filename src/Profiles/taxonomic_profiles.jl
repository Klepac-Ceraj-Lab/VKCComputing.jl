function load_raw_metaphlan(manual_path::Union{Nothing, String}=nothing; replace_pattern = r"FG\d+_S\d+_profile", cleanup_pattern = "_profile.tsv")

    if isnothing(manual_path)
        df = DataFrame(file = filter(f-> contains(f, replace_pattern), readdir(analysisfiles("metaphlan"), join=true)))
    else
        df = DataFrame(file = filter(f-> contains(f, replace_pattern), readdir(manual_path, join=true)))
    end

    df.sample = map(s-> replace(s, cleanup_pattern => ""), basename.(df.file))
    df.sample_base = map(s-> replace(s, r"_S\d+"=>""), df.sample)

    #knead = load(ReadCounts())
    taxa = metaphlan_profiles(df.file; samples = df.sample)
    set!(taxa, df)
    #set!(taxa, select(knead, "sample_uid"=>"sample", AsTable(["final pair1", "final pair2"])=> ByRow(row-> row[1]+row[2]) =>"read_depth"))
    taxa
end



function load_custom_unirefs(::UnirefProfiles, timepoint_metadata::DataFrame; custom_arrow_path = "data/genefamilies_HM36_stratified.arrow")
    comm = Leap.read_gfs_arrow(; arrow_path = custom_arrow_path)
    insert!(comm, timepoint_metadata; namecol=:sample)

    valid_samples = intersect(name.(comm.samples), timepoint_metadata.sample)
    comm = comm[:, valid_samples]

    if isempty(comm.samples)
        @warn "No overlapping samples between profile and metadata!"
    end

    return comm
end




function load_taxonomic_profiles(cfg::LeapConfig)
    @chain VKCComputing.Leap.load_raw_metaphlan(
        cfg.metaphlan_dir;
        replace_pattern = cfg.metaphlan_replace_pattern,
        cleanup_pattern = cfg.metaphlan_cleanup_pattern
    ) begin
        filter(t -> !ismissing(taxrank(t)), _[:, samplenames(_)])
        filter(t -> taxrank(t) == :species, _[:, samplenames(_)])
        comm2wide()
        select(Not([:sample, :file]))
        filter_prevalence(cfg.prevalence_threshold)
    end
end