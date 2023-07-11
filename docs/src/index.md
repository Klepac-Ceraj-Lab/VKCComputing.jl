```@meta
CurrentModule = VKCComputing
```

# VKCComputing.jl

Documentation for [VKCComputing](https://github.com/Klepac-Ceraj-Lab/VKCComputing.jl).


```@index
```

## Setup environment

```@docs
set_default_preferences!
set_airtable_dir!
set_readonly_pat!
set_readwrite_pat!
```

## Interacting with Airtable

```@docs
VKCAirtable
LocalAirtable
LocalBase
vkcairtable
localairtable
uids
```

## Interacting with records

```@docs
resolve_links
biospecimens
seqpreps
subjects
```

## Interacting with files

```@docs
get_analysis_files
audit_analysis_files
audit_tools
```

## Interacting with AWS

```@docs
aws_ls
```