#!/usr/bin/perl
use strict;
use warnings;

use CGI;
use DBI;
use DBD::mysql;

our $conn;
our $json;
our $cgi=CGI->new;

our %os;
our %by;

our $ok=<<__OK__;
<DIV style=\\"width:138px; float:left;\\">
	<A href=\\"#\\"><IMG class=\\"tipPanda floatLeft\\" src=\\"images/thumbsUp.png\\" height=\\"128\\" width=\\"128\\" title=\\"Panda Installation\\" style=\\"margin-left:5px;\\"></A>
</DIV>
<DIV class=floatLeft style=\\"margin-left:5px;\\">
	<P id=content>
		<SPAN>Congratulations! Your computer is running ##op## and you can proceed with the installation of Panda.<BR /><BR />Either click on the thmbs up image to the left or <A HREF=\\"#\\">click here</A> to begin the Panda installation process.</A></SPAN>
	</P>
</DIV>
__OK__


our $no=<<__NO__;
<DIV style=\\"width:138px; float:left;\\">
	<IMG class=floatLeft src=\\"images/thumbsDown.png\\" height=\\"128\\" width=\\"128\\" title=\\"Panda Installation\\" style=\\"margin-left:5px;\\">
</DIV>
<DIV class=floatLeft style=\\"margin-left:5px;\\">
	<P id=content>
		<SPAN>Unfortunately your computer does not support Panda at the moment.<BR /><BR />
	</P>
</DIV>
__NO__


print $cgi->header(-type => "application/json", -charset => "utf-8");
#print $cgi->header(-type => "text/html", -charset => "utf-8");

our $opParm=$cgi->param("os");
our $uaParm=$cgi->param("ua");

loadHashes();

if(evaluateOperatingSystem())
	{
		buildSuccessMarkup();	
	}
	else
	{
		buildFailureMarkup();
	}

#if($conn=getDatabaseConnection("svc", "root", 'tiger31'))
#{
#	
#	$conn->disconnect();
#}

print "$json";

exit 0;

sub loadHashes
{
	while(<DATA>)
	{
		chomp($_);
		
		our($string, $opsys, $allow)=split(",", $_);
		
		$os{$string}="$allow$opsys";
		$by{$opsys}="$allow";
	}	
}

sub evaluateOperatingSystem
{
	our $found=0;
	
	foreach our $op(sort keys %os)
	{
		if(index($cgi->param("os"), $op) >= 0)
		{
			my $name=substr($os{$op}, 1);
			
			$ok=~s/##op##/$name/;
			$no=~s/##op##/$name/;
			
			$found=1 unless substr($os{$op}, 0, 1) eq "N";
		}
	}
	return $found;
}


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

sub buildSuccessMarkup
{
	our $connection=shift;
	
	$ok=~s/\n//g;
	$ok=~s/\t//g;
	
	$json.=sprintf('{"status":"OK", "html":"%s"}', $ok);
}

sub buildFailureMarkup
{
	$no=~s/\n//g;
	$no=~s/\t//g;
	
	$json.=sprintf('{"status":"OK", "html":"%s"}', $no);
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


__DATA__
Win16,Windows 3.11,N
Windows 95,Windows 95,N
Win95,Windows 95,N
Windows_95,Windows 95,N
Windows NT 5.0,Windows 2000,Y
Windows 2000,Windows 2000,Y
Windows NT 5.1,Windows XP,Y
Windows XP,Windows XP,Y
Windows NT 5.2,Windows Server 2003,Y
Windows NT 6.0,Windows Vista,N
Windows NT 6.1,Windows 7,Y
Windows NT 4.0,Windows NT 4.0,Y
WinNT4.0,Windows NT 4.0,Y
WinNT,Windows NT 4.0,Y
#Windows NT,Windows NT 4.0,Y
Windows ME,Windows ME,Y
OpenBSD,Open BSD,Y
SunOS,Sun OS,Y
Linux,Linux,Y
X11,Linux,Y
Mac_PowerPC,Mac OS,Y
Macintosh,Mac OS,Y
QNX,QNX,N
BeOS,BeOS,N
OS/2,OS/2,N
