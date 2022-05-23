# Data cleanup and backup procedure

## Background

Everything on `/lovelace` (attached to `ada`, in Vanja's office)
was synced to `/franklin` (attached to `rosalind`, in the lab),
and then from `/franklin` to `/ThunderBay` (also attached to `rosalind`).
The only thing that is not recoverable that wasn't part of the stuff Vanja synced to NTM
is the last two rounds of sequencing, which are also stored on `/grace` (renamed from `/augusta`) - attached to `hopper`.
So unless both L-wing and Simpson are destroyed by the same disaster,
we should have everything secure in at least 3 places

## The Plan

### Phase 1 - Secure non-recoverable assets

Seqeuncing files, if lost, cannot be recovered.
As a consequence, the most care needs to be take with any changes to these assets.
Here's the plan to get that secured.

1. Wipe everything on /lovelace except for fastq files
2. For ECHO mgx sequences
   1. Rename all fastq files to the new `SampleNumber` paradigm (eg `FG00001`)
   2. Verify that all the samples that we've sequenced have one and only one set of sequences
   3. Compress, archive, and encrypt all sequences, by batch
   4. Sync bundled batches to `/Thunderbay` and `NTM` (or Google Drive, if I can figure that part out)
3. Repeat step 2, other than encryption, for 16S sequences
4. Repeat step 2, other than encryption, for non-ECHO samples

When this phase is complete,
we will have all data that is non-recoverable secure and organized,
so next steps can be done with confidence.

### Phase 2 - Analysis objects

We can always re-do the analysis steps,
but this is computationally expensive (and takes a lot of time),
so it's still important to do this well.
This will only be done for ECHO mgx samples.

1. Rename all analysis files to `SampleNumber` paradigm
2. Verify that all sequenced samples in batches 001-014 have the following:
   1. kneaddata (QC'ed) files
   2. Metaphlan taxomic profiles (`_profile.tsv`),
      alignment (`bowtie2.tsv`), and sam `.sam` files
   3. Humann functional profiles (`genefamilies.tsv`) and pathways (`pathabundance.tsv` and `pathcoverage.tsv`)
   4. For archival purposes, we'll skip regrouped, renormed, and named files, since those are large and easy to regenerate
3. Document any samples missing one or more of these.
   1. Some of these will be found in `weak_failed`
   2. Others may be missing for other reasons (name clashes etc)

### Phase 3 - Reorganization

Sequencing-batch based storage / organization for analysis files doesn't make a lot of sense,
especially since we're going to start having mixed sequencing batches
from multiple projects.
Instead, I propose the following structure:

```
Project
├── kneaddata 
│  ├── s1.fastq.gz
│  ├── s2.fastq.gz
│  └── etc...
├── metaphlan
│  ├── s1_profile.tsv
│  ├── s1_bowtie2.tsv
│  ├── s1.sam.bz2
│  ├── s2_profile.tsv
│  └── etc...
├── humann
│  ├── s1_genefamilies.tsv
│  ├── s1_pathabundance.tsv
│  ├── s1_pathcoverage.tsv
│  ├── s2_genefamilies.tsv
│  └── etc...
├── README.md
└── Project_metadata.toml # metadata about files, not samples
```

Scripts that automate moving files from an analysis run into this structure,
updating the metadata file, and verifying what's present
will become part of this repo.

### Phase 4 - Finalize

Once the reorganization is done,
Run batches 15 and 16 under the new paradigm,
use the process to test out new script functionality
(primarily on `hopper` and / or `engaging` to avoid conflicts)

## Structure proposal

```
Drive (eg `/lovelace`)
├── Sequencing
│  ├── metagenomes
│  ├── amplicon
│  │   ├── its
│  │   ├── V4V5
│  │   ├── V6V8
├── Project 1  (echo)
│  │   └── Project_metadata.toml # metadata about files, not samples

...

```

- README.md
- batchXXX.txt