default: update-parser

update-parser:
    docopt.sh conda-export.sh -p > parse-opts.sh
    shfmt -w parse-opts.sh parse-opts.sh
