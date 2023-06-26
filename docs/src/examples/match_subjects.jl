# # Match samples to subject IDs
#
# Dima sent a CSV of subject IDs,
# we want to find all subjects for which we have 3 or 6 month IDs

using VKCComputing
using CSV
using DataFrames

base = base = LocalBase()
tab = CSV.read("dima_ids.csv", DataFrame; stringtype=String)

#-

subs = subjects(base, "khula")
subs.stool .= true
leftjoin!(tab, select(subs, "subject_id"=>"ID", "stool"=>"stool"); on = "ID")

tab.stool = Int.(coalesce.(tab.stool, false))

CSV.write("dima_with_stool.csv", tab)