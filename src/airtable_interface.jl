
"""
    VKCAirtable(base, name, localpath)

Connecting Airtable tables with local instances.
Generally, use [`vkcairtable`](@ref) to create.
"""
struct VKCAirtable
    key::Airtable.Credential
    base::AirBase
    name::String
    localpath::String
end

"""
    LocalAirtable(table, data, uididx)

Primary data structure for interacting with airtable-based data.
"""
struct LocalAirtable
    table::VKCAirtable
    data
    uid_idx::Dictionary
    atid_idx::Dictionary
end

"""
    LocalBase(; update=Month(1))

Load the airtable sample database into memory.
Requires that an airtable key with read access
and a directory for storing local files are set to preferences.
(see [`set_readonly_pat!`](@ref) and [`set_airtable_dir!`](@ref).

## Updating local base files

The `update` keyword argument can take a number of different forms.

1. A boolean value, which will cause updates to all tables if `true`,
   and no tables if `false`.
2. An `AbstractTime` from `Dates` (eg `Week(1)`), which will update any table
   whose local copy was last updated longer ago than this value.
3. A vector of `Pair`s of the form `"\$table_name"=> x`, where `x` is either
   of the options from (1) or (2) above.

For example, to update the "Biospecimens" table if it's older than a week,
and to update the "Projects" table no matter what, call

```julia
julia> using VKCComputing, Dates

julia> base = LocalBase(; update=["Biospecimens"=> Week(1), "Projects"=> true]);
```

## Indexing

Indexing into the local base can be done either with the name of a table
(eg `base["Biospecimens"]`), which will return a [`VKCAirtable`](@ref),
or using a record ID hash (eg `base["recUqEcu3pM8p2jzQ"]`). 

!!! warning
    Note that record ID hashes are identified based on the regular expression
    `r"^rec[A-Za-z0-9]{14}\$"` - that is, a string starting with `"rec"`,
    followed by exactly 14 alphanumeric characters.
    In principle, one could name a table as something that matches this regular expression,
    causing it to be improperly identified as a record hash rather than a table name.

[`VCKAirtable`](@ref)s can also be indexed with the `uid` column string,
so an individual record can be accessed using eg `base["Projects"]["khula"]`,
but a 2-argument indexing option is provided for convenience, eg `base["Projects", "khula"]`.
"""
struct LocalBase
    tableidx::Dictionary{String, LocalAirtable}
    recordidx::Dictionary{String, String}

    function LocalBase(update)
        tidx = dictionary([t => localairtable(vkcairtable(t); update = update[t]) for t in _new_tables])
        ridx = dictionary([r.id => t for t in _new_tables for r in tidx[t].data])
        new(tidx, ridx)
    end
end

_localbase_update(arg = dictionary(t => Month(1) for t in _new_tables)) = arg
_localbase_update(arg::Dates.AbstractTime) = dictionary((t => arg for t in _new_tables))
_localbase_update(arg::Bool) = dictionary((t => arg for t in _new_tables))
_localbase_update(arg::AbstractVector) = merge(_localbase_update(), dictionary(arg))

LocalBase(; update = Month(1)) = LocalBase(_localbase_update(update))

_isrecordhash(query)::Bool = false
_isrecordhash(query::AbstractString)::Bool = contains(query, r"^rec[A-Za-z0-9]{14}$")

const oldbase = AirBase("appSWOVVdqAi5aT5u")
const newbase = AirBase("appmYwoXIHlen5s0q")

const _new_tables = (
    "Aliases",
    "Biospecimens",
    "CollectionBuffer",
    "MetabolomicsBatches",
    "Projects",
    "SequencingBatches",
    "SequencingPrep",
    "Sites",
    "Subjects",
    "Visits",
)



"""
    vkcairtable(name::String)

Returns a [VKCAirtable](@ref) type based on the table name.
Requires that the local preference `airtable_dir` is set.
See [VKCComputing.set_preferences!](@ref).
"""
function vkcairtable(name::String) #; olddb = false)
    if @has_preference("readonly_pat")
        pat = @load_preference("readonly_pat")
    elseif @has_preference("readwrite_pat")
        pat = @load_preference("readonly_pat")
    else 
        pat = get(ENV, "AIRTABLE_KEY", nothing)
    end
    isnothing(pat) && throw(ArgumentError("No airtable key available - set preference for 'readonly_pat' or 'readwrite_pat', or the environmental variable 'AIRTABLE_KEY'"))
    key = Airtable.Credential(pat)
    base = newbase # olddb ? oldbase : newbase
    return VKCAirtable(key, base, name,
                joinpath(@load_preference("airtable_dir"), 
                    "airtable_$(lowercase(replace(name, " "=> ""))).json")
            )
end

