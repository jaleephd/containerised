#!/bin/bash

# This script automates the download, installation and test of Ensembl
# with a local Ensembl database server, schemas and data for homosapien,
# and creates an Ensembl database user.
# An Ensembl registry config file
# and a shell enviroment script for sourcing are also generated.
# After Ensembl is installed and tested, VEP will also be installed
# (unless install_ensembl_vep is set to False), optionally converting cache
# for Tabix, greatly improving the speed of retrieving existing co-located variants.
# Note, however, that this conversion step takes several hours!
#
# IMPORTANT NOTE:
#   The default values for
#   - installation directories (ensembl_install_dir, ensembl_db_dir, ensembl_conf_dir) 
#   - and passwords (ensembl_db_root_pass, ensembl_user_pass)
#   SHOULD BE OVERRIDDEN for a non-test installation! 
#
# Author Justin Lee <justin.lee@jcu.edu.au>, 2018

# Ensembl URL, version and database schema-specific values
# ensembl_release# and GRCh# can be overriden in the environment
ensembl_base_url="ftp://ftp.ensembl.org/pub"
ensembl_release="${ensembl_release:-93}"
grch_build="${grch_build:-38}" # Genome Reference Consortium Human Build #
release_ver="release-${ensembl_release}"
homosapiens="homo_sapiens_core_${ensembl_release}_${grch_build}"
homosapiens_url="$ensembl_base_url/$release_ver/mysql/$homosapiens"

# generate some random default passwords for database root and user
dbpwlengthlowtohigh="10-16" # between 10 and 16 character password
dbpwoptions="-ny" # at least 1 number and 1 special character
dbpw1="$(pwgen ${dbpwoptions} $(shuf -i${dbpwlengthlowtohigh} -n1))"
dbpw2="$(pwgen ${dbpwoptions} $(shuf -i${dbpwlengthlowtohigh} -n1))"

# Ensembl local install settings - these can be overriden in the environment
# where the Ensembl API tarball will be downloaded
ensembl_download_dir="${ensembl_download_dir:-/tmp/ensembl_downloads}"
# where the Ensembl database sql and data insertion files will be downloaded
ensembl_schema_base_dir="${ensembl_schema_base_dir:-${ensembl_download_dir}/mysql}"

# where Ensembl software/libraries will be installed
ensembl_install_dir="${ensembl_install_dir:-${HOME}/ensembl}"

# where Ensembl database will be installed
ensembl_db_dir="${ensembl_db_dir:-/${ensembl_install_dir}/mysql_db}"
# database port to connect on
ensembl_db_port="${ensembl_db_port:-3306}"
# database 'root' (admin) user password
ensembl_db_root_pass="${ensembl_db_root_pass:-${dbpw1}}"
# database user that Ensembl will use for accessing database
ensembl_user="${ensembl_user:-ensembl_user}"
ensembl_user_pass="${ensembl_user_pass:-${dbpw2}}"
# Ensembl database install log goes here
ensembl_db_install_log_dir="${ensembl_db_install_log_dir:-$PWD}"

# directory for storing config files relevant to Ensembl API/database
ensembl_conf_dir="${ensembl_conf_dir:-${ensembl_install_dir}/conf}"
# the following files will created in the ensembl_conf_dir
ensembl_export_env="${ensembl_export_env:-export_env.sh}"
ensembl_registry="${ensembl_registry:-ensembl_registry.conf}"

# set to False if don't want to install Ensembl-Vep
install_ensembl_vep="${install_ensembl_vep:-True}"
# set to True to optimise the VEP cache for Tabix - this takes several hours!
vep_convert_cache="${vep_convert_cache:-False}"


# test if bioperl is installed
perl -e 'use Bio::Perl;' 2>/dev/null
# if not, exit with an error
if [ $? -ne 0 ]; then
    echo "Ensembl requires Bioperl! Please install before proceeding!"
    echo "Exiting..."
    exit 1
fi

[ ! -d $ensembl_download_dir/ ] && mkdir -p $ensembl_download_dir
[ ! -d $ensembl_install_dir/ ] && mkdir -p $ensembl_install_dir
[ ! -d $ensembl_conf_dir/ ] && mkdir -p $ensembl_conf_dir
[ ! -d $ensembl_schema_base_dir/ ] && mkdir -p $ensembl_schema_base_dir

pushd . 2>/dev/null
echo cd $ensembl_download_dir
cd $ensembl_download_dir

# download and extract ensembl
if [ ! -e $ensembl_download_dir/ensembl-api.tar.gz ]; then
    echo "Downloading Ensembl API from $ensembl_base_url/ensembl-api.tar.gz"
    wget $ensembl_base_url/ensembl-api.tar.gz
fi
echo "Unpacking Ensembl API..."
echo tar -zxvf $ensembl_download_dir/ensembl-api.tar.gz -C $ensembl_install_dir
tar -zxvf $ensembl_download_dir/ensembl-api.tar.gz -C $ensembl_install_dir
if [ $? -ne 0 ]; then
    popd 2>/dev/null
    echo "Error unpacking Ensembl API! Exiting..." 2>&1
    exit 1
