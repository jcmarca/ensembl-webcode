# $Id$

package EnsEMBL::Web::Component::Transcript::Go;

# GO:0005575  	cellular_component
# GO:0008150  	biological_process
# GO:0003674  	molecular_function

use strict;

use base qw(EnsEMBL::Web::Component::Transcript);

sub _init {
  my $self = shift;
  $self->cacheable(1);
  $self->ajaxable(1);
}

sub content {
  my $self   = shift;
  my $object = $self->object;  
  
  return $self->non_coding_error unless $object->translation_object;

  my $label = 'Ontology';
  
  unless ($object->__data->{'links'}) {
    my @similarity_links = @{$object->get_similarity_hash($object->Obj)};
    
    return unless @similarity_links;
    
    $self->_sort_similarity_links(@similarity_links);
  }

  return '<p>No ontology terms have been mapped to this entity.</p>' unless $object->__data->{'links'}{'go'}; 

  my $html          =  '<p><h3>The following ontology terms have been mapped to this entry:</h3></p>';
  my $columns       = [   
    { key => 'go',              title => 'Accession',      width => '5%',  align => 'left'   },
    { key => 'description',     title => 'Term',           width => '30%', align => 'left'   },
    { key => 'evidence',        title => 'Evidence',          width => '3%',  align => 'center' },
    { key => 'desc',            title => 'Annotation Source', width => '24%', align => 'center' },
    { key => 'goslim_goa_acc',  title => 'GOSlim Accessions', width => '5%', align => 'centre' },
    { key => 'goslim_goa_title',title => 'GOSlim Terms', width => '30%', align => 'centre' },
  ];

# This view very much depends on existance of the ontology db 
# But it does not have to be - you can still display the ontology terms with the links to the corresponding 
# ontology website.
   
  my %clusters = $self->hub->species_defs->multiX('ONTOLOGIES');
  warn Data::Dumper::Dumper \%clusters;

  foreach my $oid (sort {$a <=> $b} keys %clusters) {
    my $go_hash  = $object->get_go_list($clusters{$oid}->{db}, $clusters{$oid}->{root});

    if (%$go_hash) {
	$html .= "<p><h3>The following terms are descendants of $clusters{$oid}->{description}</h3>";
      #add closest goslim_goa
      my $go_database=$self->hub->get_databases('go')->{'go'};    
      foreach (keys %$go_hash){
        my $query = qq(        
          SELECT t.accession, t.name,c.distance
          FROM closure c join term t on c.parent_term_id= t.term_id
          where child_term_id = (SELECT term_id FROM term where accession='$_')
          and parent_term_id in (SELECT term_id FROM term t where subsets like '%goslim_goa%')
          order by distance         
        );
        my $result = $go_database->dbc->db_handle->selectall_arrayref($query);
	foreach my $r (@$result) {
	    my ($accession, $name, $distance) =@{$r};
	    $go_hash->{$_}[3]->{$accession}->{'name'} = $name;
	    $go_hash->{$_}[3]->{$accession}->{'distance'} = $distance;
        }
      }
      my $table = $self->new_table($columns, [], { margin => '1em 0px', cellpadding => '2px' });
      $self->process_data($table, $go_hash, $clusters{$oid}->{db});
      $html .= $table->render;
    }
  }
  return "</p>$html";
}

sub process_data {
  my ($self, $table, $data_hash, $extdb) = @_;
  my $hub     = $self->hub;
  my $object  = $self->object;
  my $species = $hub->species;
  my $species_path = $hub->species_defs->species_path($species);

  foreach my $go (sort keys %$data_hash) {
    my $row     = {};
    my @go_data = @{$data_hash->{$go} || []};
    my ($evidence, $description, $info_text,$goslim_goa_hash) = @go_data;


    my $go_link    = $hub->get_ExtURL_link($go, $extdb, $go);
    my $query_link = $hub->get_ExtURL_link($description, $extdb, $go);
    
    my $info_text_html;
    my $info_text_url;
    my $info_text_gene;
    my $info_text_species;
    my $info_text_common_name;
    my $info_text_type;
    
    if ($info_text) {
     # create URL
     if ($info_text =~ /from ([a-z]+[ _][a-z]+) (gene|translation) (\w+)/i) {
        $info_text_gene        = $3;
        $info_text_type        = $2;
        $info_text_common_name = ucfirst $1;
      } else {
        warn "regex parse failure in EnsEMBL::Web::Component::Transcript::go()"; # parse error
      }
      
      $info_text_species = $species;
      (my $species       = $info_text_common_name) =~ s/ /_/g;
      my $script         = $info_text_type eq 'gene' ? 'geneview?gene=' : 'protview?peptide=';
      $info_text_url     = "<a href='$species_path/$script$info_text_gene'>$info_text_gene</a>";
      $info_text_html    = "[from $info_text_common_name $info_text_url]";
    } else {
      $info_text_html = '';
    }

    my $goslim_goa_acc='';
    my $goslim_goa_desc='';
    # my $distance;
    foreach (keys %$goslim_goa_hash){
      # $distance = $goslim_goa_hash->{$_}->{'distance'};   
      $goslim_goa_acc.=$hub->get_ExtURL_link($_, 'GOSLIM_GOA', $_)."<br/>";
      $goslim_goa_desc.=$hub->get_ExtURL_link($goslim_goa_hash->{$_}->{'name'}, 'GOSLIM_GOA', $_)."<br/>";
    }
    $row->{'go'}          = $go_link;
    $row->{'description'} = $query_link;
    $row->{'evidence'}    = $evidence;
    $row->{'desc'}        = $info_text_html;
    $row->{'goslim_goa_acc'}   = $goslim_goa_acc;
    $row->{'goslim_goa_title'} = $goslim_goa_desc;
    
    $table->add_row($row);
  }
  
  return $table;  
}

1;
