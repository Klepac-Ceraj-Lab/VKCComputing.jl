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
transform!(subs, "Biospecimens"=> ByRow(bios-> begin
    ismissing(bios) && return (; mo3 = 0, mo6 = 0)
    recs = base[bios]
    tps = [base[rec][:uid] for rec in Iterators.filter(
        !isempty, Iterators.flatten(map(r-> get(r, :visit, [""]), recs)))
    ]
    mo3 = Int("3mo" ∈ tps)
    mo6 = Int("6mo" ∈ tps)
    return (; mo3, mo6)

end) => ["3mo", "6mo"])

leftjoin!(tab, select(subs, "subject_id"=> "ID", "3mo", "6mo"); on="ID")

transform!(tab,
    "3mo" => ByRow(s-> coalesce(s, 0)) => "3mo",
    "6mo" => ByRow(s-> coalesce(s, 0)) => "6mo" 
)
#-

CSV.write("dima_with_stool.csv", tab)