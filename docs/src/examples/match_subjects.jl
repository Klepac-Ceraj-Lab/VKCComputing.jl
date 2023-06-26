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

subject_recs = map(tab.ID) do id
    get(base["Subjects"], string(["khula-", id]), missing)
end