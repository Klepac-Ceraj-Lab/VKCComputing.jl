using Airtable
using VKCComputing
using JSON3
using DataFrames
using Preferences
using Dates
using LoggingExtras
using MiniLoggers
using Dictionaries

oldpat = @load_preference(VKCComputing, "old_readonly_pat") # PAT with read record access to `μBiome Samples` Base
newpat = @load_preference(VKCComputing, "new_readwrite_pat") # PATH with read/write for both records and schema for new SequencingSamples Base

olddb = AirBase("appSWOVVdqAi5aT5u")
newdb = AirBase("appmYwoXIHlen5s0q")

#- 

xferdir = joinpath(load_preference(VKCComputing, "airtable_dir"), "xfer")
isdir(xferdir) || mkpath(xferdir)

#-

interval = Day(2)
force = false

old_samples = nested_metadata(VKCAirtable(
    Airtable.Credential(oldpat),
    olddb,
    "Samples",
    joinpath(xferdir, "airtable_samples.json")
))

old_projects = nested_metadata(VKCAirtable(
    Airtable.Credential(oldpat),
    olddb,
    "Project",
    joinpath(xferdir, "airtable_projects.json")
))

old_mgxbatches = nested_metadata(VKCAirtable(
    Airtable.Credential(oldpat),
    olddb,
    "MGX Batches",
    joinpath(xferdir, "airtable_mgxbatches.json")
))

new_biospecimens = nested_metadata(VKCAirtable(
    Airtable.Credential(newpat),
    newdb,
    "Biospecimens",
    joinpath(xferdir, "airtable_biospecimens.json")
); interval, force)

new_seqprep = nested_metadata(VKCAirtable(
    Airtable.Credential(newpat),
    newdb,
    "SequencingPrep",
    joinpath(xferdir, "airtable_seqprep.json")
); interval, force)

new_seqbatches = nested_metadata(VKCAirtable(
    Airtable.Credential(newpat),
    newdb,
    "SequencingBatches",
    joinpath(xferdir, "airtable_seqbatch.json")
); interval, force)

new_aliases = nested_metadata(VKCAirtable(
    Airtable.Credential(newpat),
    newdb,
    "Aliases",
    joinpath(xferdir, "airtable_aliases.json")
); interval, force)

new_subjects = nested_metadata(VKCAirtable(
    Airtable.Credential(newpat),
    newdb,
    "Subjects",
    joinpath(xferdir, "airtable_subjects.json")
); interval, force)

new_projects = nested_metadata(VKCAirtable(
    Airtable.Credential(newpat),
    newdb,
    "Projects",
    joinpath(xferdir, "airtable_newprojects.json")
); interval, force)

new_visits = nested_metadata(VKCAirtable(
    Airtable.Credential(newpat),
    newdb,
    "Visits",
    joinpath(xferdir, "airtable_newvisits.json")
); interval, force)

new_buffers = nested_metadata(VKCAirtable(
    Airtable.Credential(newpat),
    newdb,
    "CollectionBuffer",
    joinpath(xferdir, "airtable_newbuffers.json")
); interval, force)

#-

global_logger(TeeLogger(
                MiniLogger(; minlevel=MiniLoggers.Info, message_mode=:markdown),
                MiniLogger(; minlevel=MiniLoggers.Info, append=true, io="dbxfer.log")
            )
)

#-


resprojid_old = old_projects[findfirst(rec-> rec.fields[:Name] == "ECHO", old_projects)].id
resprojid_new = new_projects[findfirst(rec-> rec.fields[:uid] == "resonance", new_projects)].id

new_biosp_ids = Set(map(rec-> rec.fields[:uid], new_biospecimens))

put_biosp = NamedTuple[]
alias_dict = Dictionary(String[], Vector{String}[])

 
for bsp in old_samples
    first(get(bsp.fields, :Project, ["no"])) == resprojid_old || continue
    sid = get(bsp.fields, :sample, nothing)

    if isnothing(sid)
        @warn "record had no ID: $bsp"
    else
        haskey(bsp.fields, :sid_old) && set!(alias_dict, bsp.fields[:sid_old], vcat(get(alias_dict, bsp.fields[:sid_old], String[]), [bsp.fields[:sample]]))
        push!(put_biosp, (; uid = bsp.fields[:sample], subject = get(bsp.fields, :subject, nothing)))
    end

