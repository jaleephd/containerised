#!/bin/bash
# script insert table data into a MySQL database using mysqlimport
# takes arguments: [-v] [[-t terminatechar] [-e escapechar] |
#                        -i /path/to/mysqlimport.conf ] [-c path/to/my.cnf]
#                  db_schema datadir
# data_dir contains text data files which can be either uncompressed
# or gzip compressed
# Note: this script expects user credentials to be passed via a my.cnf file
#
# Written by Justin Lee <justin.lee@jcu.edu.au>, 2018

usage="$(basename $0): [-v] [[-t terminatechar] [-e escapechar] | -i /path/to/mysqlimport.conf ] [-c path/to/my.cnf] db_schema datadir"

verbose=""
schema=""
myconf="$HOME/my.cnf"
importconf=""
fieldtermby=""
fieldescwith=""

while getopts vc:i:t:e: opt; do
    case "$opt" in
    v) # verbose mode (mysqlimport prints info about the various stages)
        verbose="-v"
        ;;
    i) # mysqlimport conf file
        importconf="$OPTARG"
        ;;
    c) # user conf file
        myconf="$OPTARG"
        ;;
    t) # specify field terminator (eg \t)
        # WARNING KLUDGE! \t doesn't get passed correctly if %q used here!
        fieldtermby="$(printf -- "--fields-terminated-by=%s" "$OPTARG")"
        ;;
    e) # specify field escape (eg \\)
        fieldescwith="$(printf -- "--fields_escaped_by=%q" "$OPTARG")"
        ;;
    \?)
        echo "$usage" 2>&1
        ;;
    esac
done
shift "$((OPTIND-1))"

if [ -n "$importconf" ]; then
    fieldtermby=""
    fieldescwith=""
    if [ -f "$importconf" ]; then
        # only use the first line
        echo "Using mysqlimport config file $importconf" 2>&1
        xtra_params="$(head -n1 $importconf)"
    else
        echo "Unable to find mysqlimport config file $importconf!" 2>&1
        echo "Exiting..." 2>&1
        exit 1
    fi
else
    xtra_params="$fieldtermby $fieldescwith"
fi

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
find ${datadir}/ -maxdepth 1 \( -name '*.txt' -o -name '*.txt.gz' \) -exec cp {} "${tmpdir}/" \;
gunzip ${tmpdir}/*.gz 2>/dev/null

filecnt=$(ls -l  ${tmpdir}/*.txt 2>/dev/null | wc -l)
if [ $filecnt -gt 0 ]; then
    # Note use of --local to avoid needing a global grant on FILE
    #      GRANT FILE ON *.* to 'someone'@'%';
    # ref: stackoverflow.com/questions/6837061/mysqlimport-error-1045-access-denied
    [ -n "$verbose" ] && echo "mysqlimport --defaults-file="$myconf" --local $xtra_params $verbose $schema ${tmpdir}/*.txt"
    mysqlimport --defaults-file="$myconf" --local $xtra_params $verbose $schema ${tmpdir}/*.txt
fi
rm -rf $tmpdir

