#/bin/bash


### VALUES in this section can be overridden by setting them in the environment

# database server will be installed in db_base_dir/dbdirname
db_base_dir="${db_base_dir:-/tmp}"
dbdirname="${dbdirname:-mysql_ensembldb}"

# these database settings should be overridden as required
dbport="${dbport:-3306}" # MySQL network port
dbrootpass="${dbrootpass:-secretpassA}" # password for DB admin (root)
dbusername="${dbusername:-ensembl_user}" # Mysql DB user
dbuserpass="${dbuserpass:-secretpassB}" # password for Mysql DB user

# store user my.conf and install log here
user_base_dir="${user_base_dir:-$PWD}"

# install log goes here
install_log_dir="${install_log_dir:-$PWD}"

# this should be the ensembl schema parent dir
# containing subdirectories for each schema
schema_base_dir="${schema_base_dir:-${PWD}/mysql}"

# additional database setup options. override as required
#quitoncomplete="-q" # shutdown mysql server when finished. comment or set to "" for don't quit


### END of section for setting VALUES ###


mysqldir=$db_base_dir/$dbdirname # where the mysql database is installed
dbuserconfdir=$user_base_dir # where to store db user's my.conf file
verbose_db_install="-v" # verbose output logged during setup
install_log="$install_log_dir/${dbdirname}_setup.log" # log install/setup to this file


if [ ! -d $schema_base_dir/ ]; then
    echo "Unable to find Ensembl schema base directory: ${schema_base_dir}" 2>&1
    exit 1
fi

# create conf files for ensembl data imports
cleanuplist="$(add_ensembl_mysqlimport_conf.sh $schema_base_dir)"

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

# install database server, user, schemas, data with settings given above
echo "performing mysql database creation and setup ..."
echo "mysql_setup.sh $verbose_db_install $quitoncomplete -N $dbport -b $mysqldir -r $dbrootpass -u $dbusername -p $dbuserpass -c $dbuserconfdir -d $schema_base_dir $schemalist" | tee $install_log
mysql_setup.sh $verbose_db_install $quitoncomplete -N $dbport -b $mysqldir -r $dbrootpass -u $dbusername -p $dbuserpass -c $dbuserconfdir -d $schema_base_dir $schemalist >> $install_log 2>&1
exit_code=$?

echo "mysql_setup.sh returned with exit code $exit_code" | tee -a $install_log
echo "See logfile $install_log for details."

if [ $exit_code -ne 0 ]; then
    echo "Error installing Ensembl database! Exiting after cleanup..." 2>&1
fi

echo "cleaning up mysqlimport.conf files"
echo "rm -f $cleanuplist"
rm -f $cleanuplist
echo "Done!"

exit $exit_code

