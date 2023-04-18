function load_raw_metaphlan(project::String; update_metadata=false)
    if update_metadata
        @info "Updating local copies of metadata files"
        force = true
    else
        @info "Using local copies of metadata files"
        force = false
    end

    project = nested_metadata(project; force)

    df.sample = map(s-> replace(s, "_profile.tsv"=> ""), basename.(df.file))
    df.sample_base = map(s-> replace(s, r"_S\d+"=>""), df.sample)

    knead = load(ReadCounts())
    taxa = metaphlan_profiles(df.file; samples = df.sample)
    set!(taxa, df)
    set!(taxa, select(knead, "sample_uid"=>"sample", AsTable(["final pair1", "final pair2"])=> ByRow(row-> row[1]+row[2]) =>"read_depth"))
    taxa
end

