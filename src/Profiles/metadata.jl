function load_metadata(src::CSVMetadataSource)::DataFrame
    return CSV.read(src.path, DataFrame; stringtype=String)
end

function load_metadata(src::AirtableMetadataSource)::DataFrame
    tbl = Airtable.list_records(
        src.base_id,
        src.table_name;
        api_key = src.api_key,
        view = src.view
    )

    rows = [r.fields for r in tbl]
    return DataFrame(rows)
end

function load_metadata(cfg::LeapConfig)::DataFrame
    return load_metadata(cfg.metadata_source)
end