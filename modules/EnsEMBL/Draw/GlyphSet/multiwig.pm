=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2018] EMBL-European Bioinformatics Institute

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

     http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.

=cut

package EnsEMBL::Draw::GlyphSet::multiwig;

### Module for drawing multiple bigWig files in a single track 
### (used by some trackhubs via the 'container = multiWig' directive)

use strict;

use Role::Tiny::With;
with 'EnsEMBL::Draw::Role::BigWig';
with 'EnsEMBL::Draw::Role::Wiggle';
with 'EnsEMBL::Draw::Role::Default';

use parent qw(EnsEMBL::Draw::GlyphSet::bigwig);

sub can_json { return 1; }

sub init {
  my $self = shift;
  $self->{'my_config'}->set('scaleable', 1);
  $self->{'data'} = $self->get_data;
}

sub render_normal {
  my $self = shift;
  $self->{'my_config'}->set('drawing_style', ['Graph']);
  $self->{'my_config'}->set('height', 60);
  $self->_render_aggregate;
}

sub get_data {

}

1;
