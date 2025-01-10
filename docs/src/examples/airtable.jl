using VKCComputing
using Chain
using DataFrames
using CSV
using Airtable
using Preferences
using MiniLoggers

MiniLogger(; message_mode=:markdown ) |> global_logger

key = Airtable.Credential(load_preference(VKCComputing, "readwrite_pat"))
remote = AirBase("appmYwoXIHlen5s0q")
base = LocalBase()

filetypes = [ft[:Name] for ft in base["FileTypes", :]]

seqbatches = filter(base["SequencingBatches", :]) do batch
    get(batch, :type, "") == "mgx" &&
    get(batch, :facility, "") == "IMR" &&
    haskey(batch, :shipped) &&
    haskey(batch, :sequencing_prep_ids)
end

seqpreps = mapreduce(vcat, seqbatches) do batch
    [string(base[id][:uid], "_", get(base[id], :S_well, "S00")) for id in batch[:sequencing_prep_ids]]
end


filter(s-> endswith(s, "S00"), seqpreps)



