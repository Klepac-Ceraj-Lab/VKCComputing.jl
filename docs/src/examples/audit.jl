using VKCComputing
using Chain
using DataFrames
using Airtable
using Preferences
using MiniLoggers

MiniLogger(; message_mode=:markdown ) |> global_logger

key = Airtable.Credential(load_preference(VKCComputing, "readwrite_pat"))
remote = AirBase("appmYwoXIHlen5s0q")
base = LocalBase(; update=true)
analysis_files = get_analysis_files()

#-

remote_seq, local_seq, good_files, problem_files = audit_analysis_files(analysis_files; base)

DataFrames.pretty_table(remote_seq; show_subheader=false)
#-

DataFrames.pretty_table(local_seq; show_subheader=false)

#-

DataFrames.pretty_table(problem_files; show_subheader=false)

let problems = unique(problem_files.sample)
    @info "$(length(problems)) Problem IDs: $(problems)"
    combine(groupby(problem_files, "sample"),
        "s_well_ambiguity" => any => "check_s_well",
        "bad_suffix"      => any => "check_suffices",
        "bad_uid"         => any => "check_uid"
    )
end
#-

compare_remote_local(remote_seq, local_seq)