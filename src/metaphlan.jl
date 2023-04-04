function load_raw_metaphlan()
    df = DataFrame(file = filter(f-> contains(f, r"FG\d+_S\d+_profile"), readdir(analysisfiles("metaphlan"), join=true)))
    df.sample = map(s-> replace(s, "_profile.tsv"=> ""), basename.(df.file))
    df.sample_base = map(s-> replace(s, r"_S\d+"=>""), df.sample)

    knead = load(ReadCounts())
    taxa = metaphlan_profiles(df.file; samples = df.sample)
    set!(taxa, df)
    set!(taxa, select(knead, "sample_uid"=>"sample", AsTable(["final pair1", "final pair2"])=> ByRow(row-> row[1]+row[2]) =>"read_depth"))
    taxa
end

