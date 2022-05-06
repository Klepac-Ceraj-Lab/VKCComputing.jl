function set_mgx_analysis_dir!()
    host = readchomp(`hostname`, String)
    if host == "vkclab-hopper"
        @set_preferences!("mgx_analysis_dir"=> "/grace/echo/analysis/biobakery3")
    elseif host == "vkclab-ada"
        @set_preferences!("mgx_analysis_dir"=> "/lovelace/echo/analysis/")
    elseif host == "vklepacc-imac27-0118"
        @set_preferences!("mgx_analysis_dir"=> "/Volumes/franklin/echo/analysis/biobakery3/")
    else
        throw(ArgumentError("Host not recognized: $host"))
    end
end