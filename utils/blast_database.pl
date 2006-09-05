#!/usr/local/bin/perl -w

use strict;
use warnings;

use FindBin qw($Bin);
use File::Basename qw( dirname );

use vars qw( $SERVERROOT );
BEGIN{
  $SERVERROOT = dirname( $Bin );
  unshift @INC, "$SERVERROOT/conf";
  eval{ require SiteDefs };
  if ($@){ die "Can't use SiteDefs.pm - $@\n"; }
  map{ unshift @INC, $_ } @SiteDefs::ENSEMBL_LIB_DIRS;
}

use EnsEMBL::Web::SpeciesDefs;
use EnsEMBL::Web::DBSQL::DBConnection;

my $SPECIES_DEFS  = EnsEMBL::Web::SpeciesDefs->new;
my $DBCONNECTION  = EnsEMBL::Web::DBSQL::DBConnection->new( undef, $SPECIES_DEFS );
my $blast_adaptor = $DBCONNECTION->get_databases_species( $SPECIES_DEFS->ENSEMBL_PRIMARY_SPECIES, 'blast')->{'blast'};
   $blast_adaptor->create_tables();
   $blast_adaptor->rotate_daily_tables();

exit 0;
