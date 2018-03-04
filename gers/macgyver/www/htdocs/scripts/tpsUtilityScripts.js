function blurLinks()
{
	var links = document.getElementsByTagName( 'a' );
	for( var i = 0, j =  links.length; i < j; i++ ) 
	{    
		links[i].setAttribute( 'tabindex', '-1' );
	}
}

function invokeTreeView(domElement)
{
	$(domElement).treeview();
}

function invokeFormValidationEngine(domElement)
{
	jQuery(document).ready(function()
	{
        // binds form submission and fields to the validation engine
		jQuery(domElement).validationEngine();
	});
}

function invokeAccordionMenu(domElement)
{
	$(document).ready(function()
	{ 
		$(domElement).hoverAccordion(
		{ 
			keepHeight : false, 
			onClickOnly : false,
			activateItem: 1
		}); 
	});
}

function invokeManualCarousel(domElement, itemsVisible, itemsToScroll)
{
	jQuery(document).ready(function() 
		{
			jQuery(domElement).jcarousel
			(
				{
					visible: itemsVisible,
					scroll: itemsToScroll,
					wrap: 'circular'
				}
			);
		});
}

function invokeAutomaticCarousel(domElement, itemsVisible, itemsToScroll, secondsDelay)
{
	jQuery(document).ready(function() 
	{
		jQuery(domElement).jcarousel
		(
			{
				visible: itemsVisible,
				scroll: itemsToScroll,
				auto: secondsDelay,
				wrap: 'circular',
				initCallback: mycarousel_initCallback
			}
		);
	});
}

function mycarousel_initCallback(carousel)
{
	// Disable autoscrolling if the user clicks the prev or next button.
	carousel.buttonNext.bind('click', function() {
		carousel.startAuto(0);
	});

	carousel.buttonPrev.bind('click', function() {
		carousel.startAuto(0);
	});

	// Pause autoscrolling if the user moves with the cursor over the clip.
	carousel.clip.hover(function() {
		carousel.stopAuto();
	}, function() {
		carousel.startAuto();
	});
};


function invokeHoverAccordionMenu(domElement)
{
	$( domElement ).accordion( "destroy" );
	$( domElement ).accordion(
	{
			active: 0,
			event: 'click',
			autoHeight: false,
			clearStyle: true,
			header: 'h3'
	});
}

function imagePopUp(e, element, image, height, width) 
{ //function called by first hotspot
    var pop=document.getElementById(element+"-image");
    pop.src=image;
    pop.style.height=height;
    pop.style.width=width;
     
    var thing = document.getElementById(element);
    thing.style.left=(e.clientX-20) + 'px';
    thing.style.top=(e.clientY-20)  + 'px';
    
    $("#"+element).toggle();

    return true;
}