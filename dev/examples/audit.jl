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

report_problems(problem_files)

#-

compare_remote_local(remote_seq, local_seq)