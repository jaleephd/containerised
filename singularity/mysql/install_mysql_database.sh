#!/bin/bash

# this is a combined config/script for running mysql_setup.sh
# (with its many options) for installing a Mysql database server
# and user database schemas
# it performs the following:
# - install MySQL database server with database user,
# - create schemas accessible by the database user
# - insert data into the schemas
# - and cleanup after


### VALUES in this section can be overridden by setting them in the environment

# database server will be installed in db_base_dir/dbdirname
db_base_dir="${db_base_dir:-${HOME}}"
dbdirname="${dbdirname:-mysql_db}"

# generate some random default passwords for database root and user
dbpwlengthlowtohigh="10-16" # between 10 and 16 character password
dbpwoptions="-ny" # at least 1 number and 1 special character
dbpw1="$(pwgen ${dbpwoptions} $(shuf -i${dbpwlengthlowtohigh} -n1))"
dbpw2="$(pwgen ${dbpwoptions} $(shuf -i${dbpwlengthlowtohigh} -n1))"

# these database settings can be overridden as required
dbrootpass="${dbrootpass:-${dbpw1}}" # password for DB admin (root)
dbusername="${dbusername:-mysql_user}" # DB user
dbuserpass="${dbuserpass:-${dbpw2}}" # password for DB user

# additional database setup options. uncomment as required
#quitoncomplete="-q" # shutdown mysql server when finished. comment or set to "" for don't quit
#db_networking="-n" # allow network connections. comment or set to "" for local only
verbose_db_install="-v" # verbose output during setup. comment or set to "" for quiet

# store user my.conf and install log here
user_base_dir="${user_base_dir:-$PWD}"

# this directory contains subdirectories for each schema
schema_base_dir="${schema_base_dir:-$PWD}"

### END of section for setting VALUES ###


mysqldir=$db_base_dir/$dbdirname # where the mysql database is installed
dbuserconfdir=$user_base_dir # where to store db user's my.conf file
install_log="$user_base_dir/${dbdirname}_setup.log" # log install/setup to this file


if [ ! -d $schema_base_dir/ ]; then
    echo "Unable to find the base schema directory: $schema_base_dir" 2>&1
    exit 1
fi

# create a list of all the schemas to process
# from the directories under the specified data base directory
schemalist=""

# process each sub directory as a schema
for d in $schema_base_dir/*; do
    if [ -d $d/ ]; then
        schema=$(basename $d)
        # add to list of schemas to process
        schemalist="$schemalist $schema"
    fi
done


# perform mysql database creation and setup
echo "performing mysql database creation and setup ..."
echo "mysql_setup.sh $verbose_db_install $db_networking $quitoncomplete -b $mysqldir -r $dbrootpass -u $dbusername -p $dbuserpass -c $dbuserconfdir -d $schema_base_dir $schemalist" | tee $install_log
mysql_setup.sh $verbose_db_install $db_networking $quitoncomplete -b $mysqldir -r $dbrootpass -u $dbusername -p $dbuserpass -c $dbuserconfdir -d $schema_base_dir $schemalist >> $install_log 2>&1
echo "mysql_setup.sh returned with exit code $?" | tee -a $install_log
echo "Done!"
echo "See logfile $install_log for details."

