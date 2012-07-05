package EPrints::Plugin::Screen::EPrint::LocalSummary;

our @ISA = ( 'EPrints::Plugin::Screen::EPrint' );

use strict;

sub new
{
	my( $class, %params ) = @_;

	my $self = $class->SUPER::new(%params);

	$self->{appears} = [
		{
			place => "eprint_view_tabs",
			position => 200,
		}
	];

	return $self;
}

sub can_be_viewed
{
	my( $self ) = @_;

	return $self->allow( "eprint/summary" );
}

sub render
{
	my( $self ) = @_;

	my ($data,$title) = $self->{processor}->{eprint}->render_preview;

	return $data;
}	

sub phrase
{
        my( $self, $id, %bits ) = @_;

        my $base = "Plugin/Screen/EPrint/Summary";
        $base =~ s/::/\//g;

        return $self->{session}->phrase( $base.":".$id, %bits );
}

sub html_phrase
{
        my( $self, $id, %bits ) = @_;

        my $base = "Plugin/Screen/EPrint/Summary";
        $base =~ s/::/\//g;

        return $self->{session}->html_phrase( $base.":".$id, %bits );
}


sub register_furniture
{
        my( $self ) = @_;

	my $session = $self->{session};

	my $viewperms = $self->{processor}->{eprint}->get_value( "viewperms" );

	return $session->make_doc_fragment unless( EPrints::Utils::is_set( $viewperms ) );

	my $phrase;

	if( $viewperms eq 'private' )
	{
		my $url = $session->get_repository->get_conf( "rel_path" )."/cgi/users/home?screen=EPrint::Edit&eprintid=".$self->{processor}->{eprint}->get_id."#viewperms";
		my $link = $session->make_element( "a", href => $url );
		#$link->appendChild( $session->make_text( $url ) );
		$phrase = $self->html_phrase( "item_private", link=>$link );
	}
	else
	{
		my $url = $self->{processor}->{eprint}->get_url;
		my $link = $session->make_element( "a", href => $url );
		$link->appendChild( $session->make_text( $url ) );
		$phrase = $self->html_phrase( "item_online", link=>$link );
	}

	my $container = $session->make_element( "div", align=>"center" );
	my $div = $session->make_element( "div", style=>"width:60%;text-align:left;" );
	$div->appendChild( $session->render_message( "warning", $phrase ) );

	$container->appendChild( $div );

        $self->{processor}->before_messages( $container );
}




1;
