#!C:/strawberry/perl/bin/perl.exe
use strict;
use warnings;

use CGI;
use DBI;
use DBD::mysql;

our $conn;
our $json;
our $cgi=CGI->new;

print $cgi->header(-type => "application/json", -charset => "utf-8");

$json="{";
if($conn=getDatabaseConnection("svc", "root", 'tiger31'))
{
	buildJSON($conn);

	$conn->disconnect();
}

$json.="}";
print $json;

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
	our $statement=$conn->prepare("SELECT pageElementHTML FROM pageelement WHERE pageElementID = ?");
	our $pageElementHTML;
	
	$statement->execute($cgi->param("id"));

	$statement->bind_columns(\$pageElementHTML);
	$json.=sprintf('"status":"OK", "html":"%s');
	
	while($statement->fetchrow())
	{
		$pageElementHTML=~s/"/&doub;/g;
		$pageElementHTML=~s/'/&sing;/g;
	}
	
	our @lines=split("\n", $pageElementHTML);
	foreach(@lines)
	{
		chomp($_);
		my $string=$_;
		$string =~ s/^\s+//; #remove leading spaces
		$string =~ s/\s+$//; #remove trailing spaces
		$json.=$string;
	}
	$json.='"';
	
	$statement->finish;	
}
