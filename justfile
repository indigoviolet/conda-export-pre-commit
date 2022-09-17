default: update-parser

update-parser:
    docopt.sh conda-export.sh -p  | shfmt > parse-opts.sh
