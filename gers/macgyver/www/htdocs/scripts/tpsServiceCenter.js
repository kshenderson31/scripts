/*******************************************************************************
 * 
 * To Do: Ajax Phone List from Contacts Horizontal Navigation Bar
 ******************************************************************************/
function displayCurrentDate() {
	var dayNames = new Array("Sunday", "Monday", "Tuesday", "Wednesday",
			"Thursday", "Friday", "Saturday");
	var monthNames = new Array("January", "February", "March", "April", "May",
			"June", "July", "August", "September", "October", "November",
			"December");
	var now = new Date();

	var currentDate = dayNames[now.getDay()] + ", "
			+ monthNames[now.getMonth()] + " " + now.getDate() + ", "
			+ now.getFullYear();

	$("div#currentDate").html("<span>" + currentDate + "&nbsp;&nbsp;</span>");
}

function getAccordion(key, domElement) {
	$
			.ajax({
				type : "GET",
				url : "../cgi-bin/getAccordionMenu.pl",
				contentType : "application/json; charset=utf-8",
				dataType : "json",
				data : "id=" + key,
				error : function(XMLHttpRequest, textStatus, errorThrown) {
					alert(XMLHttpRequest, textStatus, errorThrown);
					$('div#Question').text(
							"responseText: " + XMLHttpRequest.responseText
									+ ", textStatus: " + textStatus
									+ ", errorThrown: " + errorThrown);
					$('div#surveyMessage').addClass("textRed");
					$('div#surveyMessage').addClass("textItalics");
					return false;
				},
				success : function(data) {
					var str = data.html;
					var r00 = str.replace(/&doub;/g, '"');
					var r01 = r00.replace(/&sing;/g, "'");
					var r02 = r01.replace(/&open;/g, "{");
					var r03 = r02.replace(/&clos;/g, "}");
					
					$("div#" + domElement).html(r03+"<script>"+data.script+"</script>");

					invokeHoverAccordionMenu(".accordion");

					return true;
				}
			}); // ajax

	return false;
};

function getPageElement(key, domElement) {
	$.ajax({
		type : "GET",
		url : "../cgi-bin/getPageElement.pl",
		contentType : "application/json; charset=utf-8",
		dataType : "json",
		data : "id=" + key,
		error : function(XMLHttpRequest, textStatus, errorThrown) {
			$('div#Question').text(
					"responseText: " + XMLHttpRequest.responseText
							+ ", textStatus: " + textStatus + ", errorThrown: "
							+ errorThrown);
			$('div#surveyMessage').addClass("textRed");
			$('div#surveyMessage').addClass("textItalics");
			return false;
		},
		success : function(data) {
			var str = data.html;
			var rep = str.replace(/&doub;/g, '"');
			rep = rep.replace(/&sing;/g, "'");
			$("div#" + domElement).html(rep);
			return true;
		}
	}); // ajax

	return false;
};

function openPhoneList() {
	jQueryUIDialogOpenStatic("#phoneList");
	$("#phoneCenter").dataTable({
		"bJQueryUI" : true,
		"bRetrieve" : true,
		"bServerSide" : false,
		"bDestroy" : true,
		"sAjaxSource" : "../cgi-bin/getPhoneList.pl?id=it",
	});

	$("#phoneVendors").dataTable({
		"bJQueryUI" : true,
		"bRetrieve" : true,
		"bServerSide" : false,
		"bDestroy" : true,
		"sAjaxSource" : "../cgi-bin/getPhoneList.pl?id=vendor",
	});

	$("#ptabs").tabs({
		"activate" : function(event, ui) {
			var table = $.fn.dataTable.fnTables(true);
			if (table.length > 0) {
				$(table).dataTable().fnAdjustColumnSizing();
			}
		}
	});

	$("table.phones").dataTable({
		"sScrollY" : "200px",
		"bScrollCollapse" : true,
		"bPaginate" : false,
		"bJQueryUI" : true,
		"bRetrieve" : true,
		"aoColumnDefs" : [ {
			"sWidth" : "10%",
			"aTargets" : [ -1 ]
		} ]
	});

	return false;
};

function quickTicket() 
{
	jQueryUIDialogOpenStatic("#quickTicket");
};

function ideas() 
{
	jQueryUIDialogOpenStatic("#ideas");
};

function broadcast() 
{
	jQueryUIDialogOpenStatic("#broadcast");
};

var viewportwidth = document.getElementsByTagName('body')[0].clientWidth;
var viewportheight = document.getElementsByTagName('body')[0].clientHeight;

$(document).ready(function() {
	displayCurrentDate();

	jQueryUIDialogCreate("#phoneList", 800, 500);
	jQueryUIDialogCreate("#quickTicket", 1020, 600);
	jQueryUIDialogCreate("#ideas", 800, 500);
	jQueryUIDialogCreate("#broadcast", 800, 500);
	jQueryUIDialogCreate("#utilityOutput", 1020, 600);
	jQueryUIDialogCreate("#confirmationPanel", 300, 300);

	getPageElement(3, "standardLinks");

	getAccordion(1, "accordionMenu");

	getPageElement(9, "mainBody");
	getPageElement(1, "pageFooter");
	
	invokeFormValidationEngine("#ticket");
	invokeFormValidationEngine("#ideas");
	
	$(function() 
	{
		$( ".ticketButtons button:first" ).button({
	       }).next().button({
	       });
		
		$( ".ideaButtons button:first" ).button({
	       }).next().button({
	       });
		
		$( ".broadcastButtons button:first" ).button({
	       }).next().button({
	       });
	});
	
	$(function() 
	{
		$( ".broadcastDate" ).datepicker({
			dateFormat: "MM d, yy"
		});
	});
	
	$(".cancelTicket").click(
       	function()
       	{	
       		$(".formError").remove();
       		jQueryUIDialogClose("#quickTicket");
          	return false;
       	}
    );
	
	$(".cancelIdea").click(
       	function()
       	{	
       		$(".formError").remove();
       		jQueryUIDialogClose("#ideas");
          	return false;
       	}
    );

	return false;
});