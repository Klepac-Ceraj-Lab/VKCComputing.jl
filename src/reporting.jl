const pt = DataFrames.PrettyTables.pretty_table

function ptable2string(table; ptkwargs...)
    io = IOBuffer()
    pt(io, table; ptkwargs...)
    seek(io, 0)
    return """|
    ```
    $(read(io, String))
    ```
    """
end


"""
    report_problems(problem_files)

WIP
"""
function report_problems(problem_files)
    problems = unique(problem_files.sample)
    @info "$(length(problems)) Problem IDs:"
    @info ptable2string(combine(groupby(problem_files, "sample"),
        "s_well_ambiguity" => any => "check_s_well",
        "bad_suffix"      => any => "check_suffices",
        "bad_uid"         => any => "check_uid"
    ); show_subheader=false)
end

"""
    compare_remote_local(remote_seq, local_seq; update_remote=false)

WIP
"""
function compare_remote_local(remote_seq, local_seq; update_remote=false)
    comp = DataFrame(
        thing  = ["sequences (N)", "kneaddata (N)", "metaphlan (N)", "humann    (N)"],
        Local  = [size(local_seq, 1), count(local_seq.kneaddata_complete), count(local_seq.metaphlan_complete), count(local_seq.humann_complete)],
        Remote = [size(remote_seq, 1), count(remote_seq.kneaddata), count(remote_seq.metaphlan), count(remote_seq.humann)]
    )
    comp.diff = comp.Local .- comp.Remote
    
    @info ptable2string(comp; show_subheader=false)

    
    all_seqids = union(remote_seq.uid, local_seq.sample)

    local_kn = subset(local_seq, "kneaddata_complete"=> identity)
    local_mp = subset(local_seq, "metaphlan_complete"=> identity)
    local_hm = subset(local_seq, "humann_complete"=> identity)
    remote_kn = subset(remote_seq, "kneaddata"=> identity)
    remote_mp = subset(remote_seq, "metaphlan"=> identity)
    remote_hm = subset(remote_seq, "humann"=> identity)

    discr = DataFrame(
        thing = ["Local, not remote", "Remote, not local"],
        kneaddata = [length(setdiff(local_kn.sample, remote_kn.uid)), length(setdiff(remote_kn.uid, local_kn.sample))],
        metaphlan = [length(setdiff(local_mp.sample, remote_mp.uid)), length(setdiff(remote_mp.uid, local_mp.sample))],
        humann    = [length(setdiff(local_hm.sample, remote_hm.uid)), length(setdiff(remote_hm.uid, local_hm.sample))]
    )
    @info ptable2string(discr; show_subheader=false)
end



function audit_report(remote_seq, local_seq, good_files, problem_files)
    compare_remote_local(remote_seq, local_seq)
    report_problems(problem_files)
end