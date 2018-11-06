                            README.txt

Ensembl automated build on Singularity with local database server.

Author Justin Lee <justin.lee@jcu.edu.au>, 2018

ensembl_centos.def: the definition file for Singularity,
    installing all the required system dependencies on container build.
    The runscript currently only runs the Ensembl installation,
    leaving a local MySQL server running that can be connected to for
    Ensembl queries.

ensembl_install.sh: the main installation script.
    It builds a local MySQL database server and creates a user for Ensembl
    queries, downloads homosapien schemas and data, which are added to the local
    MySQL database, and installs Ensembl (including Ensembl-VEP) with a
    registry file used to direct queries to the local database. Basic tests
    are run to ensure that installation was successful.

    *** IMPORTANT NOTE ***
    There are many settings that can (and SHOULD) be overridden by setting them
    in the environment (export var=VALUE) prior to running this script.
    In particular the root install directory for the ensembl installation:
        ensembl_install_dir (default: $HOME/ensembl)
    The mysql server is also installed under here by default, but can changed:
        ensembl_db_dir (default: $ensembl_install_dir/mysql_db)
    And database passwords (ensembl_db_root_pass, ensembl_user_pass)
    are randomly generated with pwgen by default.
    The conf directory containing Ensembl API and database connection settings:
        ensembl_conf_dir (default: $ensembl_install_dir/conf)
    By default Ensembl-Vep is installed (install_ensembl_vep=True),
    BUT the VEP cache is not converted (vep_convert_cache=False),
    for optimising performance with Tabix, as it takes several hours!
    The location for temporary downloads during install is:
        ensembl_download_dir (default: /tmp/ensembl_downloads)
    See the first section of the script for more details on variables.

scripts: this directory contains supporting scripts for the Ensembl install:
    - install_ensemble_database.sh: main script for calling the MySQL
      install scripts
    - add_ensembl_mysqlimport_conf.sh: for dealing with Ensembl data import
      format
    - ensembl-vep_install.sh: script for installing VEP after the main Ensembl
      install

mysql_scripts: scripts for installing a MySQL database server, creating a
    database user, running SQL files from one or more schema-named directories
    to build schemas and also inserting data into the schemas.
    - mysql_setup.sh: main MySQL script, runs all the rest of the scripts
    - setup_mysql_server.sh: installs and secures a MySQL server
    - create_mysql_user.sh: creates a database user
    - create_user_schemas.sh: creates schemas owned by the user
    - run_sql_on_schema.sh: runs sql files in given directory on specified schema
    - insert_data_in_schema.sh: inserts data from files in given directory
      on specified schema

tests: tests for ensuring Ensembl with local database installation was successful
    - ensembl_db_registry_test.pl: test connections to local database using
      registry file
    - ensembl_human_slice_test.pl: test that able to retrieve genomic
      information from local database using Ensembl API

