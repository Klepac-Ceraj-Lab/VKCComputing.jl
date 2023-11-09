using ArgParse
using BiobakeryUtils
using Microbiome

function parse_commandline()
    s = ArgParseSettings()

    @add_arg_table! s begin
        "--input", "-i"
            help = "Directory containing fastq files"
            default = "./rawfastq"
        "--output", "-o"
            help = "Directory for output files"
            default = "./output"
        # "--flag1"
        #     help = "an option without argument, i.e. a flag"
        #     action = :store_true
        # "arg1"
        #     help = "a positional argument"
        #     required = true
        "samples"
            help = "text file containing sample list"
    end

    return parse_args(s)
end

function run_knead(sample, indir, outdir)
    files = filter(f-> contains(basename(f), sample), readdir(indir; join = true))
    length(files) != 2 && throw(ArgumentError("incorrect number of samples matching $sample"))
    kneaddir = abspath(outdir, "kneaddata")
    isdir(kneaddir) || mkpath(kneaddir)
    if isfile(joinpath(kneaddir, "$(sample)_kneaddata.log")) 
        @info "Kneaddata log file found for $sample, skipping"
        return nothing
    end
    run(Cmd([
        "kneaddata",
        "--input", files[1],
        "--input", files[2],
        "--reference-db", "/murray/databases/kneaddata/hg37dec_v0.1",
        "--output", kneaddir,
        "--processes", "12",
        "--output-prefix", "$(sample)_kneaddata",
        "--trimmomatic", "/opt/conda/share/trimmomatic",
    ]))
    for f in filter(f-> contains(basename(f), Regex(string(sample, ".+", "fastq"))), readdir(kneaddir; join=true))
        run(`gzip $f`)
    end
end

function run_metaphlan(sample, indir, outdir)
    infiles = filter(f-> contains(basename(f), sample) &&
                         any(p-> contains(basename(f), p), (r"paired_[12]", "unmatched_[12]")),
                    readdir(abspath(outdir, "kneaddata"); join=true))
    metaphlandir = abspath(outdir, "metaphlan")
    isdir(metaphlandir) || mkpath(metaphlandir)
    catfile = joinpath(metaphlandir, "$sample.joined.fastq.gz")
    if isfile(joinpath(metaphlandir, "$(sample)_profile.tsv")) 
        @info "Metaphlan profile file found for $sample, skipping"
        return catfile
    end
    @info "writing combined file to $catfile"
    run(pipeline(`cat $infiles`; stdout=catfile))
    @info "Running MetaPhlAn"
    run(Cmd([
        "metaphlan", catfile, joinpath(metaphlandir, "$(sample)_profile.tsv"),
        "--bowtie2out", joinpath(metaphlandir, "$(sample)_bowtie2.tsv"),
        "--samout", joinpath(metaphlandir, "$(sample).sam"),
        "--input_type", "fastq",
        "--nproc", "16",
        "--bowtie2db", "/murray/databases/metaphlan",
        "--index", "mpa_v31_CHOCOPhlAn_201901"
    ]))
    run(`bzip2 $(joinpath(metaphlandir, "$(sample).sam"))`)
    return catfile
end


function run_humann(sample, indir, outdir, kneads)
    mprofile = abspath(outdir, "metaphlan", "$(sample)_profile.tsv")
    humanndir = abspath(outdir, "humann")
    isdir(joinpath(humanndir, "main")) || mkpath(joinpath(humanndir, "main"))
    isdir(joinpath(humanndir, "regroup")) || mkpath(joinpath(humanndir, "regroup"))
    isdir(joinpath(humanndir, "rename")) || mkpath(joinpath(humanndir, "rename"))

    if isfile(joinpath(humanndir, "main", "$(sample)_genefamilies.tsv")) 
        @info "Genefamilies file found for $sample, skipping"
    else
        run(Cmd([
            "humann", "--input", kneads,
            "--taxonomic-profile", joinpath(outdir, "metaphlan", "$(sample)_profile.tsv"),
            "--output", joinpath(humanndir, "main"),
            "--remove-temp-output", "--search-mode", "uniref90",
            "--output-basename", sample,
            "--threads", "32",
        ]))
    rm(kneads)
    end

end

function run_humann_regroup(sample, outdir)
    humanndir = abspath(outdir, "humann")
    gf_file = joinpath(humanndir, "main", "$(sample)_genefamilies.tsv") 
    ko_file = joinpath(humanndir, "regroup", "$(sample)_kos.tsv") 
    pfam_file = joinpath(humanndir, "regroup", "$(sample)_pfams.tsv") 
    ec_file = joinpath(humanndir, "regroup", "$(sample)_ecs.tsv") 

    if isfile(ko_file)
        @info "KOs regrouped file found for $sample, skipping"
    else
        run(Cmd([
            "humann_regroup_table", "--input", gf_file,
            "--output", ko_file,
            "--groups", "uniref90_ko"
        ]))
    end

    if isfile(pfam_file)
        @info "pfams regrouped file found for $sample, skipping"
    else
        run(Cmd([
            "humann_regroup_table", "--input", gf_file,
            "--output", pfam_file,
            "--groups", "uniref90_pfam"
        ]))
    end

    if isfile(ec_file)
        @info "ecs regrouped file found for $sample, skipping"
    else
        run(Cmd([
            "humann_regroup_table", "--input", gf_file,
            "--output", ec_file,
            "--groups", "uniref90_level4ec"
        ]))
    end

end

function run_humann_rename(sample, outdir)
    humanndir = abspath(outdir, "humann")
    for (t, n) in zip(("kos", "pfams", "ecs"), ("kegg-orthology", "pfam", "ec"))
        infile = joinpath(humanndir, "regroup", "$(sample)_$t.tsv") 
        outfile = joinpath(humanndir, "rename", "$(sample)_$(t)_rename.tsv")
        if isfile(outfile)
            @info "$t rename file found for $sample, skipping"
        else
            run(Cmd([
                "humann_rename_table", "--input", infile,
                "--output", outfile,
                "--names", n
                ]))
        end
    end

end

function main()
    args = parse_commandline()
    for sample in eachline(args["samples"])
        @info "Running $sample"
        run_knead(sample, args["input"], args["output"])
        catkneads = run_metaphlan(sample, args["input"], args["output"])
        run_humann(sample, args["input"], args["output"], catkneads)
        run_humann_regroup(sample, args["output"])
        run_humann_rename(sample, args["output"])
    end
end


main()
