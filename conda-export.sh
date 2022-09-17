#!/usr/bin/env bash
DOCOPT_PROGRAM_VERSION="1.0"

DOC="
Conda Export.

Usage:
  conda-export.sh [options] [ -- <env_export_options>... ]

Options:
  -h, --help                               Show this help message
  -v, --version                                Show version
  -e <yml file>, --env_pth <yml file>      Path to exported env file. [default: environment.yml]

"
DOCOPT_PREFIX=ARG

. ./parse_opts.sh
# eval "$(docopt.sh --parser "$0")"

eval "$(docopt "$@")"

# echo "@: $@"
# echo "--: $__"
# echo "export_options: ${ARG_env_export_options_[@]}"
# echo "Env: $ARG__env_pth"

if [[ -z "${CONDA_DEFAULT_ENV}" ]]; then
    echo "No conda environment active"
    exit 1
fi

conda env export "${ARG_env_export_options_[@]}" >"${ARG__env_pth}"
