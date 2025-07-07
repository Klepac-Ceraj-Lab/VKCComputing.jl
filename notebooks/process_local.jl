using ArgParse
using Dates
using VKCComputing

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

    # sample_list = "/Processing/samples.txt"
    rawfastq_dir = "/Processing/rawfastq"
    knead_dir = "/Processing/kneaddata"
    metaphlan_dir = "/Processing/metaphlan"
    humann_dir = "/Processing/humann"

    # 1. Run Kneaddata
    run_knead(sample, rawfastq_dir, knead_dir)
    # 2. Concatenate QC-passed reads into a single file
    catkneads = cat_kneads(sample, knead_dir, metaphlan_dir)
    # 3.1. Run Metaphlan with database 1 (Vanilla vOct22)
    mpv4_profiles = run_metaphlan(sample, catkneads, metaphlan_dir; db_dir = "/Databases/metaphlan4/mpa_vOct22_default", db_prefix = "mpa_vOct22_CHOCOPhlAnSGB_202403")
    # 3.2. Run Metaphlan with database 2 (vOct22 + Binfantis)
    mpv4_binf_profiles = run_metaphlan(sample, catkneads, metaphlan_dir; db_dir = "/Databases/metaphlan4/mpa_vOct22_lon_subsp", db_prefix = "mpa_vOct22_CHOCOPhlAnSGB_202403_lon_subsp")
    # 4.1 Run Humann MAIN
    hm_mainout = run_humann_main(sample, catkneads, mpv4_profiles[2], humann_dir)
    # 4.2 Run Humann REGROUP/RENAME
    run_humann_regroup_rename(sample, hm_mainout, humann_dir)

end