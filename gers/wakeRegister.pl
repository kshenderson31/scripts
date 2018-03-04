#********************************************************************************************************************************************************************
# 
#********************************************************************************************************************************************************************
#
# Add status switch

use strict;
#kuse warnings;

use Net::Ping;
use Net::Telnet;
use MIME::Lite;
use Getopt::Std;
use DBI;
use DBD::Oracle;

our %opt;
our $ok=0;
our $no=0;

our $sql = <<__SQL__;
SELECT NVL(p.loc, 'UNK'), 
       p.store_cd, 
       CASE
         WHEN p.term_num = '01' THEN 'A'
         WHEN p.term_num = '02' THEN 'B'
         WHEN p.term_num = '03' THEN 'C'
         WHEN p.term_num = '04' THEN 'D'
         WHEN p.term_num = '05' THEN 'E'
         WHEN p.term_num = '06' THEN 'F'
         WHEN p.term_num = '07' THEN 'G'
         WHEN p.term_num = '08' THEN 'H'
         WHEN p.term_num = '09' THEN 'I'
         WHEN p.term_num = '10' THEN 'J'
         WHEN p.term_num = '11' THEN 'K'
         WHEN p.term_num = '12' THEN 'L'
         WHEN p.term_num = '13' THEN 'M'
         WHEN p.term_num = '14' THEN 'N'
         WHEN p.term_num = '15' THEN 'O'
         WHEN p.term_num = '16' THEN 'P'
         WHEN p.term_num = '17' THEN 'Q'
         WHEN p.term_num = '18' THEN 'R'
         WHEN p.term_num = '19' THEN 'S'
         WHEN p.term_num = '20' THEN 'T'
         WHEN p.term_num = '21' THEN 'U'
         WHEN p.term_num = '22' THEN 'V'
         WHEN p.term_num = '23' THEN 'W'
         WHEN p.term_num = '24' THEN 'X'
         WHEN p.term_num = '25' THEN 'Y'
         WHEN p.term_num = '26' THEN 'Z'
       END, 
       p.rgstr_ip_addr, 
       p.rgstr_stat_cd, 
       CASE
         WHEN p.loc = 'DFW' THEN '7031'
         ELSE                   '7'||SUBSTR(s.op_dist_cd,2,3)
       END
  FROM polling p,
       store s
