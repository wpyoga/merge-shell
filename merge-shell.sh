#!/bin/sh

VERSION=0.2

if [ $# != 1 ]; then
    cat <<EOF
usage: $0 <shell_script>
version: ${VERSION}

merge the specified shell script with its sub-scripts

scripts sourced immediately after a '# @MERGE' comment are merged, producing
one easily-deployable big script

if the '# @MERGE' line ends with 's' or 't' and then a number, the merged files
are indented

this allows for modular shell script development:
- no need to open up a big script just to edit some small thing
- sub-scripts can be organized into directories
- script behaves (almost) exactly the same during development (without merging)
  and after deployment / installation (after being merged and deployed)

notes on merged script:
- shebang and the empty line after it will be removed from sourced script
- only the first empty line after the shebang will be removed

notes on indentation:
- indentation is only for aesthetic purposes, avoid if possible
- this script tries to recognize here-documents and avoids indenting them,
  but the pattern recognition is rudimentary and may not work correctly with
  specialized here-document patterns -- always check the output if unsure
- when indenting merged files, multiline strings are always indented:
  - try to avoid multiline strings whenever possible, and
  - never indent merged files if you have to use multiline strings
  - alternatively, you can split off the multiline string into its own file,
    and then merge it without indentation
EOF
    exit 1
fi

TMPFILE="$(mktemp)"
TMPFILE2="$(mktemp)"

cat "$1" >"${TMPFILE}"

# check for '# @MERGE' lines: '^# @MERGE$'
# also accept merge marker lines with indentation option like '# @MERGE s 4' (indent with 4 spaces) or '# @MERGE t 1' (indent with 1 tab)
# after each such line, look for the first line that is not sourcing other scripts: '^\. .*\.sh$'
# get the group of lines that source other scripts, and replace them with the sourced scripts
# repeat the above if there are still merge lines in the script

while grep -qE '^# @MERGE( (s|t) [0-9]+)?$' "${TMPFILE}"; do
    MERGE=false
    INDENT=0
    true >"${TMPFILE2}"
    while IFS= read -r LINE; do
        if printf %s "${LINE}" | grep -qE '^# @MERGE$'; then
            MERGE=true
            INDENT=0
        elif printf %s "${LINE}" | grep -qE '^# @MERGE (s|t) [0-9]+$'; then
            MERGE=true
            INDENT="$(printf %s "${LINE}" | sed 's/^# @MERGE \([st]\) \([0-9]\{1,\}\)$/\2/')"
            INDENT_TYPE="$(printf %s "${LINE}" | sed 's/^# @MERGE \([st]\) \([0-9]\{1,\}\)$/\1/')"
        elif ${MERGE} && test "${LINE}" != "${LINE#. }" && test "${LINE}" != "${LINE%.sh}"; then
            SCRIPT_TO_MERGE="${LINE#. }"

            SKIP_LINES=0
            (head -n 1 "${SCRIPT_TO_MERGE}" | grep -q '^#!') && SKIP_LINES=1
            test ${SKIP_LINES} -eq 1 && (head -n 2 "${SCRIPT_TO_MERGE}" | tail -n 1 | grep -q '^$') && SKIP_LINES=2

            if test "${INDENT}" -eq 0; then
                tail -n +$((SKIP_LINES + 1)) "${SCRIPT_TO_MERGE}" >>"${TMPFILE2}"
            else
                if test "${INDENT_TYPE}" = 's'; then
                    INDENT_CHARS="$(printf %"${INDENT}"s ' ')"
                else # must be tabs
                    INDENT_CHARS="$(printf %"${INDENT}"s ' ' | tr ' ' '\t')"
                fi

                HEREDOC=false
                MERGE_SCRIPT_MERGE_LINE=false
                tail -n +$((SKIP_LINES + 1)) "${SCRIPT_TO_MERGE}" | while IFS= read -r MERGE_SCRIPT_LINE; do
                    if "${HEREDOC}"; then
                        printf "%s\n" "${MERGE_SCRIPT_LINE}" >>"${TMPFILE2}"

                        if "${HEREDOC_INDENTED}" && printf %s "${MERGE_SCRIPT_LINE}" | grep -q "^$(printf '\t*')${HEREDOC_END}"; then
                            HEREDOC=false
                        elif ! "${HEREDOC_INDENTED}" && test "${HEREDOC_END}" = "${MERGE_SCRIPT_LINE}"; then
                            HEREDOC=false
                        fi
                    else
                        if printf %s "${MERGE_SCRIPT_LINE}" | grep -qE '^# @MERGE( [st] [0-9]+)?$'; then
                            MERGE_SCRIPT_MERGE_LINE=true
                            printf '%s\n' "${MERGE_SCRIPT_LINE}" >>"${TMPFILE2}"
                        elif "${MERGE_SCRIPT_MERGE_LINE}" && test "${MERGE_SCRIPT_LINE}" != "${MERGE_SCRIPT_LINE#. }" && test "${MERGE_SCRIPT_LINE}" != "${MERGE_SCRIPT_LINE%.sh}"; then
                            printf '%s\n' "${MERGE_SCRIPT_LINE}" >>"${TMPFILE2}"
                        elif test -n "${MERGE_SCRIPT_LINE}"; then
                            MERGE_SCRIPT_MERGE_LINE=false
                            printf "${INDENT_CHARS}%s\n" "${MERGE_SCRIPT_LINE}" >>"${TMPFILE2}"
                        else
                            MERGE_SCRIPT_MERGE_LINE=false
                            echo >>"${TMPFILE2}"
                        fi

                        if printf %s "${MERGE_SCRIPT_LINE%%#*}" | grep -qE '^(.*[^<>])?<<[^<>]'; then
                            HEREDOC=true
                            HEREDOC_INDENTED=false
                        elif printf %s "${MERGE_SCRIPT_LINE%%#*}" | grep -qE '(.*[^<>])?<<-[^<>]'; then
                            HEREDOC=true
                            HEREDOC_INDENTED=true
                        fi
                        "${HEREDOC}" && HEREDOC_END="$(printf %s\\n "${MERGE_SCRIPT_LINE%% #*}" | sed -e 's/.*[^<>]*<<-\{0,1\}\([^<>]\)/\1/' -e 's,^ *,,' -e 's, *$,,' -e s,^[\'\"],, -e s,[\'\"]$,,)"
                    fi
                done

                # if test "${INDENT_TYPE}" = 's'; then
                #     tail -n +$((SKIP_LINES + 1)) "${SCRIPT_TO_MERGE}" | sed "s,^,$(printf %${INDENT}s ' ')," >>"${TMPFILE2}"
                # else
                #     tail -n +$((SKIP_LINES + 1)) "${SCRIPT_TO_MERGE}" | sed "s,^,$(printf %${INDENT}s ' ' | tr ' ' '\t')," >>"${TMPFILE2}"
                # fi
            fi
        else
            MERGE=false
            printf '%s\n' "${LINE}" >>"${TMPFILE2}"
        fi
    done <"${TMPFILE}"
    cat "${TMPFILE2}" >"${TMPFILE}"
done

cat "${TMPFILE}"

rm "${TMPFILE}"
rm "${TMPFILE2}"
