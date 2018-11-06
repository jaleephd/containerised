#!/bin/bash
# MySQL database setup, including:
# - database server creation and root user configuration
# - client user creation (defaults to the username of user running script)
# - optional multiple database schemas created for user
# - execution of sql files (.sql or .sql.gz) from schema directories
# - insertion of data files (.txt or txt.gz) from schema directories
# Note that passwords are stored in my.cnf files
# After all steps have been completed the database server
# will be shutdown if the quit option was specified
#
# This is a front end to the following scripts which must be installed
# on the PATH (and are executed in the following order):
# - setup_mysql_server.sh
# - create_mysql_user.sh
# - create_user_schemas.sh
# - run_sql_on_schema.sh
# - insert_data_in_schema.sh
#
# Author Justin Lee <justin.lee@jcu.edu.au>, 2018

dbdir="/tmp/$USER/mysql"
skip_create_dbserver="False"
dbpass=""
dbuser=$USER
udir=$HOME
skip_create_dbuser="False"
upass=""
netopt=""
schema_name=""
verbose=""
shutdowndb="False"

usage() {
    >&2 echo "Usage: $(basename $0) [-v] [-n|-N port] [-q] [ -b | -B <database-dir> ] [ -r <root-password> ] [ -u user ] [ -c | -C user-conf-dir ] [ -p <user-password> ] [ -d data-parent-dir ] [[ schema1 ] [schema2] ... ]"
    >&2 echo "To skip database server creation use -B <database-dir>"
    >&2 echo "To skip database user creation use -C <user-conf-dir>"
    exit 1
}

while getopts hvnN:qb:B:r:u:c:C:p:d: opt; do
    case "$opt" in
    h) # help
        usage
        ;;
    v) # verbose SQL output
        verbose="-v"
        ;;
    n) # allow network access to database on default port (3306)
        netopt="-n"
        ;;
    N) # allow network access to database on specified port
        netopt="-N $OPTARG"
        ;;
    q) # quit: shut down database server on completion
        shutdowndb="True"
        ;;
    b) # database location
        dbdir="$OPTARG"
        ;;
    B) # database location
        dbdir="$OPTARG"
        skip_create_dbserver="True"
        ;;
    r) # database 'root' password
        dbpass="$OPTARG"
        ;;
    u) # database user
        dbuser="$OPTARG"
        ;;
    c) # database users conf directory
        udir="$OPTARG"
        ;;
    C) # database users conf directory
        udir="$OPTARG"
        skip_create_dbuser="True"
        ;;
    p) # database user password
        upass="$OPTARG"
        ;;
    d) # parent directory for schemas (*.sql) and data
        datadir="$OPTARG"
        ;;
    \?) # unknown flag
       usage
       ;;
    esac
done
shift $((OPTIND-1)) # remove option params

if [ "$skip_create_dbserver" = "False" ]; then
    [ -d "$dbdir" ] && mkdir -p $dbdir
    echo "setting up database in $dbdir ..."
    # optional: -n: allow network connection. don't use when testing!
    # -s: secure server install
    # -p: root password set and stored in dbdir/my.cnf
    setup_mysql_server.sh $netopt -s -p $dbpass $dbdir
    if [ $? -ne 0 ]; then
        echo "unable to complete database setup! Exiting..."
        exit 1
    fi
    sleep 5 # wait for it
fi

mysqladmin --defaults-file="$db_base_path/my.cnf" ping > /dev/null 2>&1
if [ $? -eq 0 ]; then
    echo "database server is running on $HOSTNAME"
else
    echo "starting database server on $HOSTNAME"
    mysqld_safe --defaults-file="$dbdir/my.cnf" --no-auto-restart
    sleep 5 # wait for it to start
fi

echo "database server status:"
mysqladmin --defaults-file="$dbdir/my.cnf" status
echo


if [ "$skip_create_dbuser" = "False" ]; then
    echo "creating mysql user"
    create_mysql_user.sh $netopt -u $dbuser -p $upass -c $udir $dbdir
    echo
    mysql --defaults-file="$dbdir/my.cnf" -vt -e "SELECT user, host FROM mysql.user;"
    echo
fi


if [ $# -gt 0 ]; then
    echo "creating user schemas"
    create_user_schemas.sh $dbdir $udir/my.cnf "$@"
    echo
    mysql --defaults-file="$udir/my.cnf" -vt -e "SHOW DATABASES;"
    mysql --defaults-file="$udir/my.cnf" -vt -e "SHOW GRANTS;"
    echo

    for schema in "$@"; do
        echo "processing schema: $schema"
        if [ -d "${datadir}/${schema}" ]; then
            echo "found matching directory containing SQL and/or data"
            filecnt=$(ls -l ${datadir}/${schema}/*.sql* 2>/dev/null | wc -l)
            if [ $filecnt -gt 0 ]; then
                echo "executing SQL batch files from ${datadir}/${schema} on $schema"
                [ -n "$verbose" ] && echo run_sql_on_schema.sh $verbose -c $udir/my.cnf $schema ${datadir}/${schema}
                run_sql_on_schema.sh $verbose -c $udir/my.cnf $schema ${datadir}/${schema}
            fi

            filecnt=$(ls -l ${datadir}/${schema}/*.txt* 2>/dev/null | wc -l)
            if [ $filecnt -gt 0 ]; then
                echo "inserting data from ${datadir}/${schema} into $schema"
                insert_conf=""
                if [ -f ${datadir}/${schema}/mysqlimport.conf ]; then
                    echo "found a mysqlimport.conf file in ${datadir}/${schema}"
                    insert_conf="-i ${datadir}/${schema}/mysqlimport.conf"
                fi
                [ -n "$verbose" ] && echo "insert_data_in_schema.sh $verbose $insert_conf -c $udir/my.cnf $schema ${datadir}/${schema}"
                insert_data_in_schema.sh $verbose $insert_conf -c $udir/my.cnf $schema ${datadir}/${schema}
            fi
        fi
        echo
        mysql --defaults-file="$udir/my.cnf"  -D $schema -vt -e "SHOW TABLES;"
        echo
    done
fi


if [ "$shutdowndb" = "True" ]; then
    echo "shutting down database server"
    mysqladmin --defaults-file="$dbdir/my.cnf" shutdown
    sleep 1 # wait for it to stop
else
    echo "database server has been left running"
    mysqladmin --defaults-file="$dbdir/my.cnf" status
fi
echo "done!"

