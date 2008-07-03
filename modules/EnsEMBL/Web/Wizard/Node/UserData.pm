package EnsEMBL::Web::Wizard::Node::UserData;

### Contains methods to create nodes for UserData wizards

use strict;
use warnings;
no warnings "uninitialized";

use Data::Bio::Text::FeatureParser;
use EnsEMBL::Web::File::Text;
use EnsEMBL::Web::Wizard::Node;
use EnsEMBL::Web::RegObj;

our @ISA = qw(EnsEMBL::Web::Wizard::Node);

our @formats = (
    {name => '-- Please Select --', value => ''},
    {name => 'generic', value => 'Generic'},
    {name => 'BED', value => 'BED'},
    {name => 'GBrowse', value => 'GBrowse'},
    {name => 'GFF', value => 'GFF'},
    {name => 'GTF', value => 'GTF'},
#    {name => 'LDAS', value => 'LDAS'},
    {name => 'PSL', value => 'PSL'},
);


#----------------------------- FILE UPLOAD NODES -----------------------

sub check_session {
  my $self = shift;
  my $parameter = {};
  my $temp_data = $self->object->get_session->get_tmp_data;
  if ($temp_data) {
    $parameter->{'wizard_next'} = 'overwrite_warning';
  }
  else {
    $parameter->{'wizard_next'} = 'select_file';
  }
}

sub overwrite_warning {
  my $self = shift;
  
  $self->add_element(('type'=>'Information', 'value'=>'You have unsaved data uploaded. Uploading a new file will overwrite this data, unless it is first saved to your user account.'));
  
  my $user = $ENSEMBL_WEB_REGISTRY->get_user;
  if ($user) {
    $self->add_element(( type => 'CheckBox', name => 'save', label => 'Save current data to my account', 'checked'=>'checked' ));
  }
  else {
    $self->add_element(('type'=>'Information', 'value'=>'<a href="#" onclick="login_link()">Log into your user account</a> to save this data.'));
  }
}

sub select_file {
  my $self = shift;

  $self->title('Select File to Upload');

  my $user = $ENSEMBL_WEB_REGISTRY->get_user;
  if ($self->object->param('save') && $user) {
    ## Save current temporary data upload to user account
    my $upload = $self->object->get_session->get_tmp_data;
  }

  my $current_species = $ENV{'ENSEMBL_SPECIES'};
  if ($current_species eq 'common') {
    $current_species = '';
  }
  if (!$current_species) {
    $current_species = $self->object->species_defs->ENSEMBL_PRIMARY_SPECIES;
  }
  my @valid_species = sort $self->object->species_defs->valid_species;
  my $species = [];
  foreach my $sp (@valid_species) {
    (my $name = $sp) =~ s/_/ /g;
    push @$species, {'name' => $name, 'value' => $sp}; 
  }

  $self->notes({'heading'=>'IMPORTANT NOTE:', 'text'=>qq(We are only able to store single-species datasets, containing data on Ensembl coordinate systems. There is also a 5Mb limit on data uploads. If your data does not conform to these guidelines, you can still <a href="/$current_species/UserData/Attach">attach it to Ensembl</a> without uploading.)});
  $self->add_element(( type => 'DropDown', name => 'species', label => 'Species', select => 'select', values => $species, 'value' => $current_species));
  $self->add_element(( type => 'File', name => 'file', label => 'Upload file' ));
  $self->add_element(( type => 'String', name => 'url', label => 'or provide file URL' ));
  
}

sub upload {
### Node to store uploaded data
  my $self = shift;
  my $parameter = {};

  my $method = $self->object->param('url') ? 'url' : 'file';
  if ($self->object->param($method)) {
    
    ## Cache data (File::Text knows whether to use memcached or temp file)
    my $file = new EnsEMBL::Web::File::Text($self->object->species_defs);
    $file->set_cache_filename('user_'.$method);
    $file->save($self->object, $method);

    ## Identify format
    my $data = $file->retrieve;
    my $parser = Data::Bio::Text::FeatureParser->new();
    my $file_info = $parser->analyse($data);
    my $format = $file_info->{'format'};

    ## Attach data species to session
    $self->object->get_session->set_tmp_data(
                  'filename'  => $file->filename, 
                  'species'   => $self->object->param('species'),
                  'format'    => $format,
    );
    $self->object->get_session->save_tmp_data;

    ## Work out if multiple assemblies available
    my $assemblies = $self->_get_assemblies($self->object->param('species'));

    if (scalar(@$assemblies) || !$format) {
      ## Get more input from user
      if (scalar(@$assemblies)) {
        $parameter->{'species'} = $self->object->param('species');
      }
      if (!$format) {
        $parameter->{'format'} = 'none';
      }
      $parameter->{'wizard_next'} = 'more_input';
    }
    else {
      $parameter->{'format'} = $format;
      $parameter->{'wizard_next'} = 'upload_feedback';
    }
  }
  else {
    $parameter->{'wizard_next'} = 'select_file';
    $parameter->{'error_message'} = 'No data was uploaded. Please try again.';
  }

  return $parameter;
}

