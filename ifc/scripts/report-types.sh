#!/bin/sh

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
GEOM_TYPES="$SCRIPT_DIR/geom-types-new.txt"

# Collect type names from $GEOM_TYPES
# Mark them as implemented or not
# Lines look like: IFCTYPE, #IFCTYPE, IFCTYPE,Note...

# New format: TYPE(,todo?)
implemented_list=$(grep -v ',todo' $GEOM_TYPES | sed 's/,.*//')
not_implemented_list=$(grep ',todo' $GEOM_TYPES | sed 's/,.*//')

# Old format: #?TYPE
#implemented_list=$(grep -v '^#' $GEOM_TYPES | sed 's/,.*//')
#not_implemented_list=$(grep '^#' $GEOM_TYPES | sed 's/^#//' | sed 's/,.*//')

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