WHERE p.rgstr_stat_cd NOT IN ('C')
  AND s.store_cd = p.store_cd
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
	getopts("a:dp:r:s:t:FW", \%opt);
	
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

	sendErrorMessage("Wake Registers Database Error", $message);

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
	our $port;
	our $statementHandler;
	
	printChronologicalMessage("Locating Store Information", "N");

	if(!($statementHandler=$databaseHandler->prepare($sql)))
	{
		databaseError("Prepare failed in buildHashes");
	}

	if(!($statementHandler->execute()))
	{
		databaseError("Statement execution failed in buildHashes");
	}

	$statementHandler->bind_columns(undef, \$location, \$storeNumber, \$terminalNumber, \$ipAddress, \$registerStatusCode, \$port);

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
		
		if(defined $opt{'r'})
		{
			$opt{'s'}=substr($opt{'r'},0,4);
			if(length($opt{'r'})==5)
			{
				$opt{'t'}=substr($opt{'r'},4,1);	
			}
		}

		if(defined $opt{'s'})
		{
			next if $storeNumber != $opt{'s'};
		}
		
		if(defined $opt{'t'})
		{
			next if $terminalNumber ne $opt{'t'};
		}	
		
		printChronologicalMessage(" ");
		printChronologicalMessage("Pinging \[$location\] $storeNumber$terminalNumber at $ipAddress \[$registerStatusCode\]", "Y", "Y");
		
		pingRegister($p, $ipAddress);
		
		printChronologicalMessage(" ");
		printChronologicalMessage("Accessing \[$location\] $storeNumber$terminalNumber at $ipAddress on $port \[$registerStatusCode\]", "N", "N");
		registerSession($ipAddress, $port);		
	}
	
	printChronologicalMessage(" ", "N");
	
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
	our $retry=0;
	
	if(!(open(PS,"ping -c 20 -w 1 $ip |"))) 
	{
		printChronologicalMessage("Ping execution failed", "N");
		exit 0;
	}
	
	while ( <PS> )
	{
		chomp($_);
		printChronologicalMessage("$_", "N");
		$retry=1 if index($_, "100% packet loss") >= 0;
	}
	
	if($retry)
	{
		printChronologicalMessage(" ");
		printChronologicalMessage("100% packet loss, retrying 10 pings", "N");
		if(!(open(PS,"ping -c 10 -w 1 $ip |"))) 
		{
			printChronologicalMessage("Ping execution failed", "N");
			exit 0;
		}
		
		while ( <PS> )
		{
			chomp($_);
			printChronologicalMessage("$_", "N");
		}	
	}
}
#*****************************************************************************
# Ping The Register
#*****************************************************************************
#
sub registerSession
{
	our $ip=shift;
	our $port=shift || 23;
	our $session=new Net::Telnet (Timeout=>10, Port=>$port, Telnetmode=>0, Errmode=>"return");
    
    if(!($session->open($ip)))
    {
    	printChronologicalMessage(", Session not established", "N", "Y", "N");
    }
    else
    {	
    	$ok++;
    	$session->dump_log("/var/log/mlink.dump.$ip.log");
    	$session->output_log("/var/log/mlink.output.$ip.log");
    	printChronologicalMessage(", Session established", "N", "N", "N");
    	if(!($session->login("mlink", "mlink")))
    	{
    		printChronologicalMessage(", Login failed", "N", "Y", "N");
    	}
    	else
    	{
    		printChronologicalMessage(", Session established", "N", "Y", "N");
    	}
    	$session->close;
    }
}
#*****************************************************************************
#
#*****************************************************************************
#
sub wakeMeUp
{
	our $conn=shift;
	our (undef, $min, $hour)=localtime(time);
	our $base=($hour * 60) + $min;
	
	open(SCH, "</var/log/mlink/sched.out");
	
	
	while(<SCH>)
	{
		chomp($_);
		
		our($site, $task, $seq, undef, $undef, $time)=split(/\|/, $_);
		our $timer=(substr($time, 0, 2) * 60) + substr($time, 2, 2); 
		next if $seq ne "000";
		next if $site eq "XBR" || $site eq "EVENT";
		
		our $slice=$timer - $base;
		
		if(defined $opt{'F'})
		{
			printChronologicalMessage("Waking $site($slice)");
				
			$opt{'r'}=$site;
			
			processRegisters($conn);
		}
		else
		{
			if($slice < 1 || $slice > 15)
			{
				#print LOG "[".getFormattedDateAndTime("mmmm dd, yyyy hr:mn:sc")."] Bypassing site $site\n";
			}
			else
			{
				printChronologicalMessage("Waking $site($slice)");
				
				$opt{'r'}=$site;
				
				processRegisters($conn);
			}
		}
	}
	
	close SCH;	
	close LOG;
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
	our $subject=shift || "[Failure] Wake Registers";
	our $body=shift;
	
    our $msg = MIME::Lite->new(
            From    => '"Wake Registers Script"<noreply@paradies-na.com>',
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
    
    if(defined $opt{'W'})
    {
    	print LOG "[".getFormattedDateAndTime("mmmm dd, yyyy hr:mn:sc")."] " if uc $ts eq "Y";
    	print LOG $msg;
    	print LOG "\n" if uc $eol eq "Y";
    }
    
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
	getOptions();
	
	open(LOG, ">/var/log/mlink/wake.".getFormattedDateAndTime("yyyy.MM.dd.hr.mn").".log") if defined $opt{'W'};
	
	printChronologicalMessage("$0 Started");
	
	our $connection=getDatabaseConnection("paradies", "genret", 1521, undef, undef);
	
	if(defined $opt{'W'})
	{
		wakeMeUp($connection);	
	}
	else
	{
		processRegisters($connection);	
	}
	
	if(defined $opt{'W'})
	{
		printChronologicalMessage("Purging old files");
		system("find /var/log/mlink -type f -mtime +3 -exec gzip {} \\;");
		system("find /var/log/mlink -type f -mtime +5 -exec rm -f {} \\;");	
	}
			
	printChronologicalMessage("$0 Ended");
	
	close LOG if defined $opt{'W'};
}