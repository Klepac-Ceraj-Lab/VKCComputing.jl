using ArgParse

function parse_commandline()
    s = ArgParseSettings()

    @add_arg_table! s begin
        "--input", "-i"
            help = "File with biospecimen IDs to be included"
            default = "./biospecimens.csv"
        "--directory", "-d"
            help = "Directory for output files"
            default = "./"
        "--prefix"
            help = "Prefix to add to output files. Default is to use 'prep' and 'submission'"
            default = ""

        # "--flag1"
        #     help = "an option without argument, i.e. a flag"
        #     action = :store_true
        # "arg1"
        #     help = "a positional argument"
        #     required = true
        "samples"
            help = "text file containing sample list"
    end
end

function main()
    args = parse_commandline()

end


main()
