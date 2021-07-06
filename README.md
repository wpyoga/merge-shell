# merge-shell

This utility merges modular shell scripts into one big shell script for easy distribution. The merged shell script is a singular shell script that can be streamed using `curl` and executed directly by `sh`, like this:

```console
$ curl https://example.com/script.sh | sh
```

I have set up a few forked repositories to showcase `merge-shell` functionality:

- https://github.com/wpyoga/openvpn-install

  No problems observed so far.

- https://github.com/wpyoga/wireguard-install

  No problems observed so far.

- https://github.com/wpyoga/dehydrated

  `dehydrated` generates help text by grepping the original script. Unfortunately, the information is buried inside the sub-scripts. With our current method of splitting the main script, `dehydrated-split` cannot display the help text properly. The merged script can display the help text properly.

## Overview

Too often, we see shell script projects having one big shell script that everyone edits. This may cause quite a few problems:

- accidental keystrokes changing unintended parts of the script go unnoticed, especially when the changeset is quite large
- developers having to navigate a big shell script just to find and edit a section of the code
- new developers struggle to understand the code because of lack of modularity

In contrast, projects written in other languages (including scripting languages that are not shell scripts) are often written in a modular way.

I've read about another approach to merge modular shell scripts into one big shell script, using a compressed archive inside the script, which is then extracted when the script is run. I remember that it was hosted on GitHub -- however, after searching for a few days, I still couldn't find the project. Please let me know if you have information about that project.

## Mechanism

`merge-shell` takes a single shell script as its argument, parses it, and prints the merged script to stdout. It works based on annotations inside comments, so that the split scripts are still valid shell scripts, and can work just like the merged script.

Depending on the annotation, `merge-shell` will enter different modes as described below. The `MERGE` mode merges sub-scripts into the main script, while the `HEREDOC` and `MULTILINE` modes maintain proper indentation for here-documents and multi-line strings, respectively. The `HEREDOC` and `MULTILINE` modes exist so that we don't need to parse shell syntax to recognize here-documents and multi-line strings.

Please let me know if you see any other shell constructs that need their own custom annotations.

### `@MERGE`

`@MERGE` means that the following dot line is to be merged into the main script. The merging is done recursively, and the indentation is carried over, meaning that the sourced file will be indented just like the dot line.

The `@MERGE` annotation should match this regex:

```regexp
^\s*#\s*@MERGE\s*$
```

The dot line should match this regex:

```regexp
^\s*\.\s+[a-zA-Z0-9_\.][a-zA-Z0-9_\.\-]+\s*$
```

If the next line does not match the regex, then it will be treated as any other line.

Usage:

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
- Outside of `MERGE` mode, sourced files are not merged into the script. This allows you to still use `source` or `.` or `dot` to read in config files, without change in semantics.

### `@HEREDOC` and `@HEREDOC-END`

This mode encapsulates all here-documents in the shell script. Without this mode, here-documents will be indented, so that the here-document will indented by mistake, and the ending line may not be recognized properly.

This mode starts when a line matches this regex:

```regexp
^\s*#\s*@HEREDOC\s*$
```

And ends at the end of the script, or when a line matches this regex:

```regexp
^\s*#\s*@HEREDOC-END\s*$
```

In this mode, the first line is merged into the main script, recursively indented according to the source line indentation. All other lines are not indented at all, but any existing indentation is copied as-is.

Usage:

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

This mode encapsulates all multi-line strings in the shell script. Without this mode, multi-line strings will be indented, so the content will be intended by mistake. This mode functions exactly like `HEREDOC` mode described above, but with a different annotation.

This mode starts when a line matches this regex:

```regexp
^\s*#\s*@MULTILINE\s*$
```

And ends at the end of the script, or when a line matches this regex:

```regexp
^\s*#\s*@MULTILINE-END\s*$
```

Usage:

```sh
    # @MULTILINE
    echo '
# ip config
ip 192.168.0.105
netmask 255.255.255.0' >ip-set.conf
    # @MULTILINE-END
```

## Alternative Implemention(s)

It might be a good idea to reimplement this using Python.

## TODO

The code works, but it is complicated and messy -- it needs to be refactored.
