#!/usr/bin/perl

use strict;
use warnings;

#use Data::Dumper;
use Bio::EnsEMBL::Registry;
use Bio::EnsEMBL::Slice;
use Bio::EnsEMBL::Utils::Exception;
use Bio::EnsEMBL::DBSQL::DBAdaptor;

my $registry = 'Bio::EnsEMBL::Registry';
# The Registry system allows to tell your programs
# where to find the EnsEMBL databases and how to connect to them
# load a custom ensembl_registry.conf file
# (this asumes that ENSEMBL_REGISTRY has been defined)
# ref: https://asia.ensembl.org/info/docs/api/registry.html
$registry->load_all();

# get a slice adaptor for the human core database
my $slice_adaptor;
try {
    $slice_adaptor = $registry->get_adaptor( 'Human', 'Core', 'Slice' );
    if (defined($slice_adaptor)) {
        print("got slice adaptor for Human\n");
        #print Dumper($slice_adaptor);
    } else {
        print("Warning! Unable to get a slice adaptor for Human!");
    }
} catch { print "Caught exception:\n$_"; exit(1) };


# the following code is adapted from
# https://asia.ensembl.org/info/docs/api/core/core_tutorial.html
my $slice;
# Obtain a slice covering the entire chromosome X
$slice = $slice_adaptor->fetch_by_region( 'chromosome', 'X' );
printSlice($slice);
# Obtain a slice covering the region from 1MB to 2MB (inclusively) of
# chromosome 20
$slice = $slice_adaptor->fetch_by_region( 'chromosome', '20', 1e6, 2e6 );
printSlice($slice);
#$slice = $slice_adaptor->fetch_by_region( 'chromosome', '6', 25_834_000, 25_854_000);
#printSlice($slice);
# Obtain a slice covering the entire clone AL359765.6
$slice = $slice_adaptor->fetch_by_region( 'clone', 'AL359765.6' );
printSlice($slice);
# Obtain a slice covering an entire scaffold
$slice = $slice_adaptor->fetch_by_region( 'scaffold', 'KI270510.1' );
printSlice($slice);
# Another useful way to obtain a slice is with respect to a gene:
$slice = $slice_adaptor->fetch_by_gene_stable_id( 'ENSG00000099889', 5e3 );
printSlice($slice);

# To obtain sequence from a slice the seq() or subseq() methods can be used:
my $sequence = $slice->seq();
$sequence = $slice->subseq( 100, 200 );
print "Slice sub-sequence: ", $sequence, "\n";

# To retrieve a set of slices from a particular coordinate system the fetch_all() method can be used:
# Retrieve slices of every chromosome in the database
# @slices = @{ $slice_adaptor->fetch_all('chromosome') };
#
# # Retrieve slices of every BAC clone in the database
# @slices = @{ $slice_adaptor->fetch_all('clone') };

sub printSlice {
    my ($slice) = @_;
    if (defined($slice)) {
        # We can query the slice for information about itself:
        # The method coord_system() returns a Bio::EnsEMBL::CoordSystem object
        my $coord_sys  = $slice->coord_system()->name();
        my $seq_region = $slice->seq_region_name();
        my $start      = $slice->start();
        my $end        = $slice->end();
        my $strand     = $slice->strand();
        print "Slice: $coord_sys $seq_region $start-$end ($strand)\n";
    } else {
        print "Warning! Undefined slice!";
        exit(1);
    }
}

