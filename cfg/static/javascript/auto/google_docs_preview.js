var left_hidden_tiles = [];
var right_hidden_tiles = [];

var previewplus_current_page = 0;
var previewplus_current_tile = 0;

document.observe("dom:loaded", previewPageLoad);

function previewPageLoad(){
	
	var previous_button = $('ep_inplace_previous_button');
	if( previous_button != null )
	{
		previous_button.observe("click", function(event){
			ep_preview_plus_showPreviousPage();
		});
	}

	var next_button = $('ep_inplace_next_button');
	if( next_button != null )
	{	
		next_button.observe("click", function(event){
			ep_preview_plus_showNextPage();
		});
	}

}

function ep_preview_plus_showDocumentInfo(docid)
{
	var doc_info = $('ep_preview_plus_extra_info_'+docid);
	if( doc_info == null )
		return;

	doc_info.blindDown();

	var show_button = $('ep_inplace_show_info_button_'+docid);
	if( show_button == null )
		return;

	show_button.hide();
	
	var hide_button = $('ep_inplace_hide_info_button_'+docid);
	if( hide_button == null )
		return;

	hide_button.show();
}

function ep_preview_plus_hideDocumentInfo(docid)
{
	var doc_info = $('ep_preview_plus_extra_info_'+docid);
	if( doc_info == null )
		return;

	doc_info.blindUp();

	var show_button = $('ep_inplace_show_info_button_'+docid);
	if( show_button == null )
		return;

	show_button.show();
	
	var hide_button = $('ep_inplace_hide_info_button_'+docid);
	if( hide_button == null )
		return;

	hide_button.hide();
}

function ep_preview_plus_showPage(page)
{
	var current_page = $('ep_inplace_tile_container_'+previewplus_current_page);

	if( current_page == null )
		return;

	var new_page = $('ep_inplace_tile_container_' + page );

	if( new_page == null )
		return;

	current_page.hide();
	
	$('ep_inplace_page_container_'+previewplus_current_page).removeClassName( "ep_inplace_page_container_selected" );

	if(Prototype.Browser.IE && parseInt(navigator.userAgent.substring(navigator.userAgent.indexOf("MSIE")+5)) == 6)
	{
		new_page.style.display='block';
	}
	else
	{
		new_page.appear({duration:0.5});
	}

	previewplus_current_page = page;

	$('ep_inplace_page_container_'+previewplus_current_page).addClassName( "ep_inplace_page_container_selected" );

}

function ep_preview_plus_showNextPage()
{
	return ep_preview_plus_showPage( previewplus_current_page + 1 );
}
	
function ep_preview_plus_showPreviousPage()
{
	return ep_preview_plus_showPage( previewplus_current_page - 1 );
}


function ep_preview_plus_show(preview_to_show, url){
	var preview_div = $(preview_to_show);
	if(preview_div){
		preview_div.show();
	}else{
		$('ep_inplace_ajaxload').show();
		new Ajax.Request(url, {
			method: 'get',
			onLoaded: function(response){
				$('ep_inplace_ajaxload').show();			
			},
			onSuccess: function(response) {
				$('ep_inplace_ajaxload').hide();			
				var preview_div = "<div id='"+preview_to_show+"' class='ep_preview_plus'>"+response.responseText+"</div>";
				var video_id = "player"+preview_to_show;
				preview_div = preview_div.replace(/id="player"/, 'id="'+video_id+'"');
  				$("ep_preview_plus_area").innerHTML += preview_div;
			
				var video_preview = "player"+preview_to_show;
				if(preview_div.match(video_id)){
					$f(video_id, '/flowplayer/flowplayer-3.1.5.swf', { clip: { autoPlay: false, onBeforeBegin: function() { $f("player").close(); }  } });
				}
			}
		});
	}
}

function ep_preview_plus_showInfo(num)
{
	// need to get the info from somewhere (they should be somewhere, hidden)
	
	var info = $('ep_inplace_docinfo_'+previewplus_current_tile);
	if( info == null )
		return;

	info.hide();

	info = $('ep_inplace_docinfo_' + num);
	if( info == null )
		return;
	
	info.show();

}

function ep_inplace_tile_click(num, url){

	$('ep_previews_title_'+previewplus_current_tile).removeClassName( "ep_preview_plus_tile_selected" );
	$('ep_previews_title_'+previewplus_current_tile).addClassName( "ep_preview_plus_tile_nonselected" );

	$$(".ep_preview_plus").each(
		function(prev) {prev.hide();}
	);


	ep_preview_plus_show("ep_preview_plus_"+num, url);
	$("ep_preview_plus_area").scrollTop =0;
	
	ep_preview_plus_showInfo( num );

	previewplus_current_tile = num;
	$('ep_previews_title_'+previewplus_current_tile).removeClassName( "ep_preview_plus_tile_nonselected" );
	$('ep_previews_title_'+previewplus_current_tile).addClassName( "ep_preview_plus_tile_selected" );

}

