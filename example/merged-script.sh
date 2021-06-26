#!/bin/sh

echo group1-1

echo group1-2

echo group1-3


echo group2-1
echo group2-2
echo group2-3


    cat <<EOF
here-doc 1
EOF

    cat <<-EOF
here-doc 2
EOF

    cat <<-' EOF'
here-doc 3
 EOF

	cat <<EOF
here-doc 4
EOF


echo group3-1
echo group3-2
echo group3-3

