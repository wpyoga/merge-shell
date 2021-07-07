#!/bin/sh

VERSION=0.2.1

# our annotations only support ASCII
# the dot lines only support ASCII as well
export LC_ALL=C

if [ $# != 1 ]; then
    cat <<EOF
usage: $0 <shell_script>
version: ${VERSION}

merge the specified shell script with its sub-scripts

scripts sourced immediately after a '# @MERGE' comment are merged, producing
one easily-deployable big script

this allows for modular shell script development:
- no need to open up a big script just to edit some small thing
- sub-scripts can be organized into directories
- script behaves (almost) exactly the same during development (without merging)
  and after deployment / installation (after being merged and deployed)

notes on merged script:
- shebang and the empty line after it will be removed from sourced script
- the first empty line after the shebang will be removed

more annotations are available:
- @HEREDOC and @HEREDOC-END to wrap a here-document
- @MULTILINE and @MULTILINE-END to wrap a multi-line string
EOF
    exit 1
fi

mergeshell() {
    if [ "$3" -eq 0 ]; then
        CHECK_SHEBANG=false
        CHECK_EMPTY_LINE=false
    else
        CHECK_SHEBANG=true
        CHECK_EMPTY_LINE=false
    fi

    if [ "`tail -c 1 "$1"`" != "`printf '\n'`" ]; then
        echo "Warning: input file $1: no newline at end of file, last line in file will not be recognized" >&2
    fi

    MERGE=false
    HEREDOC=false
    MULTILINE=false
    while IFS= read -r LINE; do
        if "${CHECK_SHEBANG}" && expr "${LINE}" : '^#!.*$' >/dev/null; then
            CHECK_SHEBANG=false
            CHECK_EMPTY_LINE=true
        elif "${CHECK_EMPTY_LINE}" && [ -z "${LINE}" ]; then
            CHECK_EMPTY_LINE=false
        else
            CHECK_SHEBANG=false
            CHECK_EMPTY_LINE=false
            ANNOTATION="$(expr "${LINE}" : '^[[:space:]]*#[[:space:]]\{1,\}@\(MERGE\|HEREDOC\|HEREDOC-END\|MULTILINE\|MULTILINE-END\)[[:space:]]*$')"

            if [ "${ANNOTATION}" = 'HEREDOC-END' ]; then
                MERGE=false
                HEREDOC=false
            elif [ "${ANNOTATION}" = 'MULTILINE-END' ]; then
                MERGE=false
                MULTILINE=false
            elif "${HEREDOC}"; then
                MERGE=false
                printf '%s%s\n' "${HEREDOC_INDENT}" "${LINE}"
                HEREDOC_INDENT=
            elif "${MULTILINE}"; then
                MERGE=false
                printf '%s%s\n' "${MULTILINE_INDENT}" "${LINE}"
                MULTILINE_INDENT=
            elif [ "${ANNOTATION}" = 'MERGE' ]; then
                MERGE=true
            elif "${MERGE}" && FILE="$(expr "${LINE}" : '^[[:space:]]*\.[[:space:]]\{1,\}\([[:alnum:]/_\.][[:alnum:]/_\.\-]\{1,\}\)[[:space:]]*$')"; then
                MERGE=false
                export FILE
                export INDENT="$2""$(expr "${LINE}" : '^\([[:space:]]*\)\..*$')"
                export LEVEL=$(($3 + 1))
                (mergeshell "${FILE}" "${INDENT}" "${LEVEL}")
            elif [ "${ANNOTATION}" = 'HEREDOC' ]; then
                MERGE=false
                HEREDOC=true
                HEREDOC_INDENT="$2"
            elif [ "${ANNOTATION}" = 'MULTILINE' ]; then
                MERGE=false
                MULTILINE=true
                MULTILINE_INDENT="$2"
            elif [ -z "${LINE}" ]; then
                MERGE=false
                echo
            else
                MERGE=false
                printf '%s%s\n' "$2" "${LINE}"
            fi
        fi
    done <"$1"

    true
}

(mergeshell "$1" '' 0)
