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
            --count-normalization "RPKs" \
            --output-basename $(sample)_$(hm_vertag) \
            --threads 20`
        )
                    # --search-mode uniref90 \
    end

    rm(catfile)

    return(joinpath(humann_dir, "main", "$(sample)_$(hm_vertag)_2_genefamilies.tsv"))

end