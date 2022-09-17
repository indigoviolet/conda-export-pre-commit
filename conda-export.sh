#!/usr/bin/env bash

DOCOPT_PROGRAM_VERSION="1.0"

DOC="
Conda Export.

Usage:
  conda-export.sh [options] [ -- <export_options>... ]

Options:
  -h, --help                               Show this help message
  -v, --version                            Show version
  -f <yml file>, --file <yml file>         Path to exported env file. [default: environment.yml]
  -e <env>, --env <env>                    Conda env to activate
  -p, --pass-if-modified                   Pass hook even if it modified the yml file
  --debug                                  Debug [default: false]

<export_options> specified after -- are passed through to 'conda env export'.

"
DOCOPT_PREFIX=ARG

SCRIPT_DIR="$(dirname "$(realpath "$0")")"
. "$SCRIPT_DIR"/parse-opts.sh
# eval "$(docopt.sh --parser "$0")"

eval "$(docopt "$@")"

set -euo pipefail

if [[ "${ARG__debug}" == "true" ]]; then
    echo "@: $@"
    echo "--debug: $ARG__debug"
    echo "--: $ARG__"
    echo "export_options: ${ARG_export_options_[@]}"
    echo "--env: $ARG__env"
    echo "--file: $ARG__file"
    echo "--pass-if-modified: $ARG__pass_if_modified"
    set -x
fi

if [[ -n "${ARG__env}" ]]; then
    source "$(conda info --base)"/etc/profile.d/conda.sh
    conda activate "${ARG__env}"
fi

if [[ -z "${CONDA_DEFAULT_ENV:-}" ]]; then
    echo "No active conda environment."
    exit 1
fi

conda env export --file "${ARG__file}" "${ARG_export_options_[@]}"

if [[ "${ARG__pass_if_modified}" == "true" ]]; then
    exit 0
fi

(git ls-files --error-unmatch "${ARG__file}" && git diff --exit-code "${ARG__file}") 2>/dev/null
