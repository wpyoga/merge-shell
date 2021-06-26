#!/bin/sh

# @MERGE
. split-dir/sourced1.sh


# @MERGE
. split-dir/sourced2.sh


# @MERGE s 4
. split-dir/sourced-heredoc.sh

# @MERGE t 1
. split-dir/sourced-heredoc-tab.sh


# @MERGE
. split-dir/sourced3.sh