sub more_input {
  my $self = shift;
  $self->title('File Details');

  ## Format selector
  if ($self->object->param('format') eq 'none') {
    $self->add_element(( type => 'Information', value => 'Your file format could not be identified - please select an option:'));
  $self->add_element(( type => 'DropDown', name => 'format', label => 'File format', select => 'select', values => \@formats));
  }

  ### Assembly selector
  if ($self->object->param('species')) {
    my $assemblies = $self->_get_assemblies($self->object->param('species'));
    $self->add_element(( type => 'Information', value => 'This species has more than one assembly in Ensembl. If your data uses chromosomal coordinates, please specify the assembly'));
    my $values = [];
    foreach my $assembly (@$assemblies) {
      push @$values, {'name'=>$assembly, 'value'=>$assembly};
    }
    $self->add_element(( type => 'DropDown', name => 'assembly', label => 'Assembly', select => 'select', values => $values));
  }

}

sub upload_feedback {
### Node to confirm data upload
  my $self = shift;
  $self->title('File Uploaded');
  $self->object->get_session->set_tmp_data(
    'assembly' => $self->object->param('assembly'),
    'format'  => $self->object->param('format'),
  );
  $self->object->get_session->save_tmp_data;
  $self->add_element(( type => 'Information', value => "Thank you - your file was successfully uploaded."));
}

sub select_upload {
## Node to select which data will be shared
  my $self = shift;
  $self->title('Select Data to Share');

  ## Temporary uploads
  my $upload = $self->object->get_session->get_tmp_data;
  $self->add_element(('type'=>'SubHeader', 'value'=>'Your temporary data'));
  if ($upload && keys %$upload) {
    $self->add_element(('type'=>'NoEdit', 'label' => 'Species', 'value' => $upload->{'species'}));
    $self->add_element(('type'=>'NoEdit', 'label' => 'Format', 'value' => $upload->{'format'}));
    my $file = new EnsEMBL::Web::File::Text($self->object->species_defs);
    my $file_content= $file->retrieve($upload->{'filename'});
    my $file_sample = '<pre>'.substr($file_content, 0, 1000).'</pre>';
    $self->add_element(('type'=>'NoEdit', 'label' => 'Sample of file content', 'value' => $file_sample));
    if ($upload->{'assembly'}) {
      $self->add_element(('type'=>'NoEdit', 'label' => 'Assembly', 'value' => $upload->{'assembly'}));
    }
  }
  else {
    $self->add_element('type'=>'Information', 'value'=>'You have no shareable data. Please upload a file (maximum 5MB) if you wish to share data with colleagues or collaborators.');
  }
}

sub save_upload {
## Save uploaded data to a genus_species_userdata database
  my $self = shift;
  my $parameter = {};

  ## SAVE TEMP DATA TO DATABASE

  ## 1. Retrieve data
  my $upload = $self->object->get_session->get_tmp_data;
  my $db = lc($upload->{'species'}).'_userdata';
 
 
  $parameter->{'share_id'} = '';
  $parameter->{'wizard_next'} = 'share_url';
  return $parameter;
}

sub share_url {
  my $self = shift;
  $self->title('Select Data to Share');

  my $url = 'http://'.$ENV{'ENSEMBL_SERVERNAME'}.'/Location/Karyotype?shared_data='.$self->object->param('share_id');

  $self->add_element(('type'=>'Information', 'value' => "To share this data, use the URL $url"));
  $self->add_element(('type'=>'Information', 'value' => 'Please note that this link will expire after 72 hours.'));

}

#----------------------------- DAS/ATTACHMENT NODES -----------------------

