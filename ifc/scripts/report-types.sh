#!/bin/sh

# Collect type names from geom-types.txt
# Mark them as implemented or not
# Lines look like: IFCTYPE, #IFCTYPE, IFCTYPE,Note...

implemented_list=$(grep -v '^#' geom-types.txt | sed 's/,.*//')
not_implemented_list=$(grep '^#' geom-types.txt | sed 's/^#//' | sed 's/,.*//')

# Prepare blocks
echo "=== Implemented Types ==="
while IFS= read -r type; do
  grep -E "\b$type\$" type-counts.txt
done <<EOF | sort -nr
$implemented_list
EOF

echo
echo "=== Not Yet Implemented Types ==="
while IFS= read -r type; do
  grep -E "\b$type\$" type-counts.txt
done <<EOF | sort -nr
$not_implemented_list
EOF
