#!/bin/sh

# @HEREDOC
cat <<EOF
here-doc 1
EOF
# @HEREDOC-END

# @HEREDOC
cat <<-EOF
here-doc 2
EOF
# @HEREDOC-END

# @HEREDOC
cat <<-' EOF'
here-doc 3
 EOF
# @HEREDOC-END
