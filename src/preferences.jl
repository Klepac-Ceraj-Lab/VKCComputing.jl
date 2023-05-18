
"""
TODO:

- set airtable dir using call to scratch drivbe with user name
- throw warnings if any of the directories don't exist
"""
function set_default_preferences!()
    host = readchomp(`hostname`)
    if host == "vkclab-hopper"
        @set_preferences!("mgx_analysis_dir"=> "/grace/sequencing/processed/mgx/")
        @set_preferences!("mgx_raw_dir"=> "/grace/sequencing/raw/mgx/rawfastq/")
    elseif host == "vkclab-ada"
        @set_preferences!("mgx_analysis_dir"=> "/lovelace/sequencing/processed/mgx/")
        @set_preferences!("mgx_raw_dir"=> "/lovelace/sequencing/raw/mgx/rawfastq/")
    elseif host == "vklepacc-imac27-0118"
        @set_preferences!("mgx_analysis_dir"=> "/Volumes/franklin/sequencing/processed/mgx/")
        @set_preferences!("mgx_raw_dir"=> "/Volumes/franklin/sequencing/raw/mgx/rawfastq/")
    else
        throw(ArgumentError("Host not recognized: $host"))
    end
end

"""
    set_airtable_dir!(key)

Sets local preferences for `airtable_dir` to `key`
(defaults to the environmental variable `"AIRTABLE_DIR"` if set).
"""
set_airtable_dir!(key=get(ENV, "AIRTABLE_DIR", nothing)) =
    isnothing(key) ? throw(ArgumentError("'AIRTABLE_DIR' environment variable not found")) : @set_preferences!("airtable_dir", key)

"""
    set_readonly_pat!(key)

Sets local preferences for `readonly_pat` to `key`
(defaults to the environmental variable `"AIRTABLE_KEY"` if set).
"""
set_readonly_pat!(key=get(ENV, "AIRTABLE_KEY", nothing)) =
    isnothing(key) ? throw(ArgumentError("'AIRTABLE_KEY' environment variable not found")) : @set_preferences!("readonly_pat", key)

"""
    set_readwrite_pat!(key)

Sets local preferences for `readwrite_pat` to `key`
(defaults to the environmental variable `"AIRTABLE_RW_KEY"` if set).
"""
set_readwrite_pat!(key=get(ENV, "AIRTABLE_RW_KEY", nothing)) =
    isnothing(key) ? throw(ArgumentError("'AIRTABLE_RW_KEY' environment variable not found")) : @set_preferences!("readwrite_pat", key)
