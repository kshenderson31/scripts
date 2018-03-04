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
use MIME::Lite;

our %opt;
our $databaseHandler;

our $sql = <<'__SQL__';
select sum(active),
       sum(inactive),
       sum(sniped),
       sum(killed),
       sum(cached)
  from
    (
      select case when status = 'ACTIVE'   then 1 else 0 end as active,
             case when status = 'INACTIVE' then 1 else 0 end as inactive,
             case when status = 'SNIPED'   then 1 else 0 end as sniped, 
             case when status = 'KILLED'   then 1 else 0 end as killed, 
             case when status = 'CACHED'   then 1 else 0 end as cached 
        from v$session
    )      
__SQL__

our $body = <<'__BODY__';
The maximum numbers of GERS sessions has been reached. At this time no additional users can logon to the system until currently active sessions<br>
have completed and disconnected from the system.<br>
<br>
If you are logged onto the GERS system and not actively working, please logoff the system to allow others to use the system and complete their work.
__BODY__

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
	getSessions($databaseHandler);
	
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
# Get Sessions
#********************************************************************************************************************************************************************
#
sub getSessions
{
    our $dbh=shift;
    our $active;
    our $inactive;
    our $sniped;
    our $killed;
    our $cached;
    
    printChronologicalMessage("Checking Sessions", "N");
    
    our $result;
    our $active=0;
    our $statementHandler = $databaseHandler->prepare($sql);
	
	if(!($statementHandler->execute()))
	{
		if(index(DBI::errstr, "ORA-00020") >= 0)
		{
			printChronologicalMessage("Maximum Sessions Exceeded", "N");
			sendMailMessage();
		}		
	}
	else
	{
		$statementHandler->bind_columns(undef, \$active, \$inactive, \$sniped, \$killed, \$cached);
    	$statementHandler->fetch();
    	
    	printChronologicalMessage("Active($active) Inactive($inactive) Sniped($sniped) Killed($killed) Cached($cached)", "N");
    	
		$statementHandler->finish;	
	}
}
#********************************************************************************************************************************************************************
# Send Email
#********************************************************************************************************************************************************************
#
sub sendMailMessage
{
	our $msg;
	
	printChronologicalMessage("Sending Communication on Sessions", "N");
	
	$msg = MIME::Lite->new(
    	    From    => '"IT Service Center"<itservicecenter@paradies-na.com>',
    	    To      => 'kehenderson@paradies-na.com',
       		Subject => "Maximum GERS Sessions Reached",
        	Type    => 'text/html',
        	Data    => $body
    	);
	
	$msg->send('smtp','mail1.tpscorp.theparadiesshops.com', Debug=>0 );
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