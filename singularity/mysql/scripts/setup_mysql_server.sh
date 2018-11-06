#!/bin/bash
# script to setup a MySQL database server
# optional parameters: [ -p|-P db_root_password [ -s ]] [-n|-N port] [ path/to/db ]
# Written by Justin Lee <justin.lee@jcu.edu.au>, 2018

usagestr="Usage: $(basename $0) [ -p|-P db_root_password [ -s ]] [-n|-N port] [ path/to/db ]"

umask 0002 # remove write permission from other on file creation

dbpass="" # default database 'root' user password
storepass="N"
securedb="N"
skipnetworking="skip-networking"
mysqlport=3306 # default MySQL port

while getopts hp:P:snN: opt; do
    case "$opt" in
        h) # help
           echo $usagestr
           exit 0
           ;;
        p) # root password (stored)
           dbpass="$OPTARG"
           storepass="Y"
           echo "WARNING: MySQL root user password will be stored in my.cnf!" 2>&1
           echo "MySQL root user password set to '$dbpass'" 2>&1
           ;;
        P) # root password (not stored)
           dbpass="$OPTARG"
           echo "MySQL root user password set to '$dbpass'" 2>&1
           ;;
        s) # secure database
           securedb="Y"
           ;;
        n) # allow network access to database on default port (3306)
           skipnetworking=""
           echo "MySQL network access enabled on port $mysqlport" 2>&1
           ;;
        N) # allow network access to database on specified port
           skipnetworking=""
           mysqlport="$OPTARG"
           echo "MySQL network access enabled on port $mysqlport" 2>&1
           ;;
        \?) # unknown flag
           echo $usagestr 2>&1
           exit 1
           ;;
   esac
done
shift $((OPTIND-1)) # remove option params

if [ "$securedb" = "Y" ] && [ -z "$dbpass" ]; then
    echo "Error: MySQL root user password must be specified when securing Database!" 2>&1
    echo $usagestr 2>&1
    exit 1
fi