sub select_server {
  my $self = shift;
  my $object = $self->object;
  my $sitename = $object->species_defs->ENSEMBL_SITETYPE;

  $self->title('Select a DAS server or data file');

  my $preconf_das = []; ## Preconfigured DAS servers
  my $NO_REG = 'No registry';
  my $rurl = $object->species_defs->DAS_REGISTRY_URL || $NO_REG;
  if (defined (my $url = $object->param("preconf"))) {
    $url = "http://$url" if ($url !~ m!^\w+://!);
    $url .= '/das' if ($url !~ m/\/das$/ && $url ne $rurl);
    $object->param('preconf_das', $url);
  }
  my @das_servers = $self->object->get_ensembl_das;
  if ($rurl eq $NO_REG) {
    $object->param('preconf_das') or $object->param('preconf_das', $das_servers[0]);
  } 
  else {
    $object->param('preconf_das') or $object->param('preconf_das', $rurl);
    push @$preconf_das, {'name' => 'DAS Registry', 'value'=>$rurl};
  }
  my $default = $object->param("preconf_das");
  foreach my $dom (@das_servers) { push @$preconf_das, {'name'=>$dom, 'value'=>$dom} ; }


  $self->add_element(( type => 'DropDown', name => 'preconf_das', 'select' => 'select',
    label => $sitename.' DAS server', 'values' => $preconf_das ));
  $self->add_element(( type => 'String', name => 'other_das', label => 'or other DAS server',
    'notes' => '( e.g. http://www.example.com/MyProject/das )' ));
  $self->add_element(( type => 'String', name => '_das_filter', label => 'Filter sources',
    'notes' => 'by name, description or URL' ));
  $self->add_element(('type'=>'Information', 'value'=>'OR'));
  $self->add_element(( type => 'String', name => 'url', label => 'File URL',
    'notes' => '( e.g. http://www.example.com/MyProject/mydata.gff )' ));
  my $user = $ENSEMBL_WEB_REGISTRY->get_user;
  if ($user && $user->id) {
    $self->add_element(( type => 'CheckBox', name => 'save', label => 'Attach source/url to my account', 'checked'=>'checked' ));
  }
}

sub source_logic {
  my $self = shift;
  my $parameter = {};

  if ($self->object->param('url')) {    
    $parameter->{'url'}         = $self->object->param('url');
    $parameter->{'wizard_next'} = 'attach';
  }
  else {
    $parameter->{'das_server'}  = $self->object->param('other_das') || $self->object->param('preconf_das');
    $parameter->{'wizard_next'} = 'select_source';
  }
  return $parameter;
}

sub select_source {
### Displays sources for the chosen server as a series of checkboxes 
### (or an error message if no dsns found)
  my $self = shift;

  $self->title('Select a DAS source');

  my $dsns = $self->object->get_server_dsns;
  if (ref($dsns) eq 'HASH') {
    my $dwidth = 120;
    foreach my $id (sort {$dsns->{$a}->{name} cmp $dsns->{$b}->{name} } keys (%{$dsns})) {
#warn Data::Dumper::Dumper( $dsns->{$id} );
      my $dassource = $dsns->{$id};
      my ($id, $name, $url, $desc) = ($dassource->{id}, $dassource->{name}, $dassource->{url}, substr($dassource->{description}, 0, $dwidth));
      if( length($desc) >= $dwidth ) {
      # find the last space character in the line and replace the tail with ...        
        $desc =~ s/\s[a-zA-Z0-9]+$/ \.\.\./;
      }
      $self->add_element( 'type'=>'CheckBox', 'name'=>'dsns', 'value' => $id, 'label' => $name, 'notes' => $desc );
    }
  } 
  else {
    $self->add_element('type'=>'Information', 'value'=>$dsns);
  }
}

sub attach {
}

sub attach_feedback {
}

sub _check_extension {
### Tries to identify file format from file extension
  my ($self, $ext) = @_;
  $ext =~ s/^\.//;
  return unless $ext;
  $ext = uc($ext);
  if ($ext eq 'PSLX') { $ext = 'PSL'; }
  if ($ext ne 'BED' && $ext ne 'PSL' && $ext ne 'GFF' && $ext ne 'GTF') { 
    $ext = ''; 
  }
  return $ext;
}

sub _get_assemblies {
### Tries to identify coordinate system from file contents
### If on chromosomal coords and species has multiple assemblies, 
### return assembly info
  my ($self, $species) = @_;
  my $assemblies = [];
  my %assembly = (
    'Homo_sapiens'=>['NCBI36', 'NCBI37'],
    'Mus_musculus'=>['NCBIm36', 'NCBIm37'],
  );
  if  ($species) {
    $assemblies = $assembly{$species};
  }
  return $assemblies;
}


1;


