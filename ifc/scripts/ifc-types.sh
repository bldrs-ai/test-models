out_name=type
out=$out_name.txt
rm $out
find . -name "*.ifc" -exec grep -h -oE 'IFC[A-Z]+' {} >> $out +
cat $out | sort | uniq -c | sort -rn -k 1 > $out_name-counts.txt
