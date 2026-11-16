abstract type MetadataSource end

struct CSVMetadataSource <: MetadataSource
    path::String
end

struct AirtableMetadataSource <: MetadataSource
    base_id::String
    table_name::String
    api_key::String
    view::Union{Nothing,String}
end

abstract type ProfileCollectorConfig end

Base.@kwdef struct TaxonomicProfileCollectorConfig <: ProfileCollectorConfig
    prefix::String
    workdir::String = pwd()
    taxrank::String
    metaphlan_dir::String
    metadata_source::MetadataSource
    metaphlan_replace_pattern::Regex = r"SEQ0\d+_S\d+_mpa_vOct22_CHOCOPhlAnSGB_202403_lon_subsp_RELAB_profile"
    metaphlan_cleanup_pattern::String = "_mpa_vOct22_CHOCOPhlAnSGB_202403_lon_subsp_RELAB_profile.tsv"
    prevalence_threshold::Float64 = 0.001
end