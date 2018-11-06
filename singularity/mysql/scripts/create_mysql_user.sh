#!/bin/bash
# script to create a database user in MySQL
# takes parameters: [-u username] [-p password] [-c confdir] [-n|-N mysqlport] path/to/db
# this script expects to run using the MySQL 'root' user
# with it's password given within the my.cnf file in the
# specified database directory
# Written by Justin Lee <justin.lee@jcu.edu.au>, 2018

usage="$(basename $0): [-u username] [-p password] [-c confdir] [-n|-N mysqlport] path/to/db"

uname=$USER
upass=""
udir=$HOME
mysqlport=3306 # default MySQL port
hostip="$(hostname -I | cut -d' ' -f1)" # WARNING: assumes using first IP address
netaccess=0
network_options=""

while getopts u:p:c:nN: opt; do
	case "$opt" in
	u) # username
		uname="$OPTARG"
		;;
	p) # user password
		upass="$OPTARG"
		;;
	c) # user conf file directory
		udir="$OPTARG"
		;;
    n) # network access is allowed on default port
        netaccess=1
		;;
    N) # network access is allowed on specified port
        netaccess=1
        mysqlport="$OPTARG"
		;;
	\?)
		echo "$usage" 2>&1
		;;
	esac
done
shift "$((OPTIND-1))"

if [ $# -lt 1 ]; then
    echo  "$usage" 2>&1
    exit 1
fi

dbdir=$1
shift

if [ ! -f "$dbdir/my.cnf" ]; then
    echo "Unable to find $dbdir/my.cnf!" 2>&1
    echo "Exiting..." 2>&1
    exit 1
fi

echo "Creating database user $uname with password '$upass'..." 2>&1
# drop the user in case it already exists
mysql --defaults-file="$dbdir/my.cnf" -e "DROP USER '$uname'@'%';" 2>/dev/null
mysql --defaults-file="$dbdir/my.cnf" -e "DROP USER '$uname'@'localhost';" 2>/dev/null
mysql --defaults-file="$dbdir/my.cnf" -e "CREATE USER '$uname'@'%' IDENTIFIED BY '$upass';"
mysql --defaults-file="$dbdir/my.cnf" -e "CREATE USER '$uname'@'localhost' IDENTIFIED BY '$upass';"
echo "Done!" 2>&1

# define the networking part of the my.cnf if network access is allowed
if [ $netaccess -eq 1 ]; then
    read -r -d '' network_options << EON
port=$mysqlport
# comment the following to connect locally via socket, instead of over net
host=$hostip
protocol=tcp
EON
fi

# create a my.conf for db user in specified directory (default $HOME)
echo "Creating config file $udir/my.cnf for database access ..." 2>&1
cat <<EOC > $udir/my.cnf
[client]
user=$uname
password='$upass'
socket=$dbdir/mysql.sock
$network_options
EOC
echo "Done!" 2>&1

echo 2>&1
echo "To access mysql as user $uname, use the command:" 2>&1
echo "    $ mysql --defaults-file=\"$udir/my.cnf\"" 2>&1
if [ $netaccess -eq 1 ]; then
    echo "Note connecting via network to $hotip on port $mysqlport" 2>&1
    echo "     to connect locally via socket:" 2>&1
    echo "     comment the #host and #protocol lines in $udir/my.cnf" 2>&1
fi

