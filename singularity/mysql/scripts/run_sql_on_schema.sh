#!/bin/bash
# script to batch file(s) of sql commands through a MySQL database
# takes arguments: [-v] [-c path/to/my.cnf] db_schema SQL_dir
# If the -v (verbose) option is specified, then sql commands will be echoed
# Note: this script expects user credentials to be passed via a my.cnf file
#
# Written by Justin Lee <justin.lee@jcu.edu.au>, 2018

usage="$(basename $0): [-v] [-c path/to/my.cnf] db_schema SQL_dir"

verbose=""
schema=""
myconf="$HOME/my.cnf"

while getopts vc: opt; do
	case "$opt" in
	v) # verbose mysql mode - echo SQL and use interactive output format
		verbose="-vt"
		;;
	c) # user conf file
		myconf="$OPTARG"
		;;
	\?)
		echo "$usage" 2>&1
		;;
	esac
done
shift "$((OPTIND-1))"

if [ ! -f "$myconf" ]; then
    echo "Unable to find mysql config file $myconf!" 2>&1
    echo "Exiting..." 2>&1
    exit 1
fi

if [ $# -lt 2 ]; then
    echo  "$usage" 2>&1
    exit 1
fi


schema=$1
datadir=$2

if [ ! -d $datadir ]; then
    echo "$datadir doesn't exist!" 2>&1
    echo "Exiting..." 2>&1
    exit 1
fi

tmpdir=/tmp/$$_$schema
mkdir -p $tmpdir
if [ $? -ne 0 ]; then
    echo "Unable to create temp directory $tmpdir!" 2>&1
    echo "Exiting..." 2>&1
    exit 1
fi

chmod 700 $tmpdir
# Note: appending '/' to datadir in case it is a symlink
find ${datadir}/ -maxdepth 1 \( -name '*.sql' -o -name '*.sql.gz' \) -exec cp {} "${tmpdir}/" \;
gunzip ${tmpdir}/*.gz 2>/dev/null

filecnt=$(ls -l ${tmpdir}/*.sql 2>/dev/null | wc -l)
if [ $filecnt -gt 0 ]; then
    for fn in  ${tmpdir}/*.sql; do
        cat $fn | mysql --defaults-file="$myconf" -D $schema $verbose
    done
fi
rm -rf $tmpdir