end

subdict = dictionary([rec.fields[:uid] => AirRecord(rec.id, AirTable("Subjects", newdb), NamedTuple(rec.fields)) for rec in new_subjects])
put_subj = unique([(; uid = bsp.subject, project=[resprojid_new]) for bsp in put_biosp if (!isnothing(bsp.subject) && bsp.subject ∉ keys(subdict))])

!isempty(put_subj) && merge!(subdict, dictionary(zip([subj.uid for subj in put_subj], 
                                          Airtable.post!(Airtable.Credential(newpat), AirTable("Subjects", newdb), put_subj)))
)

put_biosp = map(bsp -> (; uid = bsp.uid, subject = [subdict[bsp.subject].id]), filter(bsp -> !isnothing(bsp.subject), put_biosp))
biosp_recs = Airtable.post!(Airtable.Credential(newpat), AirTable("Biospecimens", newdb), put_biosp)

#- 

uuid_map(json_out) = dictionary([rec.fields[:uid] => rec.id for rec in json_out])
function frommap(uidmap, fields, thing)
    resp = get(fields, thing, missing)
    resp = ismissing(resp) ? missing : [uidmap[lowercase(resp)]]
end


biosp_map = uuid_map(biosp_recs)
visits_map = uuid_map(new_visits)
buff_map = uuid_map(new_buffers)
oldsamples_idx = dictionary([old_samples[i].fields[:sample] => i for i in eachindex(old_samples) if haskey(old_samples[i].fields, :sample)])
oldbatch_map = dictionary([batch.id => batch.fields for batch in old_mgxbatches])
newbatch_map = dictionary([parse(Int, match(r"mgx batch(\d{3})"i, b.fields[:old_id]).captures[1]) => b.id for b in new_seqbatches if !isnothing(match(r"mgx batch(\d{3})"i, b.fields[:old_id]))])

updates = map(biosp_recs) do rec
    collection = get(old_samples[oldsamples_idx[rec.fields[:uid]]].fields, :timepoint, missing)
    collection isa AbstractString && (collection = parse(Int, collection))
    visit = frommap(visits_map, old_samples[oldsamples_idx[rec.fields[:uid]]].fields, :ECHOTPCoded)
    collection_buffer = get(old_samples[oldsamples_idx[rec.fields[:uid]]].fields, :Fecal_EtOH, missing)
    if !ismissing(collection_buffer)
        collection_buffer == "FG03057" && (collection_buffer = ("F"))
        collection_buffer ∉ ["E", "F"] && throw(ArgumentError("Fecal_EtOH should be 'E' or 'F', but is $collection_buffer"))
        collection_buffer = [collection_buffer == "E" ? buff_map["ethanol"] : buff_map["omnigene"]]
    end

    (; collection, visit, collection_buffer)
end
    
patches = Airtable.patch!(Airtable.Credential(newpat), AirTable("Biospecimens", newdb),  biosp_recs, updates)

batch_patches = filter(patches) do pt
    old = old_samples[oldsamples_idx[pt.fields[:uid]]]
    haskey(old.fields, Symbol("MGX Batches"))
end

newseqs = mapreduce(vcat, batch_patches) do pt
    old = old_samples[oldsamples_idx[pt.fields[:uid]]]
    batches = [newbatch_map[oldbatch_map[id][:Name]] for id in old.fields[Symbol("MGX Batches")]]
    return [(; biospecimen=[pt.id], sequencing_batch = [batch]) for batch in batches]
end

#-

seqids = Airtable.post!(Airtable.Credential(newpat), AirTable("SequencingPrep", newdb), newseqs)
seqids_dict = uuid_map(seqids)

#-

put_aliases = [(;
    uid = k,
    biospecimens = unique([biosp_map[j] for j in alias_dict[k]]),
    biospecimens_notes = "- from `sid_old` column in old database"
    ) for k in keys(alias_dict)
]

Airtable.post!(Airtable.Credential(newpat), AirTable("Aliases", newdb), put_aliases)