fi

# download ensembl database schemas
[ ! -d $ensembl_schema_base_dir ] && mkdir -p $ensembl_schema_base_dir

cd $ensembl_schema_base_dir
if [ ! -d $ensembl_schema_base_dir/$homosapiens/ ]; then
    mkdir -p $ensembl_schema_base_dir/$homosapiens
    cd $homosapiens/
    echo "Downloading Homo Sapien data from: $homosapiens_url/"
    wget $homosapiens_url/*.gz
    echo "Done!"
fi

popd 2>/dev/null

# Perl library path for Ensembl
echo "Creating library path for Ensembl modules..."
ENSEMBLLIB=${ensembl_install_dir}/ensembl/modules
for d in compara variation funcgen io; do
    ENSEMBLLIB="${ENSEMBLLIB}:${ensembl_install_dir}/ensembl-${d}/modules"
done
echo "ENSEMBLLIB=${ENSEMBLLIB}"

# export Ensembl and Perl5 library path (including BioPerl) to a conf file
# and export the Esensembl environment variables to this conf file
echo "Storing environment variables in $ensembl_conf_dir/$ensembl_export_env"
cat << EOF > $ensembl_conf_dir/$ensembl_export_env
PERL5LIB="${PERL5LIB}"
ENSEMBLLIB="${ENSEMBLLIB}"
ENSEMBL_REGISTRY="${ensembl_conf_dir}/${ensembl_registry}"
[ -n "\${ENSEMBL_REGISTRY}" ] && export ENSEMBL_REGISTRY
[ -n "\${ENSEMBLLIB}" ] && PERL5LIB="\${ENSEMBLLIB}\${PERL5LIB:+:\${PERL5LIB}}"
export PERL5LIB
EOF
echo "Done!"

# and export to shell for using now
ENSEMBL_REGISTRY=${ensembl_conf_dir}/${ensembl_registry}
PERL5LIB="${ENSEMBLLIB}${PERL5LIB:+:${PERL5LIB}}"
export PERL5LIB ENSEMBL_REGISTRY

if [ ! -e "$ensembl_db_dir/my.cnf" ]; then
    # build database and insert ensembl schemas and data into mysql
    # my.conf goes in this dir, and schemas in ./mysql/ will be processed
    echo "Building Ensembl MySQL database with install_ensemble_database.sh..."

    echo db_base_dir="$(dirname $ensembl_db_dir)" dbdirname="$(basename $ensembl_db_dir)" dbport="$ensembl_db_port" dbrootpass="$ensembl_db_root_pass" dbusername="$ensembl_user" dbuserpass="$ensembl_user_pass" user_base_dir="$ensembl_conf_dir" install_log_dir="$ensembl_db_install_log_dir" schema_base_dir="$ensembl_schema_base_dir" quitoncomplete="" install_ensemble_database.sh
    db_base_dir="$(dirname $ensembl_db_dir)" dbdirname="$(basename $ensembl_db_dir)" dbport="$ensembl_db_port" dbrootpass="$ensembl_db_root_pass" dbusername="$ensembl_user" dbuserpass="$ensembl_user_pass" user_base_dir="$ensembl_conf_dir" install_log_dir="$ensembl_db_install_log_dir" schema_base_dir="$ensembl_schema_base_dir" quitoncomplete="" install_ensemble_database.sh
    if [ $? -ne 0 ]; then
        echo "Error building Ensembl database! Exiting..."
        exit 1
    else
        echo "Completed build of Ensembl database!"
    fi
else
    echo "MySQL database server already exists, skipping database build..."
    echo "To force database build: rm $ensembl_db_dir/my.cnf"
fi

# create an Ensembl registry.conf
# with a Bio::EnsEMBL::DBSQL::DBAdaptor object for each database schema
# and some aliases

# port and host from user's my.cnf
if [ ! -e "$ensembl_conf_dir/my.cnf" ]; then
    echo "Unable to locate Ensembl user's MySQL conf file: $ensembl_conf_dir/my.cnf"
    echo "Exiting..."
    exit 1
fi

mysqlhost="$(cat "$ensembl_conf_dir/my.cnf" | awk -F= '/^host/ { print $2 }')"
mysqlport="$(cat "$ensembl_conf_dir/my.cnf" | awk -F= '/^port/ { print $2 }')"
if [ -z "$mysqlhost" ] || [ -z "$mysqlport" ]; then
    echo "Unable to extract Ensembl database host or port from $ensembl_conf_dir/my.cnf"
    echo "Exiting..."
    exit 1
fi

read -r -d '' dbadaptor_human << EOA
new Bio::EnsEMBL::DBSQL::DBAdaptor(
    -host    => '$mysqlhost',
    -port    => '$mysqlport',
    -user    => '$ensembl_user',
    -pass    => '$ensembl_user_pass',
    -species => 'homo_sapiens',
    -group   => 'core',
    -dbname  => '$homosapiens'
);
EOA

read -r -d '' species_aliases << 'EOS'
my @human_aliases = ('H_sapiens', 'Hsapiens', 'Homo Sapiens', 'homosapiens', 'Human', 'human');
Bio::EnsEMBL::Utils::ConfigRegistry->add_alias(
    -species => "homo_sapiens",
    -alias   => \@human_aliases
);
EOS

read -r -d '' registry_header << 'EOT'
# See the following URL for information on the format of this file:
#     https://asia.ensembl.org/info/docs/api/registry.html
# The Registry configuration file for the Perl API is a Perl file which defines the DBAdaptors you will need in your scripts.

use strict;

# You will have to import some modules. The first one will allow you to define some aliases for the databases. The second module is needed if you want to configure EnsEMBL core databases and the third one is needed for the EnsEMBL Compara databases. You may need other DBAdaptors for connecting to an EnsEMBL Variation database for instance.

use Bio::EnsEMBL::Utils::ConfigRegistry;
use Bio::EnsEMBL::DBSQL::DBAdaptor;
#use modules::Adaptors::Pass;
#use Bio::EnsEMBL::Compara::DBSQL::DBAdaptor;

# Next, you have to declare your DBAdaptors. For each database you will need to create a new object. You will have to create Bio::EnsEMBL::DBSQL::DBAdaptor objects for EnsEMBL core database, Bio::EnsEMBL::Compara::DBSQL::DBAdaptor objects for EnsEMBL Compara databases and so on. You will have to define the database host, the port (3306 is the default value), the name of the database, the type of database (core, compara, variation, vega...) and the species to which this database refers to.
EOT

read -r -d '' registry_footer << 'EOT'
# The species name can be whatever you want and you may add as many aliases as you want, BUT:
#   1.
#
#      You should not have two databases with the same name or alias.
#   2.
#
#      If you intend to use the EnsEMBL Compara API, you need to use the standard binomial name as the species name or any of the aliases as the API relies on this in order to connect to the right EnsEMBL Core database.
#
# For connecting to the EnsEMBL Compara database, you will have to create a Bio::EnsEMBL::Compara::DBSQL::DBAdaptor.

# Finally, you have to end with a 1 for the import to be successful:

1;

# If you want this file to be your default configuration file, you probably want to save it as .ensembl_init in your home directory. You can also save it elsewhere and point the ENSEMBL_REGISTRY environment variable to that location. Here are a couple of examples of how to configure your environment depending on your shell:
#
#    * Under bash:
#      ENSEMBL_REGISTRY="/usr/local/share/ensembl_registry.conf"
#      export ENSEMBL_REGISTRY
#
#    * Under csh or tcsh:
#     setenv ENSEMBL_REGISTRY "/usr/local/share/ensembl_registry.conf"

EOT

# write the ensembl registry.conf
echo "Creating $ensembl_conf_dir/$ensembl_registry"
cat << EOF > $ensembl_conf_dir/$ensembl_registry
$registry_header

${dbadaptor_human}

# You may also add some aliases of the name using the Bio::EnsEMBL::Utils::ConfigRegistry module.

${species_aliases}

$registry_footer
EOF
echo "Done!"

# test Ensembl API install with connection to Ensembl-hosted DB
# see: https://asia.ensembl.org/info/docs/api/debug_installation_guide.html
#echo "Testing Ensembl API with ping_ensembl.pl (connects to remote DB) ..."
#${ensembl_install_dir}/ensembl/misc-scripts/ping_ensembl.pl
#echo "Done!"

echo "Testing Ensembl registry connections to local MySQL database ..."
ensembl_db_registry_test.pl
if [ $? -ne 0 ]; then
    echo "Ensembl failed to connect to registered database(s)!"
    echo "Exiting..."
    exit 1
fi

echo "Testing if Ensembl is able to retrieve and extract human data..."
ensembl_human_slice_test.pl
if [ $? -ne 0 ]; then
    echo "Ensembl install failed slice adaptor tests!"
    echo "Exiting..."
    exit 1
fi
echo "Done!"
echo

echo "Ensembl install completed successfully!"
echo "To use Ensembl, source $ensembl_conf_dir/$ensembl_export_env"
echo

if [ "$install_ensembl_vep" = "True" ]; then 
    echo "Installing Ensembl-VEP with:"
    echo "ensembl_download_dir=$ensembl_download_dir ensembl_install_dir=$ensembl_install_dir ensembl_release=$ensembl_release grch_build=$grch_build vep_convert_cache=$vep_convert_cache ensembl-vep_install.sh"
    ensembl_download_dir=$ensembl_download_dir ensembl_install_dir=$ensembl_install_dir ensembl_release=$ensembl_release grch_build=$grch_build vep_convert_cache=$vep_convert_cache ensembl-vep_install.sh
    if [ $? -ne 0 ]; then
        echo "Ensembl-VEP install failed!"
        echo "Exiting..."
        exit 1
    fi
    echo "Done!"
    echo
fi

