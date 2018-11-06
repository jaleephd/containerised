#!/bin/bash

# process the ensembl schema directories
# under the specified, or current directory,
# adding a mysqlimport.conf for importing ensembl data

schema_base_dir="${1:-$PWD}"
if [ ! -d $schema_base_dir/ ]; then
    echo "Unable to find Ensembl schema base directory: $schema_base_dir" >&2
    exit 1
fi

conflist=""
echo "Processing schema directories under $schema_base_dir" >&2
for d in $schema_base_dir/*; do
    if [ -d $d ]; then
        schema=$(basename $d)
        # create a conf file for ensembl-specific mysqlimport
        echo "creating $d/mysqlimport.conf for Ensembl schema $schema" >&2
        conflist="$conflist $d/mysqlimport.conf"
        cat << 'EOF' | tee $d/mysqlimport.conf > /dev/null
--fields-terminated-by=\t --fields_escaped_by=\\
# terminating and escaping characters for ensembl as per:
# https://asia.ensembl.org/info/docs/webcode/mirror/install/ensembl-data.html
# NOTE: \t must not be enclosed in single quotes here
EOF
    fi
done
echo "Done!" >&2
echo "$conflist"

