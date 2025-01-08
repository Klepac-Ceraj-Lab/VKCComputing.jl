# File storage

## Data Stores

### AWS cloud drives

The s3 bucket `s3://wc-vanja-klepac-ceraj` is managed by Wellesley College,
and should be regarded as permanent archival storage for backup purposes.

A number of additional buckets are managed by the VKC lab
and are used in a temporary fassion for eg running `nextflow` workflows.
In general, files stored here should be considered `temp` storage,
and not used for critical files

### Local Storage drives

#### Backup

- `hopper:/grace/`: General purpose, long-term storage
  - 10 Tb HDD
  - WD Elements
- `hopper:/tempstore`: General purpose, long-term storage
- `ada:/lovelace/`: General purpose
  - 8 Tb HDD
  - G-drive
- `rosalind:/Volumes/franklin/`: General purpose
  - 8 Tb HDD
  - G-drive
- `rosalind:/Volumes/ThunderBay`: Backup / Archive
  - 32 Tb RAID
  - OWC
- `rosalind:/Volumes/elsie`: Backup / General purpose
  - 10 Tb HDD
  - WD Elements

#### Working drives


- `hopper:/vassar`: High-speed access
  - 6 Tb SSD
- `hopper:/brewster`: High-speed access, databases, scratch space
  - 2 Tb NVMe
- `hopper:/murray`: High-speed access, scratch space
  - 2 Tb SSD
- `ada:/babbage/`: active computation / scratch
  - 2 Tb SSD
  - WD Passport


## Sequencing data

Sequencing data comprises a enormous array of often large,
often very important file types.
Some of these files typs (eg raw sequencing data)
cannot be recovered if lost.

Therefore, we often have multiple, redundant copies,
but keeping these copies in sync can be a challenge,
and mistakes can lead to at best huge storage costs,
and at worst, loss of critical data.

The following represents best-practices for dealing with sequencing data,
though we don't always live up to it.

In general, for a given [data store](#data-stores)

### Metagenomic data

Data from metagenomic sequencing,
including both raw and processed file products,
should be stored in at least 1 local backup drive,
and in the Wellesley-managed S3 bucket


#### Folder structure

1. Prefix: `{DRIVE}/sequencing/`
   - `DRIVE` may be eg `/grace`, `s3://wc-vanja-klepac-ceraj/backups`, or `/Volumes/franklin`
2. `(raw|processed)/` - raw sequencing files should go in `raw/`,
    anything derrived from processing by a tool (eg `kneaddata`) should go in `processed/`
3. `mgx/` - other types of sequecing will be dealt with in a different section
4. `(fastq|zip)/` - `raw` only - for compressed fastq files
5. `{TOOL}/` - `processed` only - whatever tool generated the files type.
   eg `humann` or `metaphlan`.
   see special cases below

##### MetaPhlAn database sub folders

For file products from `metaphlan`,
each file should include the ChocoPhlAn database verstion,
and should be stored in a subfolder named after the database version.
eg.

```
❯ fd SEQ01157 /grace/sequencing/processed/mgx/metaphlan
/grace/sequencing/processed/mgx/metaphlan/mpa_vJun23_CHOCOPhlAnSGB_202403/SEQ01157_S13_mpa_vJun23_CHOCOPhlAnSGB_202403_bowtie2.tsv
/grace/sequencing/processed/mgx/metaphlan/mpa_vJun23_CHOCOPhlAnSGB_202403/SEQ01157_S13_mpa_vJun23_CHOCOPhlAnSGB_202403.sam.bz2
/grace/sequencing/processed/mgx/metaphlan/mpa_vJun23_CHOCOPhlAnSGB_202403/SEQ01157_S13_mpa_vJun23_CHOCOPhlAnSGB_202403_profile.tsv
/grace/sequencing/processed/mgx/metaphlan/mpa_v31_CHOCOPhlAn_201901/SEQ01157_S13_mpa_v31_CHOCOPhlAn_201901_profile.tsv
/grace/sequencing/processed/mgx/metaphlan/mpa_v31_CHOCOPhlAn_201901/SEQ01157_S13_mpa_v31_CHOCOPhlAn_201901_bowtie2.tsv
/grace/sequencing/processed/mgx/metaphlan/mpa_v31_CHOCOPhlAn_201901/SEQ01157_S13_mpa_v31_CHOCOPhlAn_201901.sam.bz2
```

##### HUMAnN

Subdirectories:

- `main/`: Primary humann outputs, genefamilies, pathabundance, and pathcoverage
- `regroup/`: regrouped genefamilies (eg `ecs`)
- `rename/`: same as `regroup`, but with human-readable names of `ecs`, `kos`, etc

```
❯ fd SEQ01157 /grace/sequencing/processed/mgx/humann
/grace/sequencing/processed/mgx/humann/regroup/SEQ01157_S13_kos.tsv
/grace/sequencing/processed/mgx/humann/main/SEQ01157_S13_pathcoverage.tsv
/grace/sequencing/processed/mgx/humann/regroup/SEQ01157_S13_pfams.tsv
/grace/sequencing/processed/mgx/humann/regroup/SEQ01157_S13_ecs.tsv
/grace/sequencing/processed/mgx/humann/main/SEQ01157_S13_pathabundance.tsv
/grace/sequencing/processed/mgx/humann/main/SEQ01157_S13_genefamilies.tsv
/grace/sequencing/processed/mgx/humann/rename/SEQ01157_S13_kos_rename.tsv
/grace/sequencing/processed/mgx/humann/rename/SEQ01157_S13_ecs_rename.tsv
/grace/sequencing/processed/mgx/humann/rename/SEQ01157_S13_pfams_rename.tsv
/grace/sequencing/processed/mgx/kneaddata/SEQ01157_S13_kneaddata.log
```





