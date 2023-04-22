function mgx_tool_files(project::String, tool; force_update = false, update_interval = Month(1))
    dir = @load_preference("mgx_analysis_dir")
    pmd = nested_metadata("Project"; force=force_update, interval=update_interval)
    samples = pmd[findfirst(t-> t.fields[:Name] == project, pmd)].fields[:Samples]
end