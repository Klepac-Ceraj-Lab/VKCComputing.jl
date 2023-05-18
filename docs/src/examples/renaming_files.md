# Renaming files (from aliases)

## Motivation

After changing the way that we label samples,
we sometimes need to update a previous file-name
or table column name to reflect the new system.

## Getting current data

The first thing to do in most projects is to load
the airtable database into memory.
If you want to guarantee that you have the most recent
version of any particular table, use the `update` argument
of [`LocalBase`](@ref)