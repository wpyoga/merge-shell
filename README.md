# merge-shell

This utility merges modular shell scripts into one big shell script for easy distribution. The merged shell script is a singular shell script that can be streamed using `curl` and executed directly by `sh`, like this:

```console
$ curl https://example.com/script.sh | sh
```

I have set up a few forked repositories to showcase `merge-shell` functionality:

- https://github.com/wpyoga/openvpn-install/tree/faithful-fork

  No problems observed so far.

- https://github.com/wpyoga/wireguard-install/tree/faithful-fork

  No problems observed so far.

- https://github.com/wpyoga/dehydrated/tree/faithful-fork

  `dehydrated` generates help text by grepping the original script. Unfortunately, the information is buried inside the sub-scripts. With our current method of splitting the main script, `dehydrated-split` cannot display the help text properly. The merged script can display the help text properly.

- https://github.com/wpyoga/LemonBench/tree/faithful-fork

  No problems observed so far, but see [Caveats](#caveats) below. The original `LemonBench.sh` script does not have a trailing newline, so in this faithful reproduction we added a trailing newline to `LemonBench-split.sh`, which is then stripped off from the generated `LemonBench-merged.sh`.

  In general, if it finds an input file with no trailing newline, `merge-shell` will print a warning to stderr. Heed this warning, because the output file will be unusable, due to the last line being unreadable.

- https://github.com/wpyoga/nvm/tree/faithful-fork

  No problems observed so far.

- https://github.com/wpyoga/yet-another-bench-script/tree/faithful-fork

  No problems observed so far.

- https://github.com/wpyoga/rustup/tree/faithful-fork

  No problems observed so far.

## Overview

Sometimes, shell utilities are developed in a monolithic manner, with a big script containing all the code to the project. It's understandable that some developers have chosen this development pattern, because it's easier to distribute a single shell script, rather than multiple files. A user can simply use a one-liner like this to execute the script directly:

```console
$ curl https://github.com/wpyoga/script-example/my_script.sh | sh
```

The shell script can be very long, sometimes reaching thousands of lines in a single file. Functions are often interspersed with calling code. This kind of development pattern may cause a few problems:

- the code becomes difficult to reason about
- developers have to navigate a big shell script just to find and edit a section of the code
- as a result, it is difficult to maintain the code, so bug fixes and feature additions become slower over time
- it is often impossible to do unit tests
- another side effect is that new developers can sometimes struggle to understand the code, thus raising the bar for potential contributors
- during development, accidental keystrokes changing unintended parts of the script might go unnoticed, especially when the changeset is quite large -- leading to hard-to-find bugs

In contrast, projects written in other languages are often written in a modular way. Projects written in compiled languages (C, Java, Rust, ...) are most of the time modular, and even scripting languages like Python and JavaScript are usually written in a modular way. This really helps with the readability and maintainability of the code.

It's not impossible to develop shell scripts in a modular way, and I've actually read about another approach of self-extracting shell script. In that scenario, script components are packaged in a compressed tarball, which is then embedded as a base64-encoded string inside the script. When the script is run, it decodes the string and extracts the archive, the contents of which is then executed. I remember that it was hosted on GitHub -- however, after searching for a few days, I still couldn't find the project. Please let me know if you have information about that project.

## Mechanism

Our solution, `merge-shell` takes a single shell script as its argument, parses it, and prints the merged script to stdout. It works by parsing annotations inside comments, so that the split scripts are still valid shell scripts, and can work just like the merged script. This is useful during development, enabling the developer to test the script without merging them.

There are currently 3 defined annotations:

- `@MERGE` for merging sub-scripts into the main script
- `@HEREDOC` and `@HEREDOC-END` to maintain proper indentation for here-documents
- `@MULTILINE` and `@MULTILINE-END` to maintain proper indentation for multi-line strings, respectively

With `@HEREDOC` and `@MULTILINE` annotations, `merge-shell` does not need to parse shell syntax to recognize here-documents and multi-line strings.

Please let me know if you see any other shell constructs that need their own custom annotations.

### `@MERGE`

The `@MERGE` annotation means that the following dot line is to be merged into the main script. The merging is done recursively, and the indentation is carried over, so that the sourced file will be indented just like the dot line. The annotation itself is not carried over to the output script.

The `@MERGE` annotation should match this regex:

```regexp
^\s*#\s*@MERGE\s*$
```

The dot line should match this regex:

```regexp
^\s*\.\s+[a-zA-Z0-9_\.][a-zA-Z0-9_\.\-]+\s*$
```

If the next line does not match the regex, then it will be treated as any other line.

Example usage:

```sh
# @MERGE
. options.sh

if [ -f "/etc/myfile.conf" ]; then
    # @MERGE
    . load-custom.sh
fi
```

Notes:

- In this mode, `merge-shell` recursively merges each sourced script, recursively indented according to the source line indentation.
- For each sourced script, the shebang and one empty line immediately following the shebang are discarded.
- For simplicity, the sourced script file name can only consist of letters, numbers, underscore, dot, or dash. And it cannot start with a dash.
- If the `@MERGE` annotation is not specified, then the file will not be merged. This may be useful when sourcing config files at runtime.

### `@HEREDOC` and `@HEREDOC-END`

This annotation marks the start and end of a here-document. Between `@HEREDOC` and `@HEREDOC-END`, only the first line is indented, and all the other lines are not indented. Thus ensuring that the here-document contents are correct, and that the here-document EOF marker can be identified correctly.

The annotations should match these regexes:

```regexp
^\s*#\s*@HEREDOC\s*$
```

```regexp
^\s*#\s*@HEREDOC-END\s*$
```

Note that if the `@HEREDOC-END` annotation is not given, then the rest of the sub-script file is treated as a here-document, thus not indented at all.

Example usage:

```sh
    # @HEREDOC
    cat >custom.conf <<EOF
[default]
option1 = true
option2 = 2.5
EOF
    # @HEREDOC-END
```

Notes:

- Avoid having a line that matches the `HEREDOC-END` line inside the here-document, otherwise the `HEREDOC` mode will end prematurely, and the following lines will be indented, thus breaking the here-document syntax.

### `@MULTILINE` and `@MULTILINE-END`

This annotation has the same effect as `@HEREDOC` -- only the first line is indented. The annotation should match these regular expressions:

```regexp
^\s*#\s*@MULTILINE\s*$
```

```regexp
^\s*#\s*@MULTILINE-END\s*$
```

Example usage:

```sh
    # @MULTILINE
    echo '
# ip config
ip 192.168.0.105
netmask 255.255.255.0' >ip-set.conf
    # @MULTILINE-END
```

## Caveats

Files that don't have an ending newline won't be read properly. According to [POSIX](https://pubs.opengroup.org/onlinepubs/9699919799/basedefs/V1_chap03.html#tag_03_206):

> 3.206 Line
>
> A sequence of zero or more non- \<newline\> characters plus a terminating \<newline\> character.

If the last line does not have a terminating \<newline\> character, it won't be recognized as a line, thus `read` won't be able to read it, and will not be processed. The proper solution is to always have a terminating \<newline\>.

This problem is observed on files created using Windows. To avoid it, always add an extra newline at the end of source files, like this:

```txt
line 1
line 2
last line is an empty line

```

Instead of just this:

```txt
line 1
line 2
last line without extra newline
```

## Alternative Implemention(s)

It might be a good idea to reimplement this using Python.

## TODO

The code needs to be refactored.
