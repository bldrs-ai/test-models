#!/bin/sh

if [ -z "$1" ]; then
  echo "Usage: report-types.sh [geom-types.txt]" >&2
  exit 1
fi

GEOM_TYPES=$1

# Collect type names from $GEOM_TYPES
# Mark them as implemented or not
# Lines look like: IFCTYPE(?,todo?)(?,Note...)
implemented_list=$(grep -v ',todo' $GEOM_TYPES | sed 's/,.*//')
not_implemented_list=$(grep ',todo' $GEOM_TYPES | sed 's/,.*//')

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
