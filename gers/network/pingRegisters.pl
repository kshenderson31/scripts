#********************************************************************************************************************************************************************
# 
#********************************************************************************************************************************************************************
#
# Add status switch

use strict;
use warnings;

use Net::Ping;
use MIME::Lite;
use Getopt::Std;
use DBI;
use DBD::Oracle;

our %opt;
our $ok=0;
our $no=0;

our $sql = <<__SQL__;
SELECT NVL(loc, 'UNK'), store_cd, term_num, rgstr_ip_addr, rgstr_stat_cd
  FROM polling
WHERE rgstr_stat_cd NOT IN ('C')
ORDER BY 1, 2, 3  
__SQL__
#*****************************************************************************
# Flush STDOUT buffer
#*****************************************************************************
#
$|=1;
#*****************************************************************************
# Execute main
#*****************************************************************************
#
main();
exit 0;
#********************************************************************************************************************************************************************
# Get Command Line Options 
#********************************************************************************************************************************************************************
#
sub getOptions
{
	#A-Alert
	#
	getopts("a:dtA", \%opt);
}
#********************************************************************************************************************************************************************
# Database Error
#********************************************************************************************************************************************************************
#
sub databaseError
{
	our $message=shift;
	our $abend=shift || "Y";

	printChronologicalMessage("A database error has occurred");
	printChronologicalMessage(" ");
	printChronologicalMessage("$message");
	printChronologicalMessage(sprintf("Error Code: %s", $DBI::err));
	printChronologicalMessage(sprintf("State     : %s", $DBI::state));
	printChronologicalMessage(sprintf("Message   : %s", $DBI::errstr));

	$message.="\n\n";
	$message.="A database error has occurred.\n\n";
	$message.="The database error code is ".$DBI::err." and the database state is ".$DBI::state.".  The database message text is below.\n";
	$message.=$DBI::errstr;

	sendErrorMessage("Ping Registers Database Error", $message);

	exit 1 if uc $abend eq "Y";
}
#********************************************************************************************************************************************************************
# Process Registers 
#********************************************************************************************************************************************************************
#
sub processRegisters
{
	our $databaseHandler=shift;
	our $location;
	our $storeNumber;
	our $terminalNumber;
	our $ipAddress;
	our $registerStatusCode;
	our $statementHandler;
	
	printChronologicalMessage("Gathering data", "N");

	if(!($statementHandler=$databaseHandler->prepare($sql)))
	{
		databaseError("Prepare failed in buildHashes");
	}

	if(!($statementHandler->execute()))
	{
		databaseError("Statement execution failed in buildHashes");
	}

	$statementHandler->bind_columns(undef, \$location, \$storeNumber, \$terminalNumber, \$ipAddress, \$registerStatusCode);

	printChronologicalMessage("Processing results", "N");

	our $p = Net::Ping->new("icmp", 1, 8);
	
	while($statementHandler->fetch()) 
	{
		next if not defined $ipAddress;
		next if uc $ipAddress eq "MICRO";
		next if uc $ipAddress eq "MICRO";
		next if index($ipAddress, "0.0.0.0") >= 0;
		next if uc $location eq "UNK";
		
		if(defined $opt{'a'})
		{
			next if uc $location ne uc $opt{'a'};	
		}
		
		printChronologicalMessage("Pinging \[$location\] $storeNumber-$terminalNumber at $ipAddress \[$registerStatusCode\]", "N", "N");
		my $ping=pingRegister($p, $ipAddress);		
	}
	
	printChronologicalMessage(" ", "N");
	printChronologicalMessage("$ok successful pings, $no failed pings ", "N");
	
	$statementHandler->finish;
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

	if(!($connection=DBI->connect("dbi:Oracle:host=$host;sid=$sid;port=$port", $user, $pass, {RaiseError=>1, AutoCommit=>0})))
	{
		databaseError("Could not establish database connection to $host:$port:$sid");
	} 

	return $connection;	

}
#*****************************************************************************
# Ping The Register
#*****************************************************************************
#
sub pingRegister
{
	our $p=shift;
	our $ip=shift;
	our $try=1;
	
	while($try <= 10)
	{
		if($p->ping($ip))
		{
			$try=98;
		}
		$try++;
	}
	
	printChronologicalMessage(", Failed ping, register is not reachable", "N", "Y", "N") if $try != 99;
	$no++ if $try != 99;
	return 0 if $try != 99;
	
	printChronologicalMessage(", Successful ping, register is reachable", "N", "Y", "N") if $try == 99;
	$ok++ if $try == 99;
	return 1 if $try == 99
}
#*****************************************************************************
# sendEmailMessage
#*****************************************************************************
#
sub sendMailMessage
{
	our $subject=shift || "[Success] Micros Sales Processing Status";
	our $body=shift;
	
    our $msg = MIME::Lite->new(
            From    => '"Micros Sales Processor"<noreply@paradies-na.com>',
            To      => 'kehenderson@paradies-na.com',
            Subject => $subject,
            Type    => 'text/html',
            Data    => $body
        );

	$msg->send('smtp','mail1.tpscorp.theparadiesshops.com', Debug=>0 );
}

#*****************************************************************************
# sendErrorMessage
#*****************************************************************************
#
sub sendErrorMessage
{
	our $subject=shift || "[Failure] Micros Sales Processing Status";
	our $body=shift;
	
    our $msg = MIME::Lite->new(
            From    => '"Micros Sales Processor"<noreply@paradies-na.com>',
            To      => 'kehenderson@paradies-na.com',
            Subject => $subject,
            Type    => 'text/html',
            Data    => $body
        );

	$msg->send('smtp','mail1.tpscorp.theparadiesshops.com', Debug=>0 );
}

#********************************************************************************************************************************************************************
# Print Message with Date and Time
#********************************************************************************************************************************************************************
#
sub printChronologicalMessage
{
    my $msg = shift;
    my $log = shift || "Y";
    my $eol = shift || "Y";
    my $ts  = shift || "Y";

    print "[".getFormattedDateAndTime("mmmm dd, yyyy hr:mn:sc")."] " if uc $ts eq "Y";
    print $msg;
    print "\n" if uc $eol eq "Y";
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
#*****************************************************************************
# main
#*****************************************************************************
#
sub main
{
	printChronologicalMessage("$0 Started");
	
	printChronologicalMessage("Parsing Command Line Arguments");
	getOptions();
	
	our $connection=getDatabaseConnection("paradies", "genret", 1521, undef, undef);

	processRegisters($connection);
		
	printChronologicalMessage("$0 Ended");
	printChronologicalMessage(" ");
}