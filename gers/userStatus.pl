#!/usr/opt/perl15_64/bin/perl
use lib '/usr/local/bin/tps/modules';
use strict;
use warnings;

use DBI;
use DBD::Oracle;
use Getopt::Std;

our %opt;
our %exclude;

setExclusions();

getOptions();

#usage() if scalar(@ARGV) == 0;
usage() if $opt{'h'};

my $ORACLE_SID="genret";
my $LD_LIBRARY_PATH="/opt/perl-5.10.1/instantclient/instantclient_11_2";

$ENV{LD_LIBRARY_PATH}="/opt/perl-5.10.1/instantclient/instantclient_11_2";

our $dbh = DBI->connect('dbi:Oracle:host=paradies;sid=genret;port=1521', 'system', 'genret',{RaiseError => 1,AutoCommit => 0}) || die "Database connection not made: $DBI::errstr";
our $sth;
our $sql;

print "=================================================\n";
print "Processing Users\n";
print "=================================================\n";


if(defined {$opt{'e'}})
{
	addExclusions();
}

if(defined $opt{'i'})
{
	processUser($opt{'i'}, 'LOCK') if $opt{'l'};
	processUser($opt{'i'}, 'UNLOCK') if $opt{'u'};
} 
else
{
	if(defined $opt{'g'})
	{
		processGroup($opt{'g'});		
	}
	else
	{
		open(USR, "<$opt{'f'}");
		
		while(<USR>)
		{
			chomp($_);
			
			print "(Test) Processing user $_\n" if defined $opt{'t'};
			next if defined $opt{'t'};
			
			processUser(uc $_, 'LOCK') if $opt{'l'};
			processUser(uc $_, 'UNLOCK') if $opt{'u'};	
		}
		
		close USR;	
	}
}

print "=================================================\n";
print "Done\n";
print "=================================================\n";

$dbh->disconnect;

sub setExclusions
{
	
	$exclude{"SYSTEM"}="Yes";
	$exclude{"SYS"}="Yes";
	$exclude{"KEHENDER"}="Yes";
	$exclude{"TFYARBRO"}="Yes";
	$exclude{"WMUNDEN"}="Yes";
	$exclude{"RAHMED"}="Yes";
	$exclude{"LPUTNEL"}="Yes";
	$exclude{"CMATTERN"}="Yes";
	
	$exclude{"GENESIS"}="Yes";
	$exclude{"GEN"}="Yes";
	$exclude{"GERS"}="Yes";
	$exclude{"MDMUSR"}="Yes";
	
	$exclude{"AP"}="Yes";
	$exclude{"AR"}="Yes";
	$exclude{"DEV"}="Yes";
	$exclude{"DW"}="Yes";
	$exclude{"GL"}="Yes";
	$exclude{"GM_INV"}="Yes";
	$exclude{"GM_MERCH"}="Yes";
	$exclude{"MISC"}="Yes";
	$exclude{"PRC"}="Yes";
	$exclude{"REPORTSQ"}="Yes";
	$exclude{"TKT"}="Yes";
	$exclude{"WHS"}="Yes";
	$exclude{"WAREHOUSE"}="Yes";
	
}

sub addExclusions
{
	if(open(EXC, "<$opt{'e'}"))
	{
		while(<EXC>)
		{
			chomp($_);
			$exclude{uc $_}="Yes";	
			print "Adding exclusion for user $_\n";	
		}
		close EXC;	
	}	
	else
	{
		print "Could not open exclusions file, $opt{'e'}\n";
		print "$!\n";
	}	
}

sub getOptions
{
	getopts("hi:luf:g:t", \%opt);
	
#	if(!(defined $opt{'l'} || defined $opt{'u'}))
#	{
#		usage();
#	}
#	
#	if(defined $opt{'l'} && defined $opt{'u'})
#	{
#		usage();
#	}
#	
#	if(!(defined $opt{'i'} || defined $opt{'g'} || $opt{'f'}))
#	{
##		usage();
##	}	
	
}

sub usage
{
	print "Usage: userStatus.pl [-i<user>|-g<usergroup>|-f<filename>] [-l|-u] {-t}\n";
	print "\n";
	print "Switch\t\tAction\n";
	print "-i<user>\tSpecify a single user id to be locked or unlocked.\n";
	print "-g<group>\tSpecify an Oracle user group to be locked or unlocked.\n";
	print "-f<file>\tSpecify a file containing a list of userids to be locked or unlocked.\n";
	print "\n";
	print "-l\t\tLock the specified user(s).\n";
	print "-u\t\tUnlock the specified user(s).\n";
	print "\n";
	print "-t\t\tTest Mode.  Display users to be acted on, but do not take action.\n";
	
	exit 0;
}

sub processUser
{
	our $user=shift;
	our $status=shift;
	
	$user=uc $user;
    $status=uc $status;
    
    print "(Test) Processing user $user\n" if defined $opt{'t'};
	return if defined $opt{'t'};
	
	$sth = $dbh->prepare("ALTER USER $user ACCOUNT $status");
    $sth->execute();
    $sth->finish();
    	
    print "User $user($status)\n";
}

sub processGroup
{
	our $group=shift;
	
	$group=uc $group;
	
	my $sequel = "SELECT username FROM dba_users WHERE profile=\'$group\' ORDER BY username";
	my $statement = $dbh->prepare($sequel);
	
	$statement->execute();

	my($uid);                     # Declare columns
	$statement->bind_columns(undef, \$uid);
	
	while($statement->fetch()) 
	{
		next if index($uid, "OPS\$") >= 0;
		
		print "Bypassing user $uid based on exclusions\n" if defined $exclude{$uid};
		next if defined $exclude{$uid};
		
		print "(Test) Processing user $uid\n" if defined $opt{'t'};
		next if defined $opt{'t'};
		
	    processUser($uid, 'LOCK') if $opt{'l'};
		processUser($uid, 'UNLOCK') if $opt{'u'};
	}
	$statement->finish();
}
