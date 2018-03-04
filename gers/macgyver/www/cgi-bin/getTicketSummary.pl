#!/usr/bin/perl
use strict;
use warnings;

use CGI;
use DBI;
use DBD::mysql;

our $conn;
our $json;
our $text;
our $cgi=CGI->new;

print $cgi->header(-type => "application/json", -charset => "utf-8");

if($conn=getDatabaseConnection("172.20.8.243", "rt4", "root", 'paradies'))
{
	if($cgi->param("id")==0)
	{	
		our $ix=0;
		foreach(1..50)
		{
			$text.=", " if $ix>0;
			$text.=sprintf('["%s", "100", "100", "100", "100", "100", "100"]', sprintf("Sample #%02d of 50", $_));
			$ix++;
		}
		$json=sprintf('{"sEcho":%d, "iTotalRecords":%d, "iTotalDisplayRecords":%d, "aoColumns": [ {"sTitle": "Associate Name", "sWidth": "60px", "bSortable": "false" }, { "sTitle": "Extension" , "sType": "mytext", "sClass": "center", "sWidth": "60px"}, { "sTitle": "Mobile Phone" , "sWidth": "60px" }, { "sWidth": "60", "sTitle": "Home Phone" }, { "sWidth": "160px", "sTitle": "Role" } ], "aaData": [%s]}', 20, 50, 50, $text);	
	}
	else
	{
		buildJSON($conn);	
	}
	$conn->disconnect();
}

print $json;

exit 0;


sub getDatabaseConnection
{
	our $host=shift;
	our $db=shift;
	our $un=shift;
	our $pw=shift;
	our $connection;

	if(!($connection=DBI->connect("DBI:mysql:$db;host=$host", $un, $pw, { RaiseError => 1 })))
	{
		$json=sprintf('"status":"ER", "msg":"Error Connecting to Database, Contact Support Staff with the information below<br />%s"', $DBI::errstr);
		return 0;
	}
	
	return $connection;
}

sub buildJSON
{
	our $connection=shift;
	our $statement=$conn->prepare("SELECT concat(contactLastName, ', ', contactFirstName), contactExtension, contactMobilePhone, contactHomePhone, contactRole FROM contact ORDER BY contactLastName, contactFirstName");
	our ($name, $ext, $mobile, $home, $role);
	
	$statement->execute();

	$statement->bind_columns(\$name, \$ext, \$mobile, \$home, \$role);
	
	our $text;
	our $ix=0;
	while($statement->fetchrow())
	{
		
		$text.=', ' if $ix>0;
		$text.=sprintf('["%s","%s","%s","%s","%s"]', $name, $ext, $mobile, $home, $role);

		$ix++;
	}
	
	$json=sprintf('{"sEcho":%d, "iTotalRecords":%d, "iTotalDisplayRecords":%d, "aoColumns": [ {"sTitle": "Associate Name", "sWidth": "60px", "bSortable": "false" }, { "sTitle": "Extension" , "sType": "mytext", "sClass": "center", "sWidth": "60px"}, { "sTitle": "Mobile Phone" , "sWidth": "60px" }, { "sWidth": "60", "sTitle": "Home Phone" }, { "sWidth": "160px", "sTitle": "Role" } ], "aaData": [%s]}', 20, $ix, $ix, $text);
	
	$statement->finish;	
}
