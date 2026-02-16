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
