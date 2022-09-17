#!/usr/bin/env bash

DOCOPT_PROGRAM_VERSION="1.0"

DOC="
Conda Export.

Usage:
  conda-export.sh [options] [ -- <export_options>... ]

Options:
  -h, --help                               Show this help message
  -v, --version                            Show version
  -d <dir>, --dir <dir>                    Execute in directory
  -e <yml file>, --env_pth <yml file>      Path to exported env file. [default: environment.yml]
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
    echo "--dir: $ARG__dir"
    echo "--env_pth: $ARG__env_pth"
    echo "--pass-if-modified: $ARG__pass_if_modified"
    set -x
fi

if [[ -n "${ARG__dir}" ]]; then
    cd "${ARG__dir}"
fi

if [[ -z "${CONDA_DEFAULT_ENV:-}" ]]; then
    echo "No active conda environment."
    exit 1
fi

conda env export --file "${ARG__env_pth}" "${ARG_export_options_[@]}"

if [[ "${ARG__pass_if_modified}" == "true" ]]; then
    exit 0
fi

(git ls-files --error-unmatch "${ARG__env_pth}" && git diff --exit-code "${ARG__env_pth}") 2>/dev/null
