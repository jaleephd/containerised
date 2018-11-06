#!/bin/bash
# script to create database schemas in MySQL, giving the user,
# as specified by user's my.cnf, full access to the database(s)
# takes parameters: path/to/db path/to/user/my.cnf db_schema1 [db_schema2 ...]"
# this script expects to run using the MySQL 'root' user, with password given
# within the my.cnf file in the specified database directory
# Written by Justin Lee <justin.lee@jcu.edu.au>, 2018

usage="$(basename $0): path/to/db path/to/user/my.cnf db_schema1 [db_schema2 ...]" 

if [ $# -lt 3 ]; then
    echo  "$usage" 2>&1
    exit 1
fi

dbdir=$1
ucnf=$2
shift 2

if [ ! -f "$dbdir/my.cnf" ]; then
    echo "Unable to find mysql root config: $dbdir/my.cnf!" 2>&1
    echo "Exiting..." 2>&1
    exit 1
fi

# if only path to my.cnf provided, then expect a my.cnf in that directory
if [ -d "$ucnf" ]; then
    ucnf="$ucnf/my.cnf"
fi

if [ ! -f "$ucnf" ]; then
    echo "Unable to find mysql user config: $ucnf!" 2>&1
    echo "Exiting..." 2>&1
    exit 1
fi

# extract username and password from user's my.cnf
uname="$(cat "$ucnf" | grep '^user=' | cut -d= -f2)"
upass="$(cat "$ucnf" | grep '^password=' | cut -d= -f2 | cut -d "'" -f 2)"
# if the port line exists, network access is allowed
myport="$(cat "$ucnf" | awk -F= '/^port/ { print $2 }')"
if [ -n "$myport" ]; then
    myhost="$(cat "$ucnf" | awk -F= '/^host/ { print $2 }')"
fi

for dbname in "$@"; do
    # create a database
    echo "Creating database schema with name $dbname ..." 2>&1
    # drop the database in case it already exists
    mysql --defaults-file="$dbdir/my.cnf" -e "DROP DATABASE $dbname;" 2>/dev/null
    mysql --defaults-file="$dbdir/my.cnf" -e "CREATE DATABASE $dbname;"
    echo "Done!" 2>&1

    # provide specified user with full access to database
    echo "Granting $uname full rights to database $dbname ..." 2>&1
    # allow TCP network connections from anywhere
    mysql --defaults-file="$dbdir/my.cnf" -e "GRANT ALL ON ${dbname}.* TO '$uname'@'%' IDENTIFIED BY '$upass';"
    # allow local Unix socket connections
    mysql --defaults-file="$dbdir/my.cnf" -e "GRANT ALL ON ${dbname}.* TO '$uname'@'localhost' IDENTIFIED BY '$upass';"
    echo "Done!" 2>&1

    echo 2>&1
    echo "To use $dbname database, use the command:" 2>&1
    echo "    $ mysql --defaults-file=\"$ucnf\" -D $dbname" 2>&1
    if [ -n "$myport" ]; then
        echo "Note connecting via network to $myhost on port $myport" 2>&1
        echo "     to connect locally via socket:" 2>&1
        echo "     comment the #host and #protocol lines in $ucnf" 2>&1
    fi
    echo 2>&1
done

