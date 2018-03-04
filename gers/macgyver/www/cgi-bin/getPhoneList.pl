#!/usr/bin/perl
use strict;
use warnings;

use CGI;
use DBI;
use DBD::mysql;

our $conn;
our $json;
our $cgi=CGI->new;

print $cgi->header(-type => "application/json", -charset => "utf-8");

if($conn=getDatabaseConnection("svc", "root", 'tiger31'))
{
	buildJSON($conn);

	$conn->disconnect();
}
else
{
	print $DBI::errstr;
}

print "$json";

exit 0;


sub getDatabaseConnection
{
	our $db=shift;
	our $un=shift;
	our $pw=shift;
	our $connection;
	
	if(!($connection=DBI->connect("DBI:mysql:$db", $un, $pw)))
	{
		$json=sprintf('"status":"ER", "msg":"Error Connecting to Database, Contact Support Staff with the information below<br />%s"', $DBI::errstr);
		return 0;
	}
	
	return $connection;
}

sub buildJSON
{
	our $connection=shift;
	our $sql ="SELECT concat(contactLastName, ', ', contactFirstName), ";
	    $sql.="       coalesce(contactExtension, '?'), ";
	    $sql.="       coalesce(contactMobilePhone, '?'), ";
	    $sql.="       coalesce(contactHomePhone, '?'), ";
	    $sql.="       coalesce(contactRole, '?'), ";
	    $sql.="       coalesce(contactCompanyName, '?'), ";
	    $sql.="       coalesce(contactMainPhone, '?'), ";
	    $sql.="       coalesce(contactOfficePhone, '?') ";
	    $sql.="  FROM contact ";
	    $sql.="WHERE contactTypeCode='".$cgi->param("id")."' " if $cgi->param("id") ne "all";
	    $sql.="ORDER BY contactLastName, contactFirstName";
	
	our $statement=$conn->prepare($sql);
	our ($name, $ext, $mobile, $home, $role, $company, $main, $office);
	
	$statement->execute();

	$statement->bind_columns(\$name, \$ext, \$mobile, \$home, \$role, \$company, \$main, \$office);
	
	our $text;
	our $ix=0;
	while($statement->fetchrow())
	{
		$text.=', ' if $ix>0;
		if($cgi->param("id") eq "it")
		{
			$text.=sprintf('["%s","%s","%s","%s","%s"]', $name, $ext, $mobile, $home, $role);
		}
		else
		{
			$text.=sprintf('["%s","%s","%s","%s","%s", "%s"]', $name, $company, $main, $office, $mobile, $role);	
		}

		$ix++;
	}
	
	if($cgi->param("id") eq "it")
	{
		$json=sprintf('{"sEcho":%d, "iTotalRecords":%d, "iTotalDisplayRecords":%d, "aoColumns": [ {"sTitle": "Associate Name", "sWidth": "60px", "bSortable": "true" }, { "sTitle": "Extension" , "sWidth": "60px", "bSortable": "true", "sClass":"center" }, { "sTitle": "Mobile Phone" , "sWidth": "60px", "bSortable": "true" }, { "sTitle": "Home Phone", "sWidth": "60px", "bSortable": "true" }, { "sTitle": "Role", "sWidth": "160px", "bSortable": "true" } ], "aaData": [%s]}', 20, $ix, $ix, $text);	
	}
	else
	{
		$json=sprintf('{"sEcho":%d, "iTotalRecords":%d, "iTotalDisplayRecords":%d, "aoColumns": [ {"sTitle": "Name", "sWidth": "60px", "bSortable": "true" }, { "sTitle": "Company" , "sWidth": "60px", "bSortable": "true", "sClass":"center" }, { "sTitle": "Main Office" , "sWidth": "60px", "bSortable": "true" }, { "sTitle": "Office Phone", "sWidth": "60px", "bSortable": "true" }, { "sTitle": "Mobile Phone", "sWidth": "160px", "bSortable": "true" }, { "sTitle": "Role", "sWidth": "160px", "bSortable": "true" } ], "aaData": [%s]}', 20, $ix, $ix, $text);
	}
	
	$statement->finish;	
}