# db_base_path="/path/to/your/db"
if [ $# -gt 0 ]; then
    db_base_path="$1"
    export db_base_path
    echo "'db_base_path' set to $1" 2>&1
    shift
fi

if [ -z "$db_base_path" ]; then
    echo "The 'db_base_path' environment variable is not set!" 2>&1
    echo "Please set 'db_base_path' to the MySQL database directory!" 2>&1
    echo "Exiting..." 2>&1
    exit 1
fi

if fuser -s $mysqlport/tcp; then
    echo "killing existing MySQL daemon on port $mysqlport..." 2>&1
    fuser -k $mysqlport/tcp # kill any existing MySQL daemon on default port
    if [ $? -ne 0 ]; then
        p=$(fuser $mysqlport/tcp 2>/dev/null)
        echo "Unable to kill process $p listening on port $mysqlport!" 2>&1
        echo "Exiting..." 2>&1
        exit 1
    fi
    echo "Done!" 2>&1
fi

if [ ! -d "$db_base_path/" ]; then
    echo "Creating directory $db_base_path ..." 2>&1
    mkdir -p "$db_base_path"
    if [ $? -ne 0 ]; then
        echo "Unable to create directory $db_base_path!" 2>&1
        echo "Exiting..." 2>&1
        exit 1
    fi
    echo "Done!" 2>&1
    echo 2>&1
else
    echo "Directory $db_base_path exists. Clearing ..." 2>&1
    # clean out any old data
    rm -rf "$db_base_path"/*
fi

# create data and temp database directories
echo "Creating database data and temp directories under $db_base_path ..." 2>&1
mkdir $db_base_path/data
if [ $? -ne 0 ]; then
    echo "Unable to create directory $db_base_path/data!" 2>&1
    echo "Exiting..." 2>&1
    exit 1
fi
mkdir $db_base_path/temp
if [ $? -ne 0 ]; then
    echo "Unable to create directory $db_base_path/temp!" 2>&1
    echo "Exiting..." 2>&1
    exit 1
fi
echo "Done!" 2>&1
echo 2>&1

# create database owned by current user
echo "Creating database under $db_base_path ..." 2>&1
mysql_install_db --datadir="$db_base_path/data"
echo "... database created!" 2>&1
echo 2>&1

# create a MySQL config file in $db_base_path/my.cnf
# to specify the locations of data, logs, sockets and PID files
echo "Creating database config file $db_base_path/my.cnf ..." 2>&1

if [ -z "$skipnetworking" ]; then
    mysqldnetopt="port=$mysqlport"
    clientnetopt="port=$mysqlport"
else
    mysqldnetopt="$skipnetworking"
    clientnetopt=""
fi

cat <<EOD > $db_base_path/my.cnf
[mysqld]
innodb_use_native_aio=0
datadir=$db_base_path/data
socket=$db_base_path/mysql.sock
tmpdir=$db_base_path/temp
log-error=$db_base_path/mysql.log
pid-file=$db_base_path/mysql.pid
$mysqldnetopt

[client]
user=root
socket=$db_base_path/mysql.sock
$clientnetopt
EOD

echo "Done!" 2>&1
echo 2>&1

upasstr=""
echo "Starting database daemon on $HOSTNAME..." 2>&1
mysqld_safe --defaults-file="$db_base_path/my.cnf" --no-auto-restart
# wait (up to 10 sec) for MySQL server to start
waitcnt=0
while true; do
    waitcnt=$((waitcnt + 1))
    echo -n "." 2>&1
    mysqladmin --defaults-file="$db_base_path/my.cnf" ping > /dev/null 2>&1
    if [ $? -eq 0 ]; then
        echo 2>&1
        break
    elif [ $waitcnt -gt 10 ]; then
        echo "Failed to start database daemon! Setup incomplete! Exiting..." 2>&1
        exit 1
    fi
    sleep 1
done
echo "Database server succesfully started!" 2>&1

# secure database, at minimum with a root password,
# optionally by also performing all the other steps in mysql_secure_installation
if [ -n "$dbpass" ]; then
    echo 2>&1
    echo -n "Setting password for mysql root user to '$dbpass' .. " 2>&1
    mysqladmin --defaults-file="$db_base_path/my.cnf" -u root password "$dbpass"
    if [ $? -eq 0 ]; then
        echo "Done!" 2>&1
    else
        echo "Failed to set password for root user! Setup incomplete! Exiting..." 2>&1
        exit 1
    fi

    if [ "$securedb" = "Y" ]; then # this is equivalent to mysql_secure_installation
        echo "Securing database installation..." 2>&1
        echo "... Set root password (done)." 2>&1
        # set root password (for reference - done above)
        #mysql --defaults-file="$db_base_path/my.cnf" -u root --password="$dbpass" -e "UPDATE mysql.user SET Password=PASSWORD('$dbpass') WHERE User='root'"
        echo "... Disallowing remote root login." 2>&1
        mysql --defaults-file="$db_base_path/my.cnf" -u root --password="$dbpass" -e "DELETE FROM mysql.user WHERE User='root' AND Host NOT IN ('localhost', '127.0.0.1', '::1')"
        echo "... Removing anonymous users." 2>&1
        mysql --defaults-file="$db_base_path/my.cnf" -u root --password="$dbpass" -e "DELETE FROM mysql.user WHERE User=''"
        echo "... Removing test database and access to it." 2>&1
        #mysql --defaults-file="$db_base_path/my.cnf" -u root --password="$dbpass" -e "DELETE FROM mysql.db WHERE Db='test' OR Db='test\_%'"
        mysql --defaults-file="$db_base_path/my.cnf" -u root --password="$dbpass" -e "DROP DATABASE test"
        echo "... Reloading privilege table." 2>&1
        mysql --defaults-file="$db_base_path/my.cnf" -u root --password="$dbpass" -e "FLUSH PRIVILEGES"
        echo "Done!" 2>&1

        # for reference: show remaining users and databases
        #mysql --defaults-file="$db_base_path/my.cnf" -u root --password="$dbpass" -t -v -e "SELECT user, host FROM mysql.user"
        #mysql --defaults-file="$db_base_path/my.cnf" -u root --password="$dbpass" -t -v -e "SHOW DATABASES"
    fi

    if [ "$storepass" = "Y" ]; then # store password in my.cnf
        chmod o-rwx $db_base_path/my.cnf # protect root password
        cat <<EOP >> $db_base_path/my.cnf
password='$dbpass'
EOP
    else # password needs to be passed on commandline
        upasstr=" --password=\"$dbpass\""
    fi
fi

# now shutdown the database server
sleep 3
echo 2>&1
echo "Stopping database daemon..." 2>&1
mysqladmin --defaults-file="$db_base_path/my.cnf"${upasstr} shutdown
sleep 1
echo "Done!" 2>&1
echo 2>&1

echo 2>&1
echo "MySQL database server setup completed!" 2>&1
echo 2>&1
echo "To start database server, use the command:" 2>&1
echo "    mysqld_safe --defaults-file=\"$db_base_path/my.cnf\" --no-auto-restart" 2>&1
echo "To use database, use the command:" 2>&1
echo "    mysql --defaults-file=\"$db_base_path/my.cnf\"${upasstr}" 2>&1
if [ -z "$skipnetworking" ] && [ "$securedb" = "N" ]; then
    hostip="$(hostname -I | cut -d' ' -f1)" # WARNING: assumes using first IP address
    echo "Or to connect via network to database on $hostip (port $mysqlport), use the command:" 2>&1
    echo "    mysql -h $hostip --protocol tcp --defaults-file=\"$db_base_path/my.cnf\"${upasstr}" 2>&1
fi
echo "To shutdown database server, use the command:" 2>&1
echo "    mysqladmin --defaults-file=\"$db_base_path/my.cnf\"${upasstr} shutdown" 2>&1
echo "Database logs are found in: $db_base_path/mysql.log" 2>&1
echo 2>&1

