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

