package EnsEMBL::Web::Object::Help;

use strict;
use warnings;
no warnings "uninitialized";
use CGI qw(unescape);

use EnsEMBL::Web::Object;
use EnsEMBL::Web::Data::Article;
use EnsEMBL::Web::Data::Category;
use EnsEMBL::Web::Data::View;
use EnsEMBL::Web::Data::Glossary;

use Mail::Mailer;
use Data::Dumper;

our @ISA = qw(EnsEMBL::Web::Object);

sub caption       { return undef; }
sub short_caption { return 'Help'; }
sub counts        { return undef; }

#-----------------------------------------------------------------------------

our $SPAM_THRESHOLD_PARAMETER = 30;

sub adaptor     { return $_[0]->Obj->{'adaptor'}; }
sub modular     { return $_[0]->Obj->{'modular'}; }

sub search {
  ### a
  ### Returns:
  my $self = shift;

  my $keywords    = $self->param( 'kw' );

  ## Switch to this once modular articles are available
  #my $modular     = $self->modular;
  my $modular     = 0;

  my $method = 'fetch_scores_by_string';
  if (!$modular) {
    $method = 'search_articles';
  }

  ## get list of help articles by appropriate method
  $self->{'data'}{'_results'} = EnsEMBL::Web::Data::Article->$method( $keywords );
  return $self->results;
}

sub results :lvalue { $_[0]->{'data'}{'_results'}; }

sub records {
  my ($self, $criteria) = @_;

  $self->{'records'} = [ EnsEMBL::Web::Data::View->find_all($criteria) ]
    unless $self->{'records'};

  return $self->{'records'};
}


sub views {
  my $self = shift;
  ## TODO: clean up entire help system
  #my $articles = [];

  my $params = {status => 'in_use'};
  $params->{keyword} = $self->param('kw')
    if $self->param('kw');

  #my $modular = $self->modular;
  my $modular = 0;
  ## Check to see if there are any records of type 'view'
  if ($modular) {
    $params->{type} = 'view';
    $params->{help_record_id} = $self->param('id');
    ## TODO: clean up entire help system
    #$articles = $self->records($params);

    delete $params->{type}; ## remove type parameter since it doesn't exist in old table
  } elsif ($self->param('id')) {
    $params->{article_id} = $self->param('id');
  }

  ## Default help
  if (!$self->param('id') && !$self->param('kw')) {
    $params->{keyword} = 'helpview';
  }
    
  ## Check old database and convert to records
  ## NB - convert to else block once EnsEMBL is fully migrated?
  my @articles = EnsEMBL::Web::Data::Article->search($params);

  return @articles;
}

sub index { 
  my $self = shift;
  return EnsEMBL::Web::Data::Article->fetch_index_list('live');
}

sub glossary {
  my $self = shift;
  if ($self->modular) {
    return $self->records({type => 'glossary', status => 'live'});
  } else {
    ## Fake records!

    my $glossary = EnsEMBL::Web::Data::Glossary->search(
      {status => 'live'},
      {
        order_by => 'word ASC',
      }
    );

    return $glossary;
  }
}

sub movie_list {
  my $self = shift;
  return $self->records({type => 'movie', status => 'live'});
}

sub movie {
  my $self = shift;
  my $records = $self->records({help_record_id => $self->param('id')});
  return $records->[0];
}


1;
