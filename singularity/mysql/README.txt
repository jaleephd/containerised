                            README.txt

Automated MySQL server, user, and database(s) install
within a Singularity container.

Author Justin Lee <justin.lee@jcu.edu.au>, 2018

mysql_centos.def: the Singularity definition file for the MySQL server,
    installing all the required system dependencies on container build,
    and providing an interface to the database through 'singularity run'
    with the following run commands accepted:
      [ help|install|status|ping|query ..|stop|start|remove ]
  - To build the container and call it mysqldb:
      $ sudo singularity build mysqldb.simg mysql_centos.def
  - Then set the database environment variables, prefixed with SINGULARITYENV_
    (for passing to singularity) and export them:
      - $db_base_dir/$dbdirname defines where database is installed
        default: $HOME/mysql_db
      - $db_networking defines whether network connections allowed
        ("True" or "-n"), othersise only via local filesystem socket.
        default: local socket connections only
      - $dbusername defines the database user's username.
        default: mysql_user
      - $user_base_dir defines where the database user my.conf is stored.
        default: $PWD
      - $schema_base_dir defines the parent directory containing sub
        directories, one per schema to be created, and each containing
        SQL (*.sql and *.sql.gz) and data (*.txt and *.txt.gz) files
        to be processed for that schema.
        default: $PWD
    For example to allow network connections:
      $ export SINGULARITYENV_db_networking="True"
  - Then install the database server, create database user and schemas
      $ singularity run mysqldb.simg install
    or, using the container as an executable
      $ ./mysqldb.simg install
  - Once the database has been installed, then it can be accessed with
    the following singularity run commands:
    - 'status' will return a textual status of the server, while
    - 'ping' returns an exit value of 0 if server is responding, 1 otherwise.
    - 'query <SQL query> can be used to run an SQL query on the database.
    - 'stop' should be done on completion to stop the database server.
    - 'start' can be used to restart the database server after 'stop'.
  - Optionally the database server can be shutdown and removed with
      $ singularity run mysqldb.simg remove

install_mysql_database.sh: the main installation & configuration script.
    It builds a local MySQL database server, and a database user,
    my.conf files for 'root' and the database user.
    If any directories are found under schema_base_dir (which defaults
    to the current working directory), then for each directory a schema
    will be created and any .sql or .sql.gz files will be run within
    that schema, and any .txt or .txt.gz files will be imported (optional
    mysqlimport.conf files can be used to specify import options).

    *** IMPORTANT NOTE ***
    There are many settings that can be overridden by setting them
    in the environment (export var=VALUE) prior to running this script.
    In particular the install directory for the MySQL server will be
    $db_base_dir/$dbdirname, with the following defaults:
        $db_base_dir (default: $HOME)
        $dbdirname   (default: mysql_db)
    and will also contain the root user my.conf file for controlling
    the database server.
    The database user's directory is set with
        $user_base_dir (default: current working directory)
    and will contain the my.conf file for connecting to the database,
    along with the install log.
    The database schemas parent directory is set with
        $schema_base_dir (default: current working directory)
    and contains subdirectories for defining each schema.
    The database passwords ($dbrootpass, $dbuserpass) are randomly generated
    with pwgen by default and stored in the my.conf files.
    Some other defaults which can be overridden to match requirements:
        $quitoncomplete (default: "",
                         set to "-q" to shutdown server when finished install)
        $db_networking (default: "", for local access through socket only,
                        set to "-n" for allowing network connections)
        $verbose_db_install (default: "-v" for verbose install,
                             set to "" for quiet install)
    See the first section of the script for more details on variables.

mysql_scripts: scripts for installing a MySQL database server, creating a
    database user, running SQL files from one or more schema-named directories
    to build schemas and also inserting data into the schemas.
    - mysql_setup.sh: main MySQL script, runs all the rest of the scripts
    - setup_mysql_server.sh: installs and secures a MySQL server
    - create_mysql_user.sh: creates a database user
    - create_user_schemas.sh: creates schemas owned by the user
    - run_sql_on_schema.sh: runs sql files in given directory
      on specified schema
    - insert_data_in_schema.sh: inserts data from files in given directory
      on specified schema

