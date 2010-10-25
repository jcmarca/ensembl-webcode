# $Id$

package EnsEMBL::Web::Component::Gene::GeneSNPTable;

use strict;

use base qw(EnsEMBL::Web::Component::Gene);

sub _init {
  my $self = shift;
  $self->cacheable(1);
  $self->ajaxable(1);
}

sub content {
  my $self        = shift;
  my $hub         = $self->hub;
  my $gene        = $self->configure($hub->param('context') || 100, $hub->get_imageconfig('genesnpview_transcript'));
  my @transcripts = sort { $a->stable_id cmp $b->stable_id } @{$gene->get_all_transcripts};
  my $table_rows  = $self->variation_table(\@transcripts);
  my $table       = $table_rows ? $self->make_table($table_rows) : undef;
  
  return $self->render_content($table);
}

sub make_table {
  my ($self, $table_rows) = @_;
  
  my $columns = [
    { key => 'ID',         sort => 'html'                                                   },
    { key => 'chr' ,       sort => 'position', title => 'Chr: bp'                           },
    { key => 'Alleles',    sort => 'string',                              align => 'center' },
    { key => 'Ambiguity',  sort => 'string',                              align => 'center' },
    { key => 'class',      sort => 'string',   title => 'Class',          align => 'center' },
    { key => 'Source',     sort => 'string'                                                 },
    { key => 'status',     sort => 'string',   title => 'Validation',     align => 'center' },
    { key => 'snptype',    sort => 'string',   title => 'Type',                             },
    { key => 'aachange',   sort => 'string',   title => 'Amino Acid',     align => 'center' },
    { key => 'aacoord',    sort => 'position', title => 'AA co-ordinate', align => 'center' },
    { key => 'Transcript', sort => 'string'                                                 }
  ];
  
  return $self->new_table($columns, $table_rows, { data_table => 1, sorting => [ 'chr asc' ] });
}

sub render_content {
  my ($self, $table) = @_;

  return ($table ? $table->render : '') . $self->_info(
    'Configuring the display',
    '<p>The <strong>"Configure this page"</strong> link in the menu on the left hand side of this page can be used to customise the exon context and types of SNPs displayed in both the tables above and the variation image.
    <br /> Please note the default "Context" settings will probably filter out some intronic SNPs.</p><br />'
  );
}

sub variation_table {
  my ($self, $transcripts, $slice) = @_;
  
  my @rows;
  
  foreach my $transcript (@$transcripts) {  
    my %snps = %{$transcript->__data->{'transformed'}{'snps'}||{}};
   
    return unless %snps;
    
    my $hub               = $self->hub;
    my $gene_snps         = $transcript->__data->{'transformed'}{'gene_snps'} || [];
    my $tr_start          = $transcript->__data->{'transformed'}{'start'};
    my $tr_end            = $transcript->__data->{'transformed'}{'end'};
    my $extent            = $transcript->__data->{'transformed'}{'extent'};
    my $cdna_coding_start = $transcript->Obj->cdna_coding_start;
    my $gene              = $transcript->gene;
    
    my $base_url = $hub->url({
      type   => 'Variation',
      action => 'Summary',
      vf     => undef,
      v      => undef,
      source => undef,
    });
    
    my $base_trans_url = $hub->url({
      type => 'Transcript',
      action => 'Summary',
      t => undef,
    });
    
    my $transcript_stable_id = $transcript->stable_id;
    
    foreach (@$gene_snps) {
      my ($snp, $chr, $start, $end) = @$_;
      my $raw_id               = $snp->dbID;
      my $transcript_variation = $snps{$raw_id};
      
      if ($transcript_variation && $end >= $tr_start - $extent && $start <= $tr_end + $extent) {
        my $validation        = $snp->get_all_validation_states || [];
        my $variation_name    = $snp->variation_name;
        my $var_class         = $snp->var_class;
        my $translation_start = $transcript_variation->translation_start;
        my $source            = $snp->source;
        
        # store the transcript variation so that HGVS doesn't try and calculate it again
        $snp->{'transcriptVariations'} = [ $transcript_variation ];
        
        my ($aachange, $aacoord) = $translation_start ? 
          ($transcript_variation->pep_allele_string, sprintf '%s (%s)', $transcript_variation->translation_start, (($transcript_variation->cdna_start - $cdna_coding_start) % 3 + 1)) : 
          ('-', '-');
                
        # break up allele string if too long
        my $as = $snp->allele_string;
        $as    =~ s/(.{30})/$1\n/g;
        
        my $row = {
          ID         => qq{<a href="$base_url;v=$variation_name;vf=$raw_id;source=$source">$variation_name</a>},
          class      => $var_class eq 'in-del' ? ($start > $end ? 'insertion' : 'deletion') : $var_class,
          Alleles    => qq{<kbd>$as</kbd>},
          Ambiguity  => $snp->ambig_code,
          status     => join(', ',  @$validation) || '-',
          chr        => "$chr:$start" . ($start == $end ? '' : "-$end"),
          Source     => $source,
          snptype    => join(', ', @{$transcript_variation->consequence_type||[]}),
          Transcript => qq{<a href="$base_trans_url;t=$transcript_stable_id">$transcript_stable_id</a>},
          aachange   => $aachange,
          aacoord    => $aacoord
        };
        
        # add HGVS if LRG
        $row->{'HGVS'} = $self->get_hgvs($snp, $transcript->Obj, $slice) || '-' if $transcript_stable_id =~ /^LRG/;
        
        push @rows, $row;
      }
    }
  }

  return \@rows;
}

