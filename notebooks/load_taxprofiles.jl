#####
# 2. KHULA-MW and KHULA-SA data
#####
using CSV
using DataFrames
using BiobakeryUtils
using Chain
using Leap

khula_visits = @chain CSV.read("data/2025-07-16-khula_ages_visit_reltable.csv", DataFrame; stringtype = String)

#####
# Taxonomic Profiles
#####
khula_tax_data_species = @chain Leap.load_raw_metaphlan(
    "/home/guilherme/minerva-mount/processed/internal/metaphlan/mpa_vOct22_CHOCOPhlAnSGB_202403_lon_subsp";
    replace_pattern = r"SEQ0\d+_S\d+_mpa_vOct22_CHOCOPhlAnSGB_202403_lon_subsp_RELAB_profile",
    cleanup_pattern = "_mpa_vOct22_CHOCOPhlAnSGB_202403_lon_subsp_RELAB_profile.tsv") begin
    filter(t-> !ismissing(taxrank(t)), _[:, samplenames(_)])
    # filter(t-> taxrank(t) == :subspecies, _[:, samplenames(_)])
    filter(t-> taxrank(t) == :species, _[:, samplenames(_)])
    comm2wide()
    select(Not([:sample, :file]))
    # leftjoin(unimdata, _, on = :sample => :sample_base )
    filter_prevalence(0.001)
    # dropmissing()
end

khula_tax_data_sgb = @chain Leap.load_raw_metaphlan(
    "/home/guilherme/minerva-mount/processed/internal/metaphlan/mpa_vOct22_CHOCOPhlAnSGB_202403_lon_subsp";
    replace_pattern = r"SEQ0\d+_S\d+_mpa_vOct22_CHOCOPhlAnSGB_202403_lon_subsp_RELAB_profile",
    cleanup_pattern = "_mpa_vOct22_CHOCOPhlAnSGB_202403_lon_subsp_RELAB_profile.tsv") begin
    filter(t-> !ismissing(taxrank(t)), _[:, samplenames(_)])
    filter(t-> taxrank(t) == :subspecies, _[:, samplenames(_)])
    comm2wide()
    select(Not([:sample, :file]))
    # leftjoin(unimdata, _, on = :sample => :sample_base )
    filter_prevalence(0.001)
    dropmissing()
end

#####
# Separate Longum and Infantis
#####

khula_tax_data_sgb_subset = @chain khula_tax_data_sgb begin
    rename(
        "subsp.infantis" => "Bifidobacterium_longum_infantis",
        "subsp.longum" => "Bifidobacterium_longum_longum"
    )
    select(["sample_base", "Bifidobacterium_longum_longum", "Bifidobacterium_longum_infantis" ])
end

khula_tax_data_merged = innerjoin(khula_tax_data_sgb_subset, select(khula_tax_data_species, Not("Bifidobacterium_longum")), on = "sample_base")

khula_swanson_data = @chain khula_visits begin
    innerjoin(khula_tax_data_merged, on = :uid => :sample_base)
end

CSV.write("2026-02-20-Khula_SwansonData.csv", khula_swanson_data)