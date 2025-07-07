function run_knead(
    sample,
    rawfastq_dir,
    knead_dir;
    hg_db_dir = "/Databases/kneaddata/hg37dec_v0.1",
    kd_execline = `docker run -it --user=1015 -v /Processing:/Processing -v /Databases:/Databases -v /vassar:/vassar -v /murray:/murray --rm ghcr.io/klepac-ceraj-lab/kneaddata-012:latest kneaddata`,
    )
    files = filter(f-> contains(basename(f), sample), readdir(rawfastq_dir; join = true))
    length(files) != 2 && throw(ArgumentError("incorrect number of samples matching $sample"))
    isdir(knead_dir) || mkpath(knead_dir)
    if isfile(joinpath(knead_dir, "$(sample)_kneaddata.log")) 
        @info "Kneaddata log file found for $sample, skipping"
        return nothing
    end

    run(
        `$kd_execline \
        --input1 $(files[1]) \
        --input2 $(files[2]) \
        --reference-db $(hg_db_dir) \
        --output $(knead_dir) \
        --threads 20 \
        --processes 2 \
        --output-prefix $(sample)_kneaddata \
        --trimmomatic /opt/conda/bin`
    )

    rm_files_bowtie2 = filter(f-> ( contains(f, sample) & contains(f, "bowtie2") ), readdir(knead_dir; join = true))
    rm_files_trimmed = filter(f-> ( contains(f, sample) & contains(f, "trimmed") ), readdir(knead_dir; join = true))
    rm_files_repeats = filter(f-> ( contains(f, sample) & contains(f, "repeats") ), readdir(knead_dir; join = true))
    
    @show rm_files = vcat(rm_files_bowtie2, rm_files_trimmed, rm_files_repeats)
    
    (length(rm_files) > 0) ? map(rm, rm_files) : println("No files to remove!")

    for f in filter(f-> contains(basename(f), Regex(string(sample, ".+", "fastq"))), readdir(knead_dir; join=true))
        run(`gzip $f`)
    end
end

function cat_kneads(sample, knead_dir, metaphlan_dir)
    infiles = filter(
        f -> contains(basename(f), sample) && any(p-> contains(basename(f), p), (r"paired_[12]", r"unmatched_[12]")),
        readdir(abspath(knead_dir); join=true)
    )
    isdir(metaphlan_dir) || mkpath(metaphlan_dir)
    catfile = joinpath(metaphlan_dir, "$sample.joined.fastq.gz")
    if isfile(catfile)
        @info "Cat kneads file found for $sample, skipping"
        return catfile
    end
    @info "writing combined file to $catfile"
    run(pipeline(`cat $infiles`; stdout=catfile))
    return catfile
end

function run_metaphlan(
    sample, 
    catfile,
    metaphlan_dir;
    mp_execline = `docker run -it --user=1015 -v /Processing:/Processing -v /Databases:/Databases -v /vassar:/vassar -v /murray:/murray --rm ghcr.io/klepac-ceraj-lab/metaphlan-4:latest metaphlan`,
    db_dir = "/Databases/metaphlan4/mpa_vOct22_default",
    db_prefix = "mpa_vOct22_CHOCOPhlAnSGB_202403"
    )
    
    metaphlan_dboutput_dir = abspath(metaphlan_dir, db_prefix)
    isdir(metaphlan_dboutput_dir) || mkpath(metaphlan_dboutput_dir)

    if ( isfile(joinpath(metaphlan_dboutput_dir, "$(sample)_$(db_prefix)_RELAB_profile.tsv")) & isfile(joinpath(metaphlan_dboutput_dir, "$(sample)_$(db_prefix)_bowtie2.tsv")) )
        @info "MP RELAB profile and MAPOUT files found for $sample, DB $db_prefix. Skipping initial run..."
    else
        @info "$(Dates.now()) - Start of MetaPhlAn run with database $(db_prefix) and mode RELAB"
        run(`$mp_execline \
            $catfile \
            -o $(joinpath(metaphlan_dboutput_dir, "$(sample)_$(db_prefix)_RELAB_profile.tsv")) \
            --mapout $(joinpath(metaphlan_dboutput_dir, "$(sample)_$(db_prefix)_bowtie2.tsv")) \
            --samout $(joinpath(metaphlan_dboutput_dir, "$(sample)_$(db_prefix).sam")) \
            --input_type fastq \
            --nproc 40 \
            --db_dir $(db_dir) \
            -x $(db_prefix)` 
        )
        @info "$(Dates.now()) - End of MetaPhlAn run with database $(db_prefix) and mode RELAB"
    end

    if ( isfile(joinpath(metaphlan_dboutput_dir, "$(sample)_$(db_prefix)_STATS_profile.tsv")) )
        @info "MP STATS profile found for $sample, DB $db_prefix. Skipping followup run..."
    else    
        @info "$(Dates.now()) - Start of MetaPhlAn run with database $(db_prefix) and mode STATS"
        run(`$mp_execline \
            $(joinpath(metaphlan_dboutput_dir, "$(sample)_$(db_prefix)_bowtie2.tsv")) \
            -o $(joinpath(metaphlan_dboutput_dir, "$(sample)_$(db_prefix)_STATS_profile.tsv")) \
            --input_type mapout \
            --nproc 40 \
            --db_dir $(db_dir) \
            -x $(db_prefix) \
            -t rel_ab_w_read_stats` 
        )
        @info "$(Dates.now()) - End of MetaPhlAn run with database $(db_prefix) and mode STATS"
    end

    isfile(joinpath(metaphlan_dboutput_dir, "$(sample)_$(db_prefix).sam")) && run(`bzip2 $(joinpath(metaphlan_dboutput_dir, "$(sample)_$(db_prefix).sam"))`)

    return (
        joinpath(metaphlan_dboutput_dir, "$(sample)_$(db_prefix)_RELAB_profile.tsv"),
        joinpath(metaphlan_dboutput_dir, "$(sample)_$(db_prefix)_STATS_profile.tsv")
    )