sub configure {
  my ($self, $context, $master_config) = @_;
  
  my $object = $self->object;
  my $extent = $context eq 'FULL' ? 1000 : $context;
  
  $master_config->set_parameters({
    image_width     => 800,
    container_width => 100,
    slice_number    => '1|1',
    context         => $context
  });

  $object->get_gene_slices(
    $master_config,
    [ 'context',     'normal', '100%'  ],
    [ 'gene',        'normal', '33%'   ],
    [ 'transcripts', 'munged', $extent ]
  );

  my $transcript_slice = $object->__data->{'slices'}{'transcripts'}[1];
  my ($count_snps, $snps, $context_count) = $object->getVariationsOnSlice($transcript_slice, $object->__data->{'slices'}{'transcripts'}[2]);
  
  $object->store_TransformedTranscripts; ## Stores in $transcript_object->__data->{'transformed'}{'exons'|'coding_start'|'coding_end'}
  $object->store_TransformedSNPS;        ## Stores in $transcript_object->__data->{'transformed'}{'snps'}

  ## Map SNPs for the last SNP display  
  my @snps2 = map {
    [ 
      $_->[2], $transcript_slice->seq_region_name,
      $transcript_slice->strand > 0 ?
        ( $transcript_slice->start + $_->[2]->start - 1, $transcript_slice->start + $_->[2]->end   - 1 ) :
        ( $transcript_slice->end   - $_->[2]->end   + 1, $transcript_slice->end   - $_->[2]->start + 1 )
    ]
  } @$snps;

  foreach (@{$object->get_all_transcripts}) {
    $_->__data->{'transformed'}{'extent'}    = $extent;
    $_->__data->{'transformed'}{'gene_snps'} = \@snps2;
  }

  return $object;
}


sub get_hgvs {
  my ($self, $vf, $trans, $slice) = @_;
  
  my %cdna_hgvs = %{$vf->get_all_hgvs_notations($trans, 'c')};
  my %pep_hgvs  = %{$vf->get_all_hgvs_notations($trans, 'p')};

  # group by allele
  my %by_allele;
  
  # get genomic ones if given a slice
  if(defined($slice)) {
    my %genomic_hgvs = %{$vf->get_all_hgvs_notations($slice, 'g', $vf->seq_region_name)};
    push @{$by_allele{$_}}, $genomic_hgvs{$_} for keys %genomic_hgvs;
  }

  push @{$by_allele{$_}}, $cdna_hgvs{$_} for keys %cdna_hgvs;
  push @{$by_allele{$_}}, $pep_hgvs{$_}  for keys %pep_hgvs;
  
  my $allele_count = scalar keys %by_allele;

  my @temp;
  
  foreach my $a (keys %by_allele) {
    foreach my $h (@{$by_allele{$a}}) {
      $h =~ s/(.{35})/$1\n/g if length $h > 50; # wordwrap
      push @temp, $h . ($allele_count > 1 ? " <b>($a)</b>" : '');
    }
  }

  return join ', ', @temp;
}

1;
