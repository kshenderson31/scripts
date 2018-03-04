#!/usr/bin/perl
use strict;
use warnings;

use CGI;

our $cgi=CGI->new;
our $json;
our $result;

our	$buffer = $ENV{'QUERY_STRING'};
our @pairs = split(/&/, $buffer);

print $cgi->header(-type => "application/json", -charset => "utf-8");

foreach(1..100)
{
	$result.="This is a sample line of output<br />";
}

foreach our $pair (@pairs)
{
	our ($name, $value) = split(/=/, $pair);
	$value =~ tr/+/ /;
	$value =~ s/%(..)/pack("C", hex($1))/eg;
	$result.=sprintf("|key|%s|value|%s|<br />", $name, $value);
}

printf('{"status":"OK", "results":"%s"}', $result);

exit 0;
