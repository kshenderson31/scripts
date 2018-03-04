function toggleBlanket(div_id) 
{
	var el = document.getElementById(div_id);
	if ( el.style.display == 'none' ) 
	{	
		el.style.display = 'block';
	}
	else 
	{
		el.style.display = 'none';
	}
}

function setBlanketSize(popUpDivVar, topPosition) 
{
	if (typeof window.innerWidth != 'undefined') 
	{
		viewportheight = window.innerHeight;
	} 
	else 
	{
		viewportheight = document.documentElement.clientHeight;
	}
	
	if ((viewportheight > document.body.parentNode.scrollHeight) && (viewportheight > document.body.parentNode.clientHeight)) 
	{
		blanket_height = viewportheight;
	} 
	else 
	{
		if (document.body.parentNode.clientHeight > document.body.parentNode.scrollHeight) 
		{
			blanket_height = document.body.parentNode.clientHeight;
		} 
		else 
		{
			blanket_height = document.body.parentNode.scrollHeight;
		}
	}
	
	var blanket = document.getElementById('blanket');
	blanket.style.height = blanket_height + 'px';
	var popUpDiv = document.getElementById(popUpDivVar);
	popUpDiv.style.top = topPosition + 'px';
}

function setWindowPosition(popUpDivVar, leftPosition) 
{
	if (typeof window.innerWidth != 'undefined') 
	{
		viewportwidth = window.innerHeight;
	} 
	else 
	{
		viewportwidth = document.documentElement.clientHeight;
	}
	
	if ((viewportwidth > document.body.parentNode.scrollWidth) && (viewportwidth > document.body.parentNode.clientWidth)) 
	{
		window_width = viewportwidth;
	} 
	else 
	{
		if (document.body.parentNode.clientWidth > document.body.parentNode.scrollWidth) 
		{
			window_width = document.body.parentNode.clientWidth;
		} 
		else 
		{
			window_width = document.body.parentNode.scrollWidth;
		}
	}
	var popUpDiv = document.getElementById(popUpDivVar);
	popUpDiv.style.left = leftPosition + 'px';
}

function popupWindowInFrame(divName, topPosition, leftPosition) 
{
	setBlanketSize(divName, topPosition);
	setWindowPosition(divName, leftPosition);
	toggleBlanket('blanket');
	toggleBlanket(divName);		
}

function openPopUpWindow(url, name, wHeight, wWidth)
{
	var left = (screen.width/2)-(wWidth/2);
	var top = (screen.height/2)-(wHeight/2);

	popUpWindow = window.open(url, name, "location=no,status=no,scrollbars=no,menubar=no,resizable=no,directories=0,width="+wWidth+",height="+wHeight+",top="+top+",left="+left);	
	
}

function jQueryUIDialogCreate(domElement, dWidth, dHeight)
{
	$(domElement).dialog(
		{
			autoOpen: false,
			height: dHeight,
			width: dWidth,
			modal: true
		});
}
function jQueryUIDialogOpen(domElement, html)
{
	$(domElement).dialog( "open" );
	$(domElement).html(html);
}

function jQueryUIDialogOpenStatic(domElement)
{
	$(domElement).dialog( "open" );
}

function jQueryUIDialogClose(domElement)
{
	$(domElement).dialog( "close" );
}
