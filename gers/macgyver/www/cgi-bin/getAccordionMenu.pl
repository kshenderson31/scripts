#!C:/strawberry/perl/bin/perl.exe
use strict;
use warnings;

use CGI;
use DBI;
use DBD::mysql;

our %scripts;
our $conn;
our $json;
our $cgi=CGI->new;

print $cgi->header(-type => "application/json", -charset => "utf-8");

if($conn=getDatabaseConnection("svc", "root", 'tiger31'))
{
	buildJSON($conn);

	$conn->disconnect();
}

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
		$json=sprintf('{"status":"ER", "msg":"Error Connecting to Database, Contact Support Staff with the information below<br />%s"}', $DBI::errstr);
		return 0;
	}
	
	return $connection;
}

sub buildJSON
{
	our $connection=shift;
	our $statement=$conn->prepare("SELECT * FROM accordionmenuitems WHERE accordionID = ?");
	our($accordionID, $accordionName, $accordionGroupName, $accordionItemName, $accordionItemHTML, $accordionItemClassName, $accordionItemClickAction);
	our $ix=0;
	our $last;
	
	$statement->execute($cgi->param("id") || 1);

	$statement->bind_columns(\$accordionID, \$accordionName, \$accordionGroupName, \$accordionItemName, \$accordionItemHTML, \$accordionItemClassName, \$accordionItemClickAction);
	$json='{"success":"OK", "html":"';
	
	while($statement->fetchrow())
	{
		####print "$accordionID, $accordionName, $accordionGroupName, $accordionItemName, $accordionItemHTML, $accordionItemClassName, $accordionItemClickAction\n";
		if($ix==0)
		{
			$last=$accordionGroupName;
			$json.="<h3><div class='accordionMenuItem topSpacerSmall bottomSpacerSmall'>&nbsp;$accordionGroupName</div></h3>";
			$json.="<ul class=accordionMenulList>";
		}
		
		if($accordionGroupName eq $last)
		{
			$json.="<li class=\'accordionMenuListSelection $accordionItemClassName\'><a href=&doub;#&doub;>&nbsp;&nbsp;$accordionItemName</a></li>";
		}
		else
		{
			$json.="</ul>";
			$json.="<h3><div class='accordionMenuItem topSpacerSmall bottomSpacerSmall'>&nbsp;$accordionGroupName</div></h3>";
			$json.="<ul class=accordionMenulList>";
			$json.="<li class=\'accordionMenuListSelection $accordionItemClassName\'><a href=&doub;#&doub;>&nbsp;&nbsp;$accordionItemName</a></li>";
		}
		
		$scripts{$accordionItemClassName}=$accordionItemClickAction;
		
		$last=$accordionGroupName;
		$ix++;
	}
	
	$json.='</ul>", "script":"';
	
#	our @lines=split("\n", $function);
#	foreach(@lines)
#	{
#		chomp($_);
#		my $string=$_;
#		$string =~ s/^\s+//; #remove leading spaces
#		$string =~ s/\s+$//; #remove trailing spaces
#		$json.=" $string";
#	}
	
	$json.=' $(document).ready(function() {';
	
	foreach our $key(sort keys %scripts)
	{
		our @lines=split("\n", $scripts{$key});
		foreach(@lines)
		{
			chomp($_);
			my $string=$_;
			$string =~ s/^\s+//; #remove leading spaces
			$string =~ s/\s+$//; #remove trailing spaces
			$json.=" $string";
		}
		#$scripts{$key}=~s/"/\\"/g;
		#$scripts{$key}=~s/{/\\{/g;
		#$scripts{$key}=~s/}/\\}/g;
		##$scripts{$key}=~s/\(/\(/g;
		#$scripts{$key}=~s/\)/\)/g;
		#$scripts{$key}=~s/\n//g;
		#print "key=$key|$scripts{$key}\n";
		#$json.=$scripts{$key};
	}
	
	$json.='});"}';	
	$statement->finish;	
}
