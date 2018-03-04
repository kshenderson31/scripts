#********************************************************************************************************************************************************************
# 
#********************************************************************************************************************************************************************
#
use strict;
use warnings;
#********************************************************************************************************************************************************************
# 
#********************************************************************************************************************************************************************
#
use DBI;
use DBD::Oracle;
use Getopt::Std;

our %opt;
our $databaseHandler;

#********************************************************************************************************************************************************************
# Main processing 
#********************************************************************************************************************************************************************
#
main();
exit 0;
#********************************************************************************************************************************************************************
# Main processing
#********************************************************************************************************************************************************************
#
sub main
{
	#****************************************************************************************************************************************************************
	# Beginning Message 
	#****************************************************************************************************************************************************************
	#
	printChronologicalMessage("$0 started", "N");
	#****************************************************************************************************************************************************************
	# Establish a connection with the database 
	#****************************************************************************************************************************************************************
	#
	our $databaseHandler=getDatabaseConnection("paradies", "genret", 1521, undef, undef);
	
	#****************************************************************************************************************************************************************
	# Get Command Line Options 
	#****************************************************************************************************************************************************************
	#
	getOptions();
	
	#****************************************************************************************************************************************************************
	# Check GERS Database Health 
	#****************************************************************************************************************************************************************
	#
	getActiveSessions($databaseHandler);
	checkBlockingSessions($databaseHandler);
	
	#****************************************************************************************************************************************************************
	# Close Database Connection 
	#****************************************************************************************************************************************************************
	#
	closeDatabaseConnection($databaseHandler);
	
	#****************************************************************************************************************************************************************
	# Ending Message 
	#****************************************************************************************************************************************************************
	#
	printChronologicalMessage("$0 ended", "N");	
}
#********************************************************************************************************************************************************************
# 
#********************************************************************************************************************************************************************
#
sub getOptions
{
	getopts("i:", \%opt);
}
#********************************************************************************************************************************************************************
# Get A Connection to the Database
#********************************************************************************************************************************************************************
#
sub getDatabaseConnection
{
	our $host=shift;
	our $sid=shift;
	our $port=shift || 1521;
	our $user=shift || 'system';
	our $pass=shift || 'genret';
	our $connection;

	printChronologicalMessage("Establishing connection to database", "N");
	
	$ENV{LD_LIBRARY_PATH}="/opt/perl-5.10.1/instantclient/instantclient_11_2";
		
	if(!($connection=DBI->connect("dbi:Oracle:host=$host;sid=$sid;port=$port", $user, $pass, {RaiseError => 1,AutoCommit => 0})))
	{
		print "Could not establish database connection to $host:$port:$sid\n";
		print $DBI::errstr;
		exit 1;
	} 
	
	return $connection;	
}
#********************************************************************************************************************************************************************
# Close Database Connection
#********************************************************************************************************************************************************************
#
sub closeDatabaseConnection
{
	our $connection=shift;
	printChronologicalMessage("Closing connection to database", "N");
	$connection->disconnect;
}
#********************************************************************************************************************************************************************
# Get Active Sessions
#********************************************************************************************************************************************************************
#
sub getActiveSessions
{
    our $dbh=shift;
    
    printChronologicalMessage(" ");
    printChronologicalMessage("Active Sessions");
    printChronologicalMessage(" ");
    
    our $result;
    our $active=0;
    our $sql=" SELECT 'User ' || username || '(' || osuser || ') logged on from ' || machine || ' via ' || program FROM V\$Session WHERE Status='ACTIVE' AND UserName IS NOT NULL";
    our $statementHandler = $databaseHandler->prepare($sql);
	
	$statementHandler->execute();
	
	$statementHandler->bind_columns(undef, \$result);
	
	while($statementHandler->fetch()) 
	{
		next if index($result, 'OPS$DAEMON') >= 0;
		printChronologicalMessage($result);
		$active++;
	}
	
	printChronologicalMessage(" ");
	printChronologicalMessage("$active active sessions found");
	
	$statementHandler->finish;
}
#********************************************************************************************************************************************************************
# Get Blocking Sessions
#********************************************************************************************************************************************************************
#
sub checkBlockingSessions
{
    our $dbh=shift;
    
    printChronologicalMessage(" ");
    printChronologicalMessage("Blocking Sessions");
    printChronologicalMessage(" ");
    
    our $result;
    our $blocks=0;
    our $sql="select s1.username || '\@' || s1.machine || ' ( SID=' || s1.sid || ' )  is blocking ' || s2.username || '\@' || s2.machine || ' ( SID=' || s2.sid || ' ) ' AS blocking_status
                from gv\$lock l1, gv\$session s1, gv\$lock l2, gv\$session s2
              where s1.sid = l1.sid
                and s2.sid = l2.sid
                and l1.BLOCK = 1
                and l2.request > 0
                and l1.id1 = l2.id1
                and l2.id2 = l2.id2";
    our $statementHandler = $databaseHandler->prepare($sql);
	
	$statementHandler->execute();
	
	$statementHandler->bind_columns(undef, \$result);
	
	while($statementHandler->fetch()) 
	{
		printChronologicalMessage($result);
		$blocks++;
	}
	
	printChronologicalMessage(" ");
	printChronologicalMessage("$blocks blocking sessions found");
	
	$statementHandler->finish;
}
#********************************************************************************************************************************************************************
# Send an error message via email
#********************************************************************************************************************************************************************
#
sub printChronologicalMessage
{
    my $msg = shift;
    my $log = shift || "Y";
    
    print "[".getFormattedDateAndTime("mmmm dd, yyyy hr:mn:sc")."] $msg\n";

	#$body .= "$msg<br>" if $log eq "Y";    
}
#********************************************************************************************************************************************************************
# Get the date and time
#********************************************************************************************************************************************************************
#
sub getFormattedDateAndTime
{
	my $format     = shift;
	
	my @monthAbbr  = qw( Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec );
	my @monthNames = qw( January February March April May June July August September October November December );
	my @days       = qw( Sunday Monday Tuesday Wednesday Thursday Friday Saturday );
	my @daysAbbr   = qw( Sun Mon Tue Wed Thu Fri Sat );
	my %numbers;
	
	for my $number(0..60)
	{
		$numbers{$number} = sprintf("%02d", $number);
        if($number < 10)
        {
            my $n = sprintf("%02d", $number);
            $numbers{$n} = $n;
        }
	}
	      
	my ($currSeconds, $currMinutes,$currHour, $currDay, $currMonth, $currYear, $currWeekDay, $currDayOfYear, $isdst) = localtime(time);	
	
	$currYear += 1900;
	$currMonth++;
	
	my $mthIndex = $currMonth - 1;
	my $return   = $format;
	my $yr       = substr($currYear,2,2);
	
	my $hrFmtd   = sprintf("%2d", $currHour);
	
	$currMonth = sprintf("%02d", $currMonth);
	$currDay   = sprintf("%02d", $currDay);
	
	$return =~ s/yyyy/$currYear/g;
	$return =~ s/yy/$yr/g;
	
	$return =~ s/mmmm/$monthNames[$mthIndex]/g;
	$return =~ s/mmm/$monthAbbr[$mthIndex]/g;
	$return =~ s/mm/$currMonth/g;
	$return =~ s/MM/$numbers{$currMonth}/g;
	
	$return =~ s/dd/$numbers{$currDay}/g;
	$return =~ s/d/$currDay/g;
	
	$return =~ s/www/$days[$currWeekDay]/g;
	$return =~ s/ww/$daysAbbr[$currWeekDay]/g;
	
	$return =~ s/hr/$numbers{$currHour}/g;
	$return =~ s/mn/$numbers{$currMinutes}/g;
	$return =~ s/sc/$numbers{$currSeconds}/g;
	
	$return =~ s/j/$currDayOfYear/g;
	
	return $return;
}