end

function run_humann_main(
    sample, 
    catfile,
    mp_profile,
    humann_dir;
    hm_vertag = "HM40",
    hm_execline = `docker run -it --user=1015 -v /Processing:/Processing -v /Databases:/Databases -v /vassar:/vassar -v /murray:/murray --rm ghcr.io/klepac-ceraj-lab/humann-4:latest humann`,
    choco_db_dir = "/Databases/humann4/chocophlan",
    prot_db_dir = "/Databases/humann4/uniref90_annotated",
    util_db_dir = "/Databases/humann4/full_mapping"
    )

    isdir(joinpath(humann_dir, "main")) || mkpath(joinpath(humann_dir, "main"))
    isdir(joinpath(humann_dir, "regroup")) || mkpath(joinpath(humann_dir, "regroup"))
    isdir(joinpath(humann_dir, "rename")) || mkpath(joinpath(humann_dir, "rename"))

    if isfile(joinpath(humann_dir, "main", "$(sample)_$(hm_vertag)_2_genefamilies.tsv")) 
        @info "Genefamilies file found for $sample, skipping"
    else
        run(
            `$hm_execline \
            --input $catfile \
            --taxonomic-profile $mp_profile \
            --output $(joinpath(humann_dir, "main")) \
            --remove-temp-output \
            --nucleotide-database $(choco_db_dir) \
            --protein-database $(prot_db_dir) \
            --utility-database $(util_db_dir) \
            --output-basename $(sample)_$(hm_vertag) \
            --threads 20`
        )
                    # --search-mode uniref90 \
    end

    rm(catfile)

    return(joinpath(humann_dir, "main", "$(sample)_$(hm_vertag)_2_genefamilies.tsv"))

end

function run_humann_regroup_rename(
    sample, 
    hm_mainout,
    humann_dir;
    hm_vertag = "HM40",
    hm_regroup_execline = `docker run -it --user=1015 -v /Processing:/Processing -v /Databases:/Databases -v /vassar:/vassar -v /murray:/murray --rm ghcr.io/klepac-ceraj-lab/humann-4:latest humann_regroup_table`,
    hm_rename_execline = `docker run -it --user=1015 -v /Processing:/Processing -v /Databases:/Databases -v /vassar:/vassar -v /murray:/murray --rm ghcr.io/klepac-ceraj-lab/humann-4:latest humann_rename_table`,
    util_db_dir = "/Databases/humann4/full_mapping"
    )

    regroup_humann_dir = joinpath(humann_dir, "regroup")
    rename_humann_dir = joinpath(humann_dir, "rename")

    isdir(regroup_humann_dir) || mkpath(regroup_humann_dir)
    isdir(rename_humann_dir) || mkpath(rename_humann_dir)

    if isfile(hm_mainout) 
        run(`$hm_regroup_execline -i $hm_mainout -c $(joinpath(util_db_dir, "map_level4ec_uniclust90.txt.gz")) -o $(joinpath(regroup_humann_dir, sample))_$(hm_vertag)_ecs.tsv`)
        run(`$hm_regroup_execline -i $hm_mainout -c $(joinpath(util_db_dir, "map_ko_uniref90.txt.gz")) -o $(joinpath(regroup_humann_dir, sample))_$(hm_vertag)_kos.tsv`)
        run(`$hm_regroup_execline -i $hm_mainout -c $(joinpath(util_db_dir, "map_pfam_uniref90.txt.gz"))  -o $(joinpath(regroup_humann_dir, sample))_$(hm_vertag)_pfams.tsv`)

        run(`$hm_rename_execline -i $(joinpath(regroup_humann_dir, sample))_$(hm_vertag)_ecs.tsv -c $(joinpath(util_db_dir, "map_level4ec_name.txt.gz")) -o $(joinpath(rename_humann_dir, sample))_$(hm_vertag)_ecs_rename.tsv`)
        run(`$hm_rename_execline -i $(joinpath(regroup_humann_dir, sample))_$(hm_vertag)_kos.tsv -c $(joinpath(util_db_dir, "map_ko_name.txt.gz")) -o $(joinpath(rename_humann_dir, sample))_$(hm_vertag)_kos_rename.tsv`)
        run(`$hm_rename_execline -i $(joinpath(regroup_humann_dir, sample))_$(hm_vertag)_pfams.tsv -c $(joinpath(util_db_dir, "map_pfam_name.txt.gz")) -o $(joinpath(rename_humann_dir, sample))_$(hm_vertag)_pfams_rename.tsv`)
    end
end