package EPrints::Plugin::Screen::EPMC::GoogleDocsPreview;

@ISA = ( 'EPrints::Plugin::Screen::EPMC' );

use strict;
# Make the plug-in
sub new
{
      my( $class, %params ) = @_;

      my $self = $class->SUPER::new( %params );

      $self->{actions} = [qw( enable disable )];
      $self->{disable} = 0; # always enabled, even in lib/plugins

      $self->{package_name} = 'Package_Name';

      return $self;
}

=item $screen->action_enable( [ SKIP_RELOAD ] )

Enable the L<EPrints::DataObj::EPM> for the current repository.

If SKIP_RELOAD is true will not reload the repository configuration.

=cut

sub action_enable
{
      my( $self, $skip_reload ) = @_;

      $self->SUPER::action_enable( $skip_reload );

      my $repo = $self->{repository};

      # ADD STUFF HERE
  my $citation = $repo->dataset( 'eprint' )->citation( 'summary_page' );
  
  my $filename = $citation->{filename};

  my $string = "
  <cite:citation xmlns='http://www.w3.org/1999/xhtml' xmlns:epc='http://eprints.org/ep3/control' xmlns:cite='http://eprints.org/ep3/citation'>
    <p style='margin-bottom: 1em'>
       <div align='center'>
         <i>
		<epc:print expr='\$googledocs_preview' />
         </i>
       </div>
    </p>
  </cite:citation>
";
	EPrints::XML::add_to_xml( $filename,$string,$self->{package_name} );
	if( !$repo->expire_abstracts() )
	{
		$self->{processor}->add_message( 'warning','You need to regenerate abstracts' ); 
	}
      $self->reload_config if !$skip_reload;
}

=item $screen->action_disable( [ SKIP_RELOAD ] )

Disable the L<EPrints::DataObj::EPM> for the current repository.

If SKIP_RELOAD is true will not reload the repository configuration.

=cut

sub action_disable
{
      my( $self, $skip_reload ) = @_;

      $self->SUPER::action_disable( $skip_reload );
      my $repo = $self->{repository};

      # ADD STUFF HERE
  my $citation = $repo->dataset( 'eprint' )->citation( 'summary_page' );
  
  my $filename = $citation->{filename};
	EPrints::XML::remove_package_from_xml($filename,$self->{package_name} );
	if( !$repo->expire_abstracts() )
	{
		$self->{processor}->add_message( 'warning','You need to regenerate abstracts' ); 
	}
      
      $self->reload_config if !$skip_reload;

}

1;
