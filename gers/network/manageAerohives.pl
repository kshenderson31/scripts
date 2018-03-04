#********************************************************************************************************************************************************************
# 
#********************************************************************************************************************************************************************
#
# Add status switch

use strict;
use warnings;

use Net::Appliance::Session;
use Net::SSH::Perl;
use Net::OpenSSH;
use MIME::Lite;
use Getopt::Std;
use DBI;
use DBD::Oracle;
use Data::Dumper;

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
$Net::OpenSSH::debug |= 16;
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
	getopts("a:dp:tA", \%opt);
	
	$opt{'p'}=$opt{'p'} || 10;
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
sub processDevices
{
	our $databaseHandler=shift;
	our $desc;
	our $ipAddress;
	our $credentials;
	
	while(<DATA>)
	{
		chomp($_);
		
		next if substr($_, 0, 1) eq "#";
		
		($desc, $ipAddress, $credentials)=split(",", $_);
		
		printChronologicalMessage("Attempting to Access $desc at $ipAddress", "N");
		deviceSession($ipAddress, $credentials);
	}	
	printChronologicalMessage(" ", "N");
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
# 
#*****************************************************************************
#
sub deviceSession
{
	our $ip=shift;
	our $credentials=shift;
	our $session;
	
	printChronologicalMessage("\tEstablishing SSH Session", "N", "Y", "Y");
	#$session=Net::OpenSSH->new($ip, user=>'admin', password=>$credentials);
	#if($session->error)
	
	if(!($session=Net::Appliance::Session->new({personality=>'ios', transport=>'SSH', host=>"$ip"})))
	#if(!($session=Net::SSH::Perl->new($ip, debug=>1)))
	{
		printChronologicalMessage("\tSession Could Not Be Established", "N", "Y", "Y");
		printChronologicalMessage("\t".$session->error, "N", "Y", "Y");
	}
	else
	{
		##$session->set_global_log_at('debug');
		printChronologicalMessage("\tAttempting to Login To Device", "N", "Y", "Y");
		if(!($session->connect(username=>"admin", password=>$credentials, SHKC=>0)))
	    #if(!($session->login("admin", $credentials)))
	    {
	    	printChronologicalMessage("\tLogin Failed", "N", "Y", "Y");
	    }	
	    else
	    {
	    	printChronologicalMessage("\tLogin Successful", "N", "Y", "Y");
			sshCommand($session, "show version");
			sshCommand($session, "show route");
			sshCommand($session, "quit");
	    }
	    
	    $session->close;
	}
    #my($stdout, $stderr, $exit) = $ssh->cmd($cmd);
}
#*****************************************************************************
# 
#*****************************************************************************
#
sub sshCommand
{
	our $session=shift;
	our $command=shift;
	our $abend=shift || "Y";
	 
	printChronologicalMessage("\tExecuting command($command)", "N", "Y", "Y");
	
	our @result=$session->cmd($command);
	foreach(@result)
	{
		chomp($_);
		printChronologicalMessage("\t$_", "N", "Y", "Y");
	}
	printChronologicalMessage("="x80, "N", "Y", "Y");
	printChronologicalMessage(" ", "N", "Y", "Y");
	
	
	
#	$session->system($command);
#	if($session->error)
#	{
#		printChronologicalMessage("\tExecution of Command Failed", "N", "Y", "Y");
#		printChronologicalMessage("\t".$session->error, "N", "Y", "Y");
#		return 0;
#	}
	
	#my ($out, $err) = $session->capture2("$command");
	###our @result = $session->capture($command);
#	if($session->error)
#	{
#		printChronologicalMessage("\tExecution of Command Failed", "N", "Y", "Y");
#		printChronologicalMessage("\t".$session->error, "N", "Y", "Y");
#		return 0;
#	}
#	
#	print "|$out|$err|\n";
#	foreach(@result)
#	{
#		printChronologicalMessage("\t$_", "N", "Y", "Y");
#	}
    
    return 1;
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
	
	######
	###our $connection=getDatabaseConnection("paradies", "genret", 1521, undef, undef);

	printChronologicalMessage("Processing Aerohive Devices");
	processDevices();
		
	printChronologicalMessage("$0 Ended");
	printChronologicalMessage(" ");
}

__DATA__
Name,10.253.0.1,93r0p9r9
Name,10.252.5.129,$eidarap