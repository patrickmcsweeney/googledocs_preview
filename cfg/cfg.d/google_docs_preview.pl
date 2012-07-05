#
# Preview PlusPlus local settings
#

# Use our Convert plugins over EPrints' default ones (because we use different preview sizes)
#$c->{plugin_alias_map}->{"Convert::ImageMagick::ThumbnailImages"} = "Convert::ImageMagick::LocalThumbnailImages";
#$c->{plugin_alias_map}->{"Convert::ImageMagick::LocalThumbnailImages"} = undef;
#$c->{plugin_alias_map}->{"Convert::ImageMagick::ThumbnailDocuments"} = "Convert::ImageMagick::LocalThumbnailDocuments";
#$c->{plugin_alias_map}->{"Convert::ImageMagick::LocalThumbnailDocuments"} = undef;

# Tell EPrints::DataObj::Document to generate thumbnail_[video|audio] for the appropriate documents 
$c->{thumbnail_types} = sub
{
	my( $list, $session, $doc ) = @_;
	my $type = $doc->get_value( "format" );
	return unless( defined $type );
	push @$list, "video" if( $type =~ /^video\// );
	push @$list, "audio" if( $type =~ /^audio\// );
};

# The main entry point for generating previews
$c->{make_preview_plus} = sub
{
	my ($session, $eprint, $orientation) = @_;

	my @docs = $eprint->get_all_documents;
	return $session->html_phrase( "previewplusplus:nothing_to_see" ) unless( scalar( @docs ) );

	my $preview_container = $session->make_element("div", class=>"ep_preview_plus_container");
	$preview_container->appendChild($session->get_repository()->call("make_preview_area", $session, $eprint));
	$preview_container->appendChild($session->get_repository()->call("make_preview_controls", $session, $eprint, $orientation));
	return $preview_container;
};

# The big preview frame
$c->{make_preview_area} = sub 
{
        my ($session, $eprint) = @_;

        my $preview_area_div = $session->make_element("div", id=>"ep_preview_plus_area");

	my $padding_div = $session->make_element( "div", style=>"height:100%;width:100%;background-color: #ffffff;", id=>"ep_inplace_ajaxload" );
	$preview_area_div->appendChild( $padding_div );

	my $load_img = $session->make_element("img", "src"=>$session->config("rel_path")."/images/ajax-loader.gif", id=>"ep_inplace_ajaxload_image", "alt"=>"Loading");
	$padding_div->appendChild($load_img);

	my $text = $session->make_element( "span", style=>"font-size: 16px; font-weight: bold; color: #AAAAAA;" );
	$padding_div->appendChild( $text );
	$text->appendChild( $session->make_text( "Loading previews..." ) );

        return $preview_area_div;

};

# The routine that actually creates PreviewPlusPlus
$c->{render_preview} = sub 
{
        my ($session, $document) = @_;

	# sf2: edshare - perms package
	if( $document->value("security") ne "public" && !$document->user_can_view( $session->current_user() ) )
	{
		my $container = $session->make_element( "div", style=>"background-color:#ffffff;height:370px;width:100%;padding-top: 50px;", align=>"center" );

		my $msg_container = $session->make_element( "div", style => "width: 80%;text-align:left;" );
		$container->appendChild( $msg_container );

		$msg_container->appendChild( $session->render_message( "error", $session->make_text( "You are not authorised to preview this document but you may request a copy from the author." ), 1 ) );

		$container->appendChild( $session->make_element( "br" ) );
		$container->appendChild( $session->make_element( "br" ) );
		$container->appendChild( $session->make_element( "img", style=>"border:0;", alt=>$document->get_value("description"),title=>$document->get_value( "description" ), src=>$document->icon_url() ) );
		my $p = $session->make_element( "p" );
		$container->appendChild( $p );
		$p->appendChild( $document->render_value( "description" ) );
		$container->appendChild( $session->make_element( "br" ) );
		$container->appendChild( $session->make_element( "br" ) );
		$p = $session->make_element( "p" );
		$container->appendChild( $p );
		$container->appendChild( $session->get_repository()->call("render_request_copy", $session, $document ));
		return $container;

	}
		my $eprint = $document->get_eprint;
	
		my $doc_frag = $session->make_doc_fragment();

		# sf2 - i don't like those three calls to get a preview...
		my( $thumbnail ) = @{($document->get_related_objects( EPrints::Utils::make_relation( "haspreviewThumbnailVersion" ) ))};
		my( $video_thumbnail ) = @{($document->get_related_objects( EPrints::Utils::make_relation( "hasvideoThumbnailVersion" ) ))};
		my( $audio_thumbnail ) = @{($document->get_related_objects( EPrints::Utils::make_relation( "hasaudioThumbnailVersion" ) ))};

		# pick up a video preview (.flv) over a normal preview (.jpg)
		$thumbnail = $video_thumbnail if( defined $video_thumbnail );

		# same for audio
		$thumbnail = $audio_thumbnail if( defined $audio_thumbnail && !defined $video_thumbnail );

		return $session->get_repository()->call("render_no_preview", $session, $document ) unless( defined $thumbnail );

		my $thumbnail_main = $thumbnail->get_main;
		return $session->get_repository()->call("render_no_preview", $session, $document ) unless( defined $thumbnail_main );

		if( $thumbnail_main =~ /video_preview\.flv$/ )
		{
			my $video_link = $session->make_element("a", id=>"player", href=>$thumbnail->url, class=>'ep_preview_plus_video');
			$doc_frag->appendChild($video_link);

# TODO use generic name for flowplayer and symlink to latest version, always!!
			my $script = "flowplayer('player', '/flowplayer/flowplayer-3.1.5.swf', { clip: { autoPlay: false, autoBuffering: true } }); ";
			$doc_frag->appendChild($session->make_javascript($script));
	
		}
		elsif( $thumbnail_main =~ /(preview|page-\d+)\.jpg$/ )
		{
			my $thumbnails_path = $thumbnail->local_path();

			unless( opendir(DIR, $thumbnails_path) )
			{
				$session->get_repository->log( "Failed to open directory '$thumbnails_path'" );
				return $session->get_repository()->call("render_no_preview", $session, $document );
			}

			my @pages = grep { /^page.*/ && -f "$thumbnails_path/$_" } readdir(DIR);
			#sort the pages into order
			if( scalar( @pages ) == 0 )
			{
				my $img = $session->make_element("img", src=>$thumbnail->url(), alt=>"Preview image");
				$doc_frag->appendChild($img);
				return $doc_frag;
			}
			elsif(scalar @pages > 1)
			{
				@pages = sort{
					$a =~ m/[0-9]+/;
					my $a_num = $&;

					$b =~ m/[0-9]+/;
					my $b_num = $&;

					return $a_num <=> $b_num;

				} @pages;
			}
		
			my $thumbnails_base_url = $thumbnail->get_baseurl();	
			foreach my $page (@pages)
			{
				my $img = $session->make_element("img", class=>"ep_inplace_page", src=>$thumbnails_base_url.$page);
				$doc_frag->appendChild($img);
			}

		}
		elsif( $thumbnail_main =~ /preview\.png$/ )
		{
			my $img = $session->make_element("img", class=>"ep_inplace_page", src=>$thumbnail->url(),alt=>"Preview image");
			$doc_frag->appendChild($img);
		}
		elsif( $thumbnail_main =~ /audio_preview\.mp3$/ )
		{
			my $preview_holder = $session->make_element("div", class=>"ep_inplace_no_preview");
                        $doc_frag->appendChild($preview_holder);
                        my $helptext = $session->make_text("This is an audio file so there is no visual preview. You can still listen to the audio file using the controls below.");
			$preview_holder->appendChild($helptext);

			my $audio_link = $session->make_element("a", id=>"player", href=>$thumbnail->url(), style=>'display:block;width:510px;height:25px;text-align:center;margin:auto;');
                        $doc_frag->appendChild($audio_link);
		}
		else
		{
			return $session->get_repository()->call("render_no_preview", $session, $document );
		}

        	return $doc_frag;
};

# When we didn't find a suitable preview, show a citation
$c->{render_no_preview} = sub
{
	my( $session, $document ) = @_;

	my $container = $session->make_element( "div", style=>"background-color:#ffffff;height:370px;width:100%;padding-top: 50px;", align=>"center" );
	my $msg_container = $session->make_element( "div", style => "width: 80%;text-align:left;" );
	$container->appendChild( $msg_container );

	$msg_container->appendChild( $session->render_message( "warning", $session->make_text( "There is no preview available for this file but you can download it." ), 1 ) );

	$container->appendChild( $session->make_element( "br" ) );
	$container->appendChild( $session->make_element( "br" ) );
	$container->appendChild( $document->render_citation_link( "preview_frame_no_preview" ) );
	return $container;
};

# The "control" bar
$c->{make_preview_controls} = sub
{
        my ($session, $eprint, $scroll_direction) = @_;
	my $controls_container = $session->make_element("div", id=>"ep_inplace_controls_container" );

        my $controls_tbody;

        if($scroll_direction eq "vertical")
	{
                $controls_tbody = $session->make_element("tbody", id=>"ep_inplace_tile_container");
        }
	else
	{
                $controls_tbody = $session->make_element("tbody");
        }


        if($scroll_direction eq "vertical")
	{

        }
	else
	{
		my $controls = $session->get_repository()->call("build_horizontal_table",$session, $eprint);
		$controls_container->appendChild( $controls );
        }

        return $controls_container;
};

$c->{build_horizontal_table} = sub
{
        my ($session, $eprint) = @_;
        
	my @docs = $eprint->get_all_documents();

        my $doc_frag = $session->make_doc_fragment();

	my $page_limit = 5;
	my $total_docs = scalar( @docs );

	my $status_bar = $session->make_element( "div", class=>"ep_inplace_info_container" );
	$doc_frag->appendChild( $status_bar );

	unless( $total_docs <= $page_limit )
	{
		my $prev_button = $session->make_element("input", id=>"ep_inplace_previous_button", type=>"image", src=>$session->config("rel_path")."/style/images/left_arrow.png" );
		$doc_frag->appendChild( $prev_button );
		
		my $next_button = $session->make_element("input", id=>"ep_inplace_next_button", type=>"image", src=>$session->config("rel_path")."/style/images/right_arrow.png" );
		$doc_frag->appendChild( $next_button );
	}

        my $script_url = $session->config("rel_path")."/cgi/get_google_docs_preview?t=".time."&docid=";
        
	my $controls_table = $session->make_element("table", class=>"ep_preview_plus_controls");
	$doc_frag->appendChild( $controls_table );

        my $count = 0;
	my $page_current_count = 0;
	my $page_total_count = 0;
	my $row;
        foreach my $doc (@docs)
        {
		if( $page_current_count == 0 )
		{
			# new page/row
			if( $page_total_count == 0 )
			{
				$row = $session->make_element("tr", id=>"ep_inplace_tile_container_0", style=>"display:block;" );
			}
			else
			{
				$row = $session->make_element("tr", id=>"ep_inplace_tile_container_$page_total_count", style=>"display:none;" );
			}
			$controls_table->appendChild( $row );
			$page_total_count++;
		}
		if( $count == 0 )
		{
			my $status = $session->make_element( "div", id=>"ep_inplace_docinfo_$count", style => "display:block;", class=>"ep_inplace_docinfo" );
			$status->appendChild( $doc->render_citation( "preview_tile_info" ) );
			$status_bar->appendChild( $status );

		}
		else
		{
			my $status = $session->make_element( "div", id=>"ep_inplace_docinfo_$count", style => "display:none;", class=>"ep_inplace:docinfo" );
			$status->appendChild( $doc->render_citation( "preview_tile_info" ) );
			$status_bar->appendChild( $status );
		}
                my $docid = $doc->get_id();
		my $td = $session->make_element("td", id=>"ep_previews_title_".$count, class=>"ep_preview_plus_tile", onclick=>"ep_inplace_tile_click(".$count.",'".$script_url.$docid."');");
		if($count == 0)
		{
			my $script = "window.onload =  function(){
				ep_inplace_tile_click(".$count.",'".$script_url.$docid."');
			};
			";
			$td->appendChild($session->make_javascript($script));
		}
		my $tile_box = $session->make_element("div", class=>"ep_inplace_tile_container");
                $tile_box->appendChild($doc->render_citation("preview_tile"));

		$td->appendChild($tile_box);
                $row->appendChild($td);
                $count++;
		$page_current_count++;
		if( $page_current_count >= $page_limit )
		{
			$page_current_count = 0;
		}
        }

	# tile padding
	while( ($page_limit - $page_current_count++) > 0 && defined $row )
	{
		my $td = $session->make_element("td", class=>"ep_preview_plus_tile_empty" );
		$row->appendChild( $td );
	}
	
	my $paging_container = $session->make_element( "div", class=>"ep_inplace_pagingbar_container" );
	$doc_frag->appendChild( $paging_container );
       
	my $pages_container = $session->make_element( "div", class=> "ep_inplace_pages_container" );
	$paging_container->appendChild( $pages_container );

	foreach( 1..$page_total_count )
	{
		last if( $page_total_count == 1 );
		my $page_container = $session->make_element( "div", class => "ep_inplace_page_image" );
		my $page_link = $session->make_element( "a", id => "ep_inplace_page_container_".($_-1), onclick=>"ep_preview_plus_showPage( ".($_-1)." ); return false;" );
		$page_container->appendChild( $page_link );

		$page_link->appendChild( $session->make_text( "$_" ) );
		if( $_ == 1 )
		{
			$page_link->setAttribute( "class", "ep_inplace_page_container ep_inplace_page_container_selected" );
		}
		else
		{
			$page_link->setAttribute( "class", "ep_inplace_page_container" );

		}
		$pages_container->appendChild( $page_container );
	}
	
	#my $document = $count > 1 ? "resources" : "resource";
	my $document = $count > 1 ? "files" : "file";
	$paging_container->appendChild( $session->make_text( "$count $document in this resource" ) );
 
	return $doc_frag;
};

$c->{render_request_copy} = sub
{
	my ( $session, $document ) = @_;
	my $eprint = $document->get_eprint();

	my $doc_frag = $session->make_doc_fragment();

	my $has_contact_email = 0;

	if( $session->get_repository->can_call( "email_for_doc_request" ) )
	{
		if( defined( $session->get_repository->call( "email_for_doc_request", $session, $eprint ) ) )
		{
			$has_contact_email = 1;
		}
	}
	if( $has_contact_email && !$document->is_public && $eprint->get_value( "eprint_status" ) eq "archive" )
	{
		# "Request a copy" button
		my $form = $session->render_form( "get", $session->get_repository->get_conf( "perl_url" ) . "/request_doc" );
		$form->appendChild( $session->render_hidden_field( "docid", $document->get_id ) );
		$form->appendChild( $session->render_action_buttons(
			"null" => $session->phrase( "request:button" )
		) );
		$doc_frag->appendChild($form);
		
	}
	return $doc_frag;
};

$c->{eprint_render} = sub
{
	my( $eprint, $repository, $preview ) = @_;

	my $succeeds_field = $repository->dataset( "eprint" )->field( "succeeds" );
	my $commentary_field = $repository->dataset( "eprint" )->field( "commentary" );

	my $flags = { 
		has_multiple_versions => $eprint->in_thread( $succeeds_field ),
		in_commentary_thread => $eprint->in_thread( $commentary_field ),
		preview => $preview,
	};
	my %fragments = ();

	# Put in a message describing how this document has other versions
	# in the repository if appropriate
	if( $flags->{has_multiple_versions} )
	{
		my $latest = $eprint->last_in_thread( $succeeds_field );
		if( $latest->value( "eprintid" ) == $eprint->value( "eprintid" ) )
		{
			$flags->{latest_version} = 1;
			$fragments{multi_info} = $repository->html_phrase( "page:latest_version" );
		}
		else
		{
			$fragments{multi_info} = $repository->render_message(
				"warning",
				$repository->html_phrase( 
					"page:not_latest_version",
					link => $repository->render_link( $latest->get_url() ) ) );
		}
	}		


	# Now show the version and commentary response threads
	if( $flags->{has_multiple_versions} )
	{
		$fragments{version_tree} = $eprint->render_version_thread( $succeeds_field );
	}
	
	if( $flags->{in_commentary_thread} )
	{
		$fragments{commentary_tree} = $eprint->render_version_thread( $commentary_field );
	}

if(0){	
	# Experimental SFX Link
	my $authors = $eprint->value( "creators" );
	my $first_author = $authors->[0];
	my $url ="http://demo.exlibrisgroup.com:9003/demo?";
	#my $url = "http://aire.cab.unipd.it:9003/unipr?";
	$url .= "title=".$eprint->value( "title" );
	$url .= "&aulast=".$first_author->{name}->{family};
	$url .= "&aufirst=".$first_author->{name}->{family};
	$url .= "&date=".$eprint->value( "date" );
	$fragments{sfx_url} = $url;
}

if(0){
	# Experimental OVID Link
	my $authors = $eprint->value( "creators" );
	my $first_author = $authors->[0];
	my $url ="http://linksolver.ovid.com/OpenUrl/LinkSolver?";
	$url .= "atitle=".$eprint->value( "title" );
	$url .= "&aulast=".$first_author->{name}->{family};
	$url .= "&date=".substr($eprint->value( "date" ),0,4);
	if( $eprint->is_set( "issn" ) ) { $url .= "&issn=".$eprint->value( "issn" ); }
	if( $eprint->is_set( "volume" ) ) { $url .= "&volume=".$eprint->value( "volume" ); }
	if( $eprint->is_set( "number" ) ) { $url .= "&issue=".$eprint->value( "number" ); }
	if( $eprint->is_set( "pagerange" ) )
	{
		my $pr = $eprint->value( "pagerange" );
		$pr =~ m/^([^-]+)-/;
		$url .= "&spage=$1";
	}
	$fragments{ovid_url} = $url;
}
	$fragments{googledocs_preview} = $repository->call("make_preview_plus", $repository, $eprint);

	foreach my $key ( keys %fragments ) { $fragments{$key} = [ $fragments{$key}, "XHTML" ]; }
	
	my $page = $eprint->render_citation( "summary_page", %fragments, flags=>$flags );

	my $title = $eprint->render_citation("brief");

	my $links = $repository->xml()->create_document_fragment();
	if( !$preview )
	{
		$links->appendChild( $repository->plugin( "Export::Simple" )->dataobj_to_html_header( $eprint ) );
		$links->appendChild( $repository->plugin( "Export::DC" )->dataobj_to_html_header( $eprint ) );
	}

	return( $page, $title, $links );
};
