function set_mgx_analysis_dir!()
    host = readchomp(`hostname`)
    if host == "vkclab-hopper"
        @set_preferences!("mgx_analysis_dir"=> "/grace/sequencing/processed/mgx/")
    elseif host == "vkclab-ada"
        @set_preferences!("mgx_analysis_dir"=> "/lovelace/sequencing/processed/mgx/")
    elseif host == "vklepacc-imac27-0118"
        @set_preferences!("mgx_analysis_dir"=> "/Volumes/franklin/sequencing/processed/mgx/")
    else
        throw(ArgumentError("Host not recognized: $host"))
    end
end

set_mgx_analysis_dir!(dir) = @set_preferences!("mgx_analysis_dir"=> dir)

function set_mgx_raw_dir!()
    host = readchomp(`hostname`)
    if host == "vkclab-hopper"
        @set_preferences!("mgx_raw_dir"=> "/grace/sequencing/raw/mgx/rawfastq/")
    elseif host == "vkclab-ada"
        @set_preferences!("mgx_raw_dir"=> "/lovelace/sequencing/raw/mgx/rawfastq/")
    elseif host == "vklepacc-imac27-0118"
        @set_preferences!("mgx_raw_dir"=> "/Volumes/franklin/sequencing/raw/mgx/rawfastq/")
    else
        throw(ArgumentError("Host not recognized: $host"))
    end
end

set_mgx_raw_dir!(dir) = @set_preferences!("mgx_raw_dir"=> dir)
