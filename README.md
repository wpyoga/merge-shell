# merge-shell

This utility merges modular shell scripts into one big shell script for easy distribution. The merged shell script is a singular shell script that can be streamed using `curl` and executed directly by `sh`, like this:

```console
$ curl https://example.com/script.sh | sh
```

## Overview

Too often, we see shell script projects having one big shell script that everyone edits. This may cause quite a few problems:

- accidental keystrokes changing unintended parts of the script go unnoticed, especially when the changeset is quite large
- developers having to navigate a big shell script just to find and edit a section of the code
- new developers struggle to understand the code because of lack of modularity

In contrast, projects written in other languages (including scripting languages that are not shell scripts) are often written in a modular way.

I've read about another approach to merge modular shell scripts into one big shell script, using a compressed archive inside the script, which is then extracted when the script is run. I remember that it was hosted on GitHub -- however, after searching for a few days, I still couldn't find the project. Please let me know if you have information about that project.

## Mechanism

This utility takes a single shell script as its argument, and parses it. Whenever it encounters a line that looks like

```sh
# @MERGE
```

it will go into `MERGE` mode (we call this a `MERGE` line). In this mode, a source line that looks like

```sh
. script.sh
```

will be merged into the main script.

This utility will exit `MERGE` mode once it sees a line that does not conform to the source line pattern. Note that the sourced script must end in `.sh` for the line to be recognized.

After completing a pass, this utility will look for a `MERGE` line inside the script, and repeat the above actions if it finds any such lines. Note that `MERGE` lines found in here-documents and multi-line strings will be recognized as regular `MERGE` lines, so try to escape those lines a bit if you don't want them to be recognized as `MERGE` lines.

## Script Indentation

The `MERGE` line can actually conform to this regular expression:

```re
^# @MERGE ([st] [0-9]+)?$
```

If the `s` or `t` option is specified, it means that in the current `MERGE` mode, sourced scripts need to be indented:

- `s`: with the specified number of spaces
- `t`: with the specified number of tabs

This feature is only offered for aesthetic purposes, and to increase readability of the merged script. However, it can cause problems with here-documents and multi-line strings, so **avoid using this feature if possible**.

Notes on here-documents:

- this utility tries to recognize here-documents and avoids indenting those sections
- the pattern recognition is rudimentary, and may not work correctly with specialized here-document patterns
- always check the merged script if you are not sure

Notes on multi-line strings:

- this utility is unable to recognize multi-line strings and avoid indenting them -- such pattern recognition seems too complicated to implement
- try to avoid using multi-line strings if you intend to indent the script, and **never indent merged files if you have to use multi-line strings**
    - multi-line strings are usually util for script output to a document, or for an awk/sed script -- these can be done using here-documents
- if you have use multi-line strings, then either
    - don't indent the merged script, or
    - split off the multi-line string into its own merged script file, which you can then merge without indentation

## Alternative Implemention(s)

It might be a good idea to reimplement this using Python, what do you think?
