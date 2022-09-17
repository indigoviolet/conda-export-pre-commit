# shellcheck disable=2016,1075,2154
docopt() {
    parse() {
        if ${DOCOPT_DOC_CHECK:-true}; then
            local doc_hash
            if doc_hash=$(printf "%s" "$DOC" | (sha256sum 2>/dev/null || shasum -a 256)); then
                if [[ ${doc_hash:0:5} != "$digest" ]]; then
                    stderr "The current usage doc (${doc_hash:0:5}) does not match \
what the parser was generated with (${digest})
Run \`docopt.sh\` to refresh the parser."
                    _return 70
                fi
            fi
        fi
        local root_idx=$1
        shift
        argv=("$@")
        parsed_params=()
        parsed_values=()
        left=()
        testdepth=0
        local arg
        while [[ ${#argv[@]} -gt 0 ]]; do
            if [[ ${argv[0]} = "--" ]]; then
                for arg in "${argv[@]}"; do
                    parsed_params+=('a')
                    parsed_values+=("$arg")
                done
                break
            elif [[ ${argv[0]} = --* ]]; then
                parse_long
            elif [[ ${argv[0]} = -* && ${argv[0]} != "-" ]]; then
                parse_shorts
            elif ${DOCOPT_OPTIONS_FIRST:-false}; then
                for arg in "${argv[@]}"; do
                    parsed_params+=('a')
                    parsed_values+=("$arg")
                done
                break
            else
                parsed_params+=('a')
                parsed_values+=("${argv[0]}")
                argv=("${argv[@]:1}")
            fi
        done
        local idx
        if ${DOCOPT_ADD_HELP:-true}; then
            for idx in "${parsed_params[@]}"; do
                [[ $idx = 'a' ]] && continue
                if [[ ${shorts[$idx]} = "-h" || ${longs[$idx]} = "--help" ]]; then
                    stdout "$trimmed_doc"
                    _return 0
                fi
            done
        fi
        if [[ ${DOCOPT_PROGRAM_VERSION:-false} != 'false' ]]; then
            for idx in "${parsed_params[@]}"; do
                [[ $idx = 'a' ]] && continue
                if [[ ${longs[$idx]} = "--version" ]]; then
                    stdout "$DOCOPT_PROGRAM_VERSION"
                    _return 0
                fi
            done
        fi
        local i=0
        while [[ $i -lt ${#parsed_params[@]} ]]; do
            left+=("$i")
            ((i++)) || true
        done
        if ! required "$root_idx" || [ ${#left[@]} -gt 0 ]; then error; fi
        return 0
    }
    parse_shorts() {
        local token=${argv[0]}
        local value
        argv=("${argv[@]:1}")
        [[ $token = -* && $token != --* ]] || _return 88
        local remaining=${token#-}
        while [[ -n $remaining ]]; do
            local short="-${remaining:0:1}"
            remaining="${remaining:1}"
            local i=0
            local similar=()
            local match=false
            for o in "${shorts[@]}"; do
                if [[ $o = "$short" ]]; then
                    similar+=("$short")
                    [[ $match = false ]] && match=$i
                fi
                ((i++)) || true
            done
            if [[ ${#similar[@]} -gt 1 ]]; then
                error "${short} is specified ambiguously ${#similar[@]} times"
            elif [[ ${#similar[@]} -lt 1 ]]; then
                match=${#shorts[@]}
                value=true
                shorts+=("$short")
                longs+=('')
                argcounts+=(0)
            else
                value=false
                if [[ ${argcounts[$match]} -ne 0 ]]; then if [[ $remaining = '' ]]; then
                    if [[ ${#argv[@]} -eq 0 || ${argv[0]} = '--' ]]; then
                        error "${short} requires argument"
                    fi
                    value=${argv[0]}
                    argv=("${argv[@]:1}")
                else
                    value=$remaining
                    remaining=''
                fi; fi
                if [[ $value = false ]]; then
                    value=true
                fi
            fi
            parsed_params+=("$match")
            parsed_values+=("$value")
        done
    }
    parse_long() {
        local token=${argv[0]}
        local long=${token%%=*}
        local value=${token#*=}
        local argcount
        argv=("${argv[@]:1}")
        [[ $token = --* ]] || _return 88
        if [[ $token = *=* ]]; then eq='='; else
            eq=''
            value=false
        fi
        local i=0
        local similar=()
        local match=false
        for o in "${longs[@]}"; do
            if [[ $o = "$long" ]]; then
                similar+=("$long")
                [[ $match = false ]] && match=$i
            fi
            ((i++)) || true
        done
        if [[ $match = false ]]; then
            i=0
            for o in "${longs[@]}"; do
                if [[ $o = $long* ]]; then
                    similar+=("$long")
                    [[ $match = false ]] && match=$i
                fi
                ((i++)) || true
            done
        fi
        if [[ ${#similar[@]} -gt 1 ]]; then
            error "${long} is not a unique prefix: ${similar[*]}?"
        elif [[ ${#similar[@]} -lt 1 ]]; then
            [[ $eq = '=' ]] && argcount=1 || argcount=0
            match=${#shorts[@]}
            [[ $argcount -eq 0 ]] && value=true
            shorts+=('')
            longs+=("$long")
            argcounts+=("$argcount")
        else
            if [[ ${argcounts[$match]} -eq 0 ]]; then
                if [[ $value != false ]]; then
                    error "${longs[$match]} must not have an argument"
                fi
            elif [[ $value = false ]]; then
                if [[ ${#argv[@]} -eq 0 || ${argv[0]} = '--' ]]; then
                    error "${long} requires argument"
                fi
                value=${argv[0]}
                argv=("${argv[@]:1}")
            fi
            if [[ $value = false ]]; then value=true; fi
        fi
        parsed_params+=("$match")
        parsed_values+=("$value")
    }
    required() {
        local initial_left=("${left[@]}")
        local node_idx
        ((testdepth++)) || true
        for node_idx in "$@"; do
            if ! "node_$node_idx"; then
                left=("${initial_left[@]}")
                ((testdepth--)) || true
                return 1
            fi
        done
        if [[ $((--testdepth)) -eq 0 ]]; then
            left=("${initial_left[@]}")
            for node_idx in "$@"; do "node_$node_idx"; done
        fi
        return 0
    }
    optional() {
        local node_idx
        for node_idx in "$@"; do
            "node_$node_idx"
        done
        return 0
    }
    oneormore() {
        local i=0
        local prev=${#left[@]}
        while "node_$1"; do
            ((i++)) || true
            [[ $prev -eq ${#left[@]} ]] && break
            prev=${#left[@]}
        done
        if [[ $i -ge 1 ]]; then return 0; fi
        return 1
    }
    _command() {
        local i
        local name=${2:-$1}
        for i in "${!left[@]}"; do
            local l=${left[$i]}
            if [[ ${parsed_params[$l]} = 'a' ]]; then
                if [[ ${parsed_values[$l]} != "$name" ]]; then return 1; fi
                left=("${left[@]:0:$i}" "${left[@]:((i + 1))}")
                [[ $testdepth -gt 0 ]] && return 0
                if [[ $3 = true ]]; then
                    eval "((var_$1++)) || true"
                else eval "var_$1=true"; fi
                return 0
            fi
        done
        return 1
    }
    switch() {
        local i
        for i in "${!left[@]}"; do
            local l=${left[$i]}
            if [[ ${parsed_params[$l]} = "$2" ]]; then
                left=("${left[@]:0:$i}" "${left[@]:((i + 1))}")
                [[ $testdepth -gt 0 ]] && return 0
                if [[ $3 = true ]]; then
                    eval "((var_$1++))" || true
                else eval "var_$1=true"; fi
                return 0
            fi
        done
        return 1
    }
    value() {
        local i
        for i in "${!left[@]}"; do
            local l=${left[$i]}
            if [[ ${parsed_params[$l]} = "$2" ]]; then
                left=("${left[@]:0:$i}" "${left[@]:((i + 1))}")
                [[ $testdepth -gt 0 ]] && return 0
                local value
                value=$(printf -- "%q" "${parsed_values[$l]}")
                if [[ $3 = true ]]; then
                    eval "var_$1+=($value)"
                else eval "var_$1=$value"; fi
                return 0
            fi
        done
        return 1
    }
    stdout() { printf -- "cat <<'EOM'\n%s\nEOM\n" "$1"; }
    stderr() {
        printf -- "cat <<'EOM' >&2\n%s\nEOM\n" "$1"
    }
    error() {
        [[ -n $1 ]] && stderr "$1"
        stderr "$usage"
        _return 1
    }
    _return() {
        printf -- "exit %d\n" "$1"
        exit "$1"
    }
    set -e
    trimmed_doc=${DOC:1:313}
    usage=${DOC:16:65}
    digest=893ff
    shorts=(-e -v -h)
    longs=(--env_pth --version --help)
    argcounts=(1 0 0)
    node_0() {
        value __env_pth 0
    }
    node_1() { switch __version 1; }
    node_2() {
        switch __help 2
    }
    node_3() { value _env_export_options_ a true; }
    node_4() { _command __ --; }
    node_5() { optional 0 1 2; }
    node_6() { optional 5; }
    node_7() { oneormore 3; }
    node_8() { optional 4 7; }
    node_9() { required 6 8; }
    node_10() { required 9; }
    cat <<<' docopt_exit() { [[ -n $1 ]] && printf "%s\n" "$1" >&2
printf "%s\n" "${DOC:16:65}" >&2; exit 1; }'
    unset var___env_pth \
        var___version var___help var__env_export_options_ var___
    parse 10 "$@"
    local prefix=${DOCOPT_PREFIX:-''}
    unset "${prefix}__env_pth" \
        "${prefix}__version" "${prefix}__help" "${prefix}_env_export_options_" \
        "${prefix}__"
    eval "${prefix}"'__env_pth=${var___env_pth:-environment.yml}'
    eval "${prefix}"'__version=${var___version:-false}'
    eval "${prefix}"'__help=${var___help:-false}'
    if declare -p var__env_export_options_ >/dev/null 2>&1; then
        eval "${prefix}"'_env_export_options_=("${var__env_export_options_[@]}")'
    else
        eval "${prefix}"'_env_export_options_=()'
    fi
    eval "${prefix}"'__=${var___:-false}'
    local docopt_i=1
    [[ $BASH_VERSION =~ ^4.3 ]] && docopt_i=2
    for (( ; docopt_i > 0; docopt_i--)); do
        declare -p "${prefix}__env_pth" "${prefix}__version" "${prefix}__help" \
            "${prefix}_env_export_options_" "${prefix}__"
    done
}