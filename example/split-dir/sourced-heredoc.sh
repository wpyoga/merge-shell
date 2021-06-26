#!/bin/sh

cat <<EOF
here-doc 1
EOF

cat <<-EOF
here-doc 2
EOF

cat <<-' EOF'
here-doc 3
 EOF