"""
    localairtable(tab::VKCAirtable; update=Month(1))

Create an instance of [`LocalAirtable`](@ref), optionally updating the local copy from remote.
"""
function localairtable(tab::VKCAirtable; update = Month(1))
    data = ThreadsX.map(nested_metadata(tab; update)) do rec
        AirRecord(rec.id, AirTable(tab.name, tab.base), rec.fields)
    end
    uid_idx = dictionary(map(eachindex(data)) do i
        (haskey(data[i].fields, :uid) ? data[i].fields[:uid] : first(data[i].fields), i)
    end)
    atid_idx = dictionary(map(eachindex(data)) do i
        (data[i].id, haskey(data[i].fields, :uid) ? data[i].fields[:uid] : first(data[i].fields))
    end)

    return LocalAirtable(tab, data, uid_idx, atid_idx)
end

Base.show(io::IO, tab::VKCAirtable) = print(io, "Airtable with name \"$(tab.name)\", located at $(tab.localpath)")
Base.show(io::IO, tab::LocalAirtable) = print(io, "Airtable with name \"$(tab.table.name)\" and $(length(tab.data)) records")
Base.show(io::IO, base::LocalBase) = print(io, join(values(base.tableidx), '\n'))

Base.haskey(base::LocalBase, k) = _isrecordhash(k) ? haskey(base.recordidx, k) : haskey(base.tableidx, k)

Base.getindex(base::LocalBase, i) = _isrecordhash(i) ? base[base.recordidx[i]][i] : base.tableidx[i]
Base.getindex(base::LocalBase, v::AbstractVector) = ThreadsX.map(i-> getindex(base, i), v)
Base.getindex(base::LocalBase, i, j) = base[i][j]

Base.haskey(tab::LocalAirtable, k) = _isrecordhash(k) ? haskey(tab.atid_idx, k) : haskey(tab.uid_idx, k)

Base.getindex(tab::LocalAirtable, i) = getindex(tab.data, i)
Base.getindex(tab::LocalAirtable, i::String) = _isrecordhash(i) ? getindex(tab, tab.atid_idx[i]) : getindex(tab.data, tab.uid_idx[i])
Base.getindex(tab::LocalAirtable, v::AbstractVector) = ThreadsX.map(i-> getindex(tab, i), v)

function Base.getindex(tab::LocalAirtable, reg::Regex)
    idx = findall([contains(k, reg) for k in keys(tab.uid_idx)])
    return tab[idx]
end

"""
    uids(tab::LocalAirtable)

Get the keys for the `uid` column of table `tab`.
"""    
uids(tab::LocalAirtable) = keys(tab.uid_idx)

"""
    uids(base::LocalBase, tab::String)

Get the keys for the `uid` column of table `tab` from `base`.
"""
uids(base::LocalBase, tab::String) = keys(base[tab].uid_idx)

function _should_update(mod, update::Bool)
    update && @debug "Should update: `update = true`"
    return update
end

function _should_update(mod, update::Dates.AbstractTime)
    if mod + update < now(localzone())
        @debug "Should update: last modified less than specified interval (*$update*)"
        return true
    else
        @debug "No update needed for interval: $update"
        return false
    end
end

function _should_update(file; update = Month(1))::Bool
    modtime = astimezone(ZonedDateTime(Dates.unix2datetime(mtime(file)), tz"UTC"), localzone())
    @debug "Expected file location: `$file`"
    @debug "Last modified: `$modtime`"
    if !isfile(file)
        @debug "Should update: missing file"
        return true
    else
        return _should_update(modtime, update)
    end
end

"""
    update_local_metadata!(::VKCAirtable; update = Month(1))

Updates the local JSON file from the remote database.
By default, this will use the local copy of a database unless

- the local copy doesn't exist
- `update` is set to `true`
- the local file was created more than `interval` ago (default 1 month)

See [vkcairtable](@ref) for how to get the first argument.
"""
function update_local_metadata!(tab::VKCAirtable; update = Month(1))
    if _should_update(tab.localpath; update)
        @info "Table $(tab.name) needs updating, writing to `$(tab.localpath)`"
        JSON3.write(tab.localpath, Airtable.query(tab))
        return true
    else
        @info "Table $(tab.name) does not need updating updating. Use `update = true` or `update = {shorter interval}` to override"
        return false
    end
end

function Airtable.query(key, tab::VKCAirtable)
    table = AirTable(tab.name, tab.base)
    Airtable.query(key, table)
end

Airtable.query(tab::VKCAirtable) = Airtable.query(tab.key, tab)


"""
    nested_metadata(tab::VKCAirtable; update = Month(1))


"""
function nested_metadata(tab::VKCAirtable; update = Month(1))
    localfile = tab.localpath
    update_local_metadata!(tab; update) || !isfile(localfile)
    @info "Loading records from local JSON file"
    return open(JSON3.read, localfile)
end

nested_metadata(tab::String; update = Month(1)) = nested_metadata(vkcairtable(tab); update)
