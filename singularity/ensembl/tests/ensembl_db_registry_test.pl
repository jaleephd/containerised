#!/usr/bin/perl

use strict;
use warnings;

#use Data::Dumper;
use Bio::EnsEMBL::Registry;
use Bio::EnsEMBL::Utils::Exception;
use Bio::EnsEMBL::DBSQL::DBAdaptor;

my $registry = 'Bio::EnsEMBL::Registry';

# The Registry system allows to tell your programs
# where to find the EnsEMBL databases and how to connect to them
# load a custom ensembl_registry.conf file
# (this asumes that ENSEMBL_REGISTRY has been defined)
# ref: https://asia.ensembl.org/info/docs/api/registry.html
$registry->load_all();

# code adapted from the Ensembl Core API Tutorial
# ref: https://asia.ensembl.org/info/docs/api/core/core_tutorial.html
my @db_adaptors = @{ $registry->get_all_DBAdaptors() };
foreach my $db_adaptor (@db_adaptors) {
    my $db_connection = $db_adaptor->dbc();
    #print Dumper($db_connection);
    $db_connection->connect();
    if ($db_connection->connected()) {
        print("Succesfully connected to database!\n");
        $db_connection->disconnect_if_idle();
    } else {
        print("failed to connect to database!\n");
        exit(1);
    }

    printf(
        "species/group\t%s/%s\ndatabase\t%s\nhost:port\t%s:%s\n\n",
        $db_adaptor->species(),   $db_adaptor->group(),
        $db_connection->dbname(), $db_connection->host(),
        $db_connection->port()
    );
}

