using ArgParse
using Dates
using VKCComputing, VKCComputing.BioBakery
sample = "SRR30136311"

function this_args()
    s = ArgParseSettings()
    @add_arg_table s begin
        "--sample", "-s"
            help = "Sample ID to process"
            required = true
    end
    return parse_args(ARGS, s)
end

if abspath(PROGRAM_FILE) == @__FILE__
    args = this_args()
    sample = args["sample"]

    # sample_list = "$(ENV["HOME"])/Processing/samples.txt"
    rawfastq_dir = "$(ENV["HOME"])/Processing/rawfastq"
    knead_dir = "$(ENV["HOME"])/Processing/kneaddata"
    metaphlan_dir = "$(ENV["HOME"])/Processing/metaphlan"
    humann_dir = "$(ENV["HOME"])/Processing/humann"

    prefetch_config = PrefetchConfig(;
        fasterq_dump_execline = `apptainer run --bind "$(ENV["HOME"])/Databases:$(ENV["HOME"])/Databases" --bind "$(ENV["HOME"])/Processing:$(ENV["HOME"])/Processing" /home/gz101/containers/bzip2.sif fasterq-dump`,
        n_threads = 10,
        split_strat = "--split-3"
    )

    kneaddata_config = KneadDataConfig(;
        kd_execline = `apptainer run --bind "$(ENV["HOME"])/Databases:$(ENV["HOME"])/Databases" --bind "$(ENV["HOME"])/Processing:$(ENV["HOME"])/Processing" /home/gz101/containers/kneaddata-012.sif kneaddata`,
        hg_db_dir = "$(ENV["HOME"])/Databases/kneaddata/hg37dec_v0.1",
        n_threads = 10,
        n_processes = 2,
        trimmomatic_path = "/opt/conda/bin"
    )

    # 0. fetch fastq from repository
    fasterq_dump(
        sample,
        rawfastq_dir;
        cfg = prefetch_config
    )

    # 1. Run Kneaddata
    run_kneaddata(
        sample,
        rawfastq_dir,
        knead_dir;
        cfg = kneaddata_config
    )

    # 2. Concatenate QC-passed reads into a single file
    catkneads = cat_kneads(
        sample, knead_dir, metaphlan_dir
    )

    # 3.1. Run Metaphlan with database 1 (Vanilla vOct22)
    mpv4_profiles = run_metaphlan(
        sample, catkneads, metaphlan_dir; 
        db_dir = "$(ENV["HOME"])/Databases/metaphlan4/mpa_vOct22_default", 
        db_prefix = "mpa_vOct22_CHOCOPhlAnSGB_202403", 
        mp_execline = `apptainer run --bind $(ENV["HOME"])/Databases:$(ENV["HOME"])/Databases --bind $(ENV["HOME"])/Processing:$(ENV["HOME"])/Processing /home/gz101/containers/metaphlan-4.sif metaphlan`
    )
    # 3.2. Run Metaphlan with database 2 (vOct22 + Binfantis)
    mpv4_binf_profiles = run_metaphlan(
        sample, catkneads, metaphlan_dir; 
        db_dir = "$(ENV["HOME"])/Databases/metaphlan4/mpa_vOct22_lon_subsp", 
        db_prefix = "mpa_vOct22_CHOCOPhlAnSGB_202403_lon_subsp", 
        mp_execline = `apptainer run --bind $(ENV["HOME"])/Databases:$(ENV["HOME"])/Databases --bind $(ENV["HOME"])/Processing:$(ENV["HOME"])/Processing /home/gz101/containers/metaphlan-4.sif metaphlan`
    )
    # 4.1 Run Humann MAIN
    hm_mainout = run_humann_main(
        sample, catkneads, mpv4_profiles[2], humann_dir;
        hm_vertag = "HM40",
        hm_execline = `apptainer run --bind $(ENV["HOME"])/Databases:$(ENV["HOME"])/Databases --bind $(ENV["HOME"])/Processing:$(ENV["HOME"])/Processing /home/gz101/containers/humann-4.sif humann`,
        choco_db_dir = "$(ENV["HOME"])/Databases/humann4/chocophlan",
        prot_db_dir = "$(ENV["HOME"])/Databases/humann4/uniref90_annotated",
        util_db_dir = "$(ENV["HOME"])/Databases/humann4/full_mapping"
    )
    # 4.2 Run Humann REGROUP/RENAME
    run_humann_regroup_rename(
        sample, hm_mainout, humann_dir,
        hm_vertag = "HM40",
        hm_regroup_execline = `apptainer run --bind $(ENV["HOME"])/Databases:$(ENV["HOME"])/Databases --bind $(ENV["HOME"])/Processing:$(ENV["HOME"])/Processing /home/gz101/containers/humann-4.sif humann_regroup_table`,
        hm_rename_execline = `apptainer run --bind $(ENV["HOME"])/Databases:$(ENV["HOME"])/Databases --bind $(ENV["HOME"])/Processing:$(ENV["HOME"])/Processing /home/gz101/containers/humann-4.sif humann_rename_table`,
        util_db_dir = "$(ENV["HOME"])/Databases/humann4/full_mapping"
    )

end