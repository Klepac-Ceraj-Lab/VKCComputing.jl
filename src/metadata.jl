
"""
    VKCAirtable(base, name, localpath)

Connecting Airtable tables with local instances
"""
struct VKCAirtable
    key::Airtable.Credential
    base::AirBase
    name::String
    localpath::String
end

Base.show(io::IO, tab::VKCAirtable) = print(io, "Airtable with name \"$(tab.name)\", located at $(tab.localpath)")


"""
    vkcairtable(name::String)

Returns a [VKCAirtable](@ref) type based on the table name.
Requires that the local preference `airtable_dir` is set.
See [VKCComputing.set_preferences!](@ref).
"""
vkcairtable(name::String) = _gen_table(Symbol(replace(name, " "=>"_")))

_gen_table(name::Symbol) = _gen_table(Val(name))
_gen_table(::Val{T}) where T = throw(ArgumentError("No table method defined for $(String(T))"))

_gen_table(::Val{:Project}) = VKCAirtable(
    Airtable.Credential(),
    AirBase("appSWOVVdqAi5aT5u"),
    "Project",
    joinpath(@load_preference("airtable_dir"), "airtable_project.json")
)

_gen_table(::Val{:Samples}) = VKCAirtable(
    Airtable.Credential(),
    AirBase("appSWOVVdqAi5aT5u"),
    "Samples",
    joinpath(@load_preference("airtable_dir"), "airtable_samples.json")
)

_gen_table(::Val{:MGX_Batches}) = VKCAirtable(
    Airtable.Credential(),
    AirBase("appSWOVVdqAi5aT5u"),
    "MGX Batches",
    joinpath(@load_preference("airtable_dir"), "airtable_mgxbatches.json")
)

_gen_table(::Val{:Amplicon_Batches}) = VKCAirtable(
    Airtable.Credential(),
    AirBase("appSWOVVdqAi5aT5u"),
    "Amplicon Batches",
    joinpath(@load_preference("airtable_dir"), "airtable_ampliconbatches.json")
)


function _should_update(file; force = false, interval = Month(1))
    modtime = astimezone(ZonedDateTime(Dates.unix2datetime(mtime(file)), tz"UTC"), localzone())
    @debug "Expected file location: `$file`"
    @debug "Last modified: `$modtime`"
    if force
        @debug "Should update: `force`"
        return true
    elseif !isfile(file)
        @debug "Should update: missing file"
        return true
    elseif modtime + interval < now(localzone())
        @debug "Should update: last modified less than specified interval (*$interval*)"
        return true
    else
        @debug "No update needed for interval: $interval"
        return false
    end
end

"""
    update_local_metadata!(::VKCAirtable; force = false, interval = Month(1))

Updates the local JSON file from the remote database.
By default, this will use the local copy of a database unless

- the local copy doesn't exist
- `force` is set to `true`
- the local file was created more than `interval` ago (default 1 month)

See [vkcairtable](@ref) for how to get the first argument.
"""
function update_local_metadata!(tab::VKCAirtable; force=false, interval = Month(1))
    if _should_update(tab.localpath; force, interval)
        @info "Table $(tab.name) needs updating, writing to `$(tab.localpath)`"
        JSON3.write(tab.localpath, Airtable.query(tab))
        return true
    else
        @info "Table $(tab.name) does not need updating updating. Use `force` or shorten `interval` to override"
        return false
    end
end

function Airtable.query(key, tab::VKCAirtable)
    table = AirTable(tab.name, tab.base)
    Airtable.query(key, table)
end

Airtable.query(tab::VKCAirtable) = Airtable.query(tab.key, tab)


"""
    nested_metadata(tab::VKCAirtable; force=false, interval = Month(1))


"""
function nested_metadata(tab::VKCAirtable; force=false, interval = Month(1))
    localfile = tab.localpath
    update_local_metadata!(tab; force, interval) || !isfile(localfile)
    @info "Loading records from local JSON file"
    return open(JSON3.read, localfile)
end

nested_metadata(tab::String; force=false, interval = Month(1)) = nested_metadata(vkcairtable(tab); force, interval)

function _flatten_airtable_records(records)
    reduce((x,y)-> vcat(x, y; cols=:union), ThreadsX.map(records) do record
        fields = record.fields
        DataFrame([(;
            first(keys(fields)) => first(values(fields)),
            :airtable_id => record.id,
            :table_id => record.table.id,
            :base_id => record.table.base.id,
            fields...
        )])
    end)
end

_parse_code_string(record) = eval(Meta.parse(record))

function tabular_metadata(tab::VKCAirtable; force=false, interval = Month(1), additional_columns=[])
    localtable = joinpath(dirname(tab.localpath), replace(basename(tab.localpath), ".json"=> ".csv"))
    localtable == tab.localpath && throw(ErrorException("Table path and json path are identical, aborting!"))
    if update_local_metadata!(tab; force, interval) || !isfile(localtable)
        @info "Airtable metadata was re-downloaded or table files was missing, so re-building table"
        tabular = _tabular(tab)
        CSV.write(localtable, tabular)
    else
        tabular=CSV.read(localtable, DataFrame; rows_to_check=5000)

    end
    return tabular
end

_tabular(::Val{T}) where T = throw(ArgumentError("No tabular output for $(String(T)) defined"))
_tabular(tab::VKCAirtable) = _tabular(Val(Symbol(replace(tab.name, " "=>"_"))), tab.localpath)

function _tabular(::Val{:MGX_Batches}, localpath)
    records = _flatten_airtable_records(open(JSON3.read, localpath))
    records."Date Shipped" = Date.(records."Date Shipped")
    return sort(records, :Name)
end

function _tabular(::Val{:Project}, localpath)
    records = _flatten_airtable_records(open(JSON3.read, localpath))
    return records
end

function _tabular(::Val{:Samples}, localpath)
    records = _flatten_airtable_records(open(JSON3.read, localpath))

    return records
end