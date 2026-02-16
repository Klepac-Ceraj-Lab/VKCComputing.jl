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
            --nproc 20 \
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
            --nproc 20 \
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