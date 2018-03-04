#********************************************************************************************************************************************************************
# acmParser.pl 
#********************************************************************************************************************************************************************
# Program Narrative
#
#
#
# -------------------------------------------------------------------------------------------------------------------------------------------------------------------
# Modification History
# -------------------------------------------------------------------------------------------------------------------------------------------------------------------
# Date               Author                Description
# =================  ====================  ==========================================================================================================================
# December 07, 2013  K Henderson           Initial coding
# =================  ====================  ==========================================================================================================================
#
use strict;
use warnings;
#********************************************************************************************************************************************************************
# 
#********************************************************************************************************************************************************************
#
use DBI;
use DBD::Oracle;
use MIME::Lite;
use Getopt::Std;
#********************************************************************************************************************************************************************
# Flush STDOUT buffer
#********************************************************************************************************************************************************************
#
$|=1;
#********************************************************************************************************************************************************************
# Global Variables
#********************************************************************************************************************************************************************
#
our $today;
our $yesterday;

our %opt;
our %acmSite;
our %event;
our %port;
our %sched;
our %task;

our %statusCode;
our %subStatusCode;
our %schedSubStatus;
our %regs;

our %polling;
our %store;
our %district;
our %noAnswer;

our $errors=0;
our $error="N";
our $body;
#********************************************************************************************************************************************************************
# Execute main
#********************************************************************************************************************************************************************
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
	getopts("m", \%opt);
}
#********************************************************************************************************************************************************************
# Parse File
#********************************************************************************************************************************************************************
#
sub getProcessingDates
{
	our $conn=shift;
	our $d1;
	our $d2;
	
	our $cursor = $conn->prepare("SELECT TO_CHAR(sysdate, 'YYYYMMDD') AS today, TO_CHAR(sysdate-1, 'YYYYMMDD') AS yesterday FROM dual");

    $cursor->execute;
    
    while (our $row=$cursor->fetchrow_hashref()) 
	{	
		$d1=$$row{'TODAY'};
		$d2=$$row{'YESTERDAY'};
	}
    $cursor->finish;
    
    printChronologicalMessage("Processing for $d1 and $d2", "N");
    
    return ($d1, $d2);
}
#********************************************************************************************************************************************************************
# Parse File
#********************************************************************************************************************************************************************
#
sub loadStatusCode
{
	our $code;
	our $message;
	our $fatal;
	
	open(STA, "</var/data/acm.status.codes");
	
	while(<STA>)
	{
		chomp($_);
		
		($code, $message, $fatal)=split(/\|/, $_);
		
		$statusCode{$code}->{'msg'}=$message;
		$statusCode{$code}->{'fatal'}="Yes" if defined $fatal;	
	}
	
	close STA;
}
#********************************************************************************************************************************************************************
# Parse File
#********************************************************************************************************************************************************************
#
sub loadSubStatusCode
{
	our $code;
	our $subCode;
	our $message;
	
	open(STA, "</var/data/acm.sub.status.codes");
	
	while(<STA>)
	{
		chomp($_);
		
		($code, $subCode, undef, $message)=split(/\|/, $_);
		
		$subStatusCode{$code}->{$subCode}=$message;
	}
	
	close STA;
}
#********************************************************************************************************************************************************************
# Parse File
#********************************************************************************************************************************************************************
#
sub loadSchedSubStatus
{
	our $code;
	our $subCode;
	our $message;
	
	open(STA, "</var/data/acm.sched.sub.status");
	
	while(<STA>)
	{
		chomp($_);
		
		($code, $message)=split(/\|/, $_);
		
		$schedSubStatus{$code}=$message;
	}
	
	close STA;
}
#********************************************************************************************************************************************************************
# Parse File
#********************************************************************************************************************************************************************
#
sub loadPolling
{
	our $conn=shift;
	our $key;
	our $ix=0;
	
	our $cursor = $conn->prepare("SELECT STORE_CD || TERM_NUM AS RGSTR_ID, STORE_CD, TERM_NUM, LOC, RGSTR_IP_ADDR, RGSTR_STAT_CD FROM polling ORDER BY store_cd, term_num");

    $cursor->execute;
    
    while (our $row=$cursor->fetchrow_hashref()) 
	{	
		$polling{$$row{'RGSTR_ID'}}->{'store'}=$$row{'STORE_CD'};
		$polling{$$row{'RGSTR_ID'}}->{'terminal'}=$$row{'TERM_NUM'};
		$polling{$$row{'RGSTR_ID'}}->{'location'}=$$row{'LOC'};
		$polling{$$row{'RGSTR_ID'}}->{'ip'}=$$row{'RGSTR_IP_ADDR'};
		$polling{$$row{'RGSTR_ID'}}->{'store'}=$$row{'RGSTR_STAT_CD'};
				
		our $acmKey="$$row{'STORE_CD'}$regs{$$row{'TERM_NUM'}}";
		
		$acmSite{$acmKey}->{'ipPOLL'}=$$row{'RGSTR_IP_ADDR'};
		$acmSite{$acmKey}->{'poll'}="Yes";
		$acmSite{$acmKey}->{'location'}=$$row{'LOC'};
		
		if(not defined $acmSite{$acmKey}->{'acm'})
		{
			$acmSite{$acmKey}->{'acm'}="No";
			$acmSite{$acmKey}->{'name'}="Not Defined";
			$acmSite{$acmKey}->{'ipACM'}="Not Defined";
			$acmSite{$acmKey}->{'port'}="Not Defined";
		}
		
		$ix++;
	}
    $cursor->finish;
    
    printChronologicalMessage("$ix rows loaded from POLLING table", "N");
}
#********************************************************************************************************************************************************************
# Parse File
#********************************************************************************************************************************************************************
#
sub loadStore
{
	our $conn=shift;
	our $ix=0;
	
	our $cursor = $conn->prepare("SELECT store_cd, store_name, op_dist_cd FROM store ORDER BY store_cd");

    $cursor->execute;
    
    while (our $row=$cursor->fetchrow_hashref()) 
	{
		$ix++;	
		$store{$$row{'STORE_CD'}}->{'name'}=$$row{'STORE_NAME'};
		$store{$$row{'STORE_CD'}}->{'district'}=$$row{'OP_DIST_CD'};
	}
    $cursor->finish;
    
    printChronologicalMessage("$ix rows loaded from STORE table", "N");
}
#********************************************************************************************************************************************************************
# Parse File
#********************************************************************************************************************************************************************
#
sub loadDistrict
{
	our $conn=shift;
	our $ix=0;
	
	our $cursor = $conn->prepare("SELECT op_dist_cd, des FROM op_dist ORDER BY op_dist_cd");

    $cursor->execute;
    
    while (our $row=$cursor->fetchrow_hashref()) 
	{
		$ix++;	
		$district{$$row{'OP_DIST_CD'}}->{'name'}=$$row{'DES'};
	}
    $cursor->finish;
    
    printChronologicalMessage("$ix rows loaded from OP_DIST table", "N");
}
#********************************************************************************************************************************************************************
# Parse File
#********************************************************************************************************************************************************************
#
sub parseFile
{
	our $filename=shift;
	our $logFileName=shift;
	our $handle;
	
	our $records=0;
	
	if(defined $logFileName)
	{
		open($handle, ">/var/log/mlink/$logFileName")
	}
	
	# Copy the log to /var/data/mlink
	#
	if(-f "/gers/mlink/genret/$filename")
	{
		# read directory and zip all .out files  .".getFormattedDateAndTime("yyyy-MM-dd")
		system("mv /gers/mlink/genret/$filename /var/log/mlink/$filename");
	}
	
	open(FIL, "</var/log/mlink/$filename");
	
	while(<FIL>)
	{
		chomp($_);
		
		$records++;
		
		#*************************************************************************************************************************************************************
		# 
		#*************************************************************************************************************************************************************
		#		
		if($filename eq "event.out")
		{
				
		}
		#*************************************************************************************************************************************************************
		# 
		#*************************************************************************************************************************************************************
		#		
		if($filename eq "port.out")
		{
				
		}
		#*************************************************************************************************************************************************************
		# 
		#*************************************************************************************************************************************************************
		#		
		if($filename eq "sched.out")
		{
			parseSched($_);
		}
		#*************************************************************************************************************************************************************
		# 
		#*************************************************************************************************************************************************************
		#		
		if($filename eq "task.out")
		{
				
		}
		#*************************************************************************************************************************************************************
		# 
		#*************************************************************************************************************************************************************
		#		
		if($filename eq "site1.out")
		{
			parseSite1($_);		
		}
		#*************************************************************************************************************************************************************
		# 
		#*************************************************************************************************************************************************************
		#
		if($filename eq "site2.out")
		{
			parseSite2($_);
		}
		
		#*************************************************************************************************************************************************************
		# 
		#*************************************************************************************************************************************************************
		#
		if($filename eq "log.out")
		{
			parseLog($_, $handle);
		}
	}
	
	close FIL;
	
	if(defined $logFileName)
	{
		close $handle;	
	}
	
	printChronologicalMessage("$records processed in $filename log", "N");
}
#********************************************************************************************************************************************************************
# Parse the sit1.out dump
#********************************************************************************************************************************************************************
#
sub parseSched
{
	our $record=shift;
	our $siteNumber;
	our $sessionName;
	our $seq;
	our $tasks;
	our $originator;
	our $startTime;
	our $stopTime;
	our $startDate;
	our $stopDate;
	our $interval;
	our $altSession;
	our $status;
	our $altExecution;
	our $statusTime;
	our $subStatus;
	our $lastStopTime;
	our $timeZoneOffset;
	
	our $action;
	our $type;
	our $date;
	
	($siteNumber, $sessionName, $seq)=split(/\|/, $record);

	if(uc $siteNumber eq "#EVENT" || uc $siteNumber eq "*DEFAULT" || uc $siteNumber eq "#XBR")
	{
		
	}
	else
	{
		if(length($siteNumber) eq 4)
		{
			$siteNumber=$siteNumber."A";
		}
		
		if($seq eq "000")
		{
			(undef, undef, undef, $tasks, $originator, $startTime, $stopTime, $startDate, $stopDate, $interval, $altSession, $status, $altExecution, $statusTime, $subStatus, $lastStopTime, $timeZoneOffset)=split(/\|/, $record);
			
			$sched{$siteNumber}->{'name'}=$sessionName;
			$sched{$siteNumber}->{'tasks'}=$tasks;
			$sched{$siteNumber}->{'originator'}=$originator;
			$sched{$siteNumber}->{'starttm'}=$startTime;
			$sched{$siteNumber}->{'stoptm'}=$stopTime;
			$sched{$siteNumber}->{'startdt'}=$startDate;
			$sched{$siteNumber}->{'stopdt'}=$stopDate;
			$sched{$siteNumber}->{'interval'}=$interval;
			$sched{$siteNumber}->{'altsess'}=$altSession;
			$sched{$siteNumber}->{'status'}=$status;
			$sched{$siteNumber}->{'altexec'}=$altExecution;
			$sched{$siteNumber}->{'stattm'}=$statusTime;
			$sched{$siteNumber}->{'substat'}=$subStatus;
			$sched{$siteNumber}->{'laststoptm'}=$lastStopTime;
			$sched{$siteNumber}->{'tzoffset'}=$timeZoneOffset;
		}
		else
		{
			if($seq eq "001")
			{
				(undef, undef, undef, $action, $type, $date)=split(/\|/, $record);
			
				$sched{$siteNumber}->{'action'}=$action;
				$sched{$siteNumber}->{'type'}=$type;
				$sched{$siteNumber}->{'date'}=$date;	
			}
			else
			{
				
			}
		}
	}
}
#********************************************************************************************************************************************************************
# Parse the sit1.out dump
#********************************************************************************************************************************************************************
#
sub parseSite1
{
	our $record=shift;
	our $siteNumber;
	our $siteStatus;
	our $baudRate;
	our $currentPriority;
	our $stopTime;
	our $type;
	our $priority;
	our $subStatus;
	our $primaryType;
	our $tasks;
	our $locked;
	our $group;
	our $sessionRetryLimit;
	our $retryDelay;
	our $currentRetry;
	our $currentPath;
	our $defaultKeys;
	our $timeZoneOffset;
	our $dst;
	our $sessionOriginator;
	our $systemType;
	our $serverType;
	our $serverSiteNumber;
	our $serviceType;
	our $portGroup;
	
	($siteNumber, $siteStatus, $baudRate, $currentPriority, $stopTime, $type, $priority, $subStatus, $primaryType, $tasks, $locked, $group, $sessionRetryLimit, $retryDelay, $currentRetry, $currentPath, $defaultKeys, $timeZoneOffset, $dst, $sessionOriginator, $systemType, $serverType, $serverSiteNumber, $serviceType, $portGroup)=split(/\|/, $record);

	if(uc $siteNumber eq "EVENT" || uc $siteNumber eq "*DEFAULT" || uc $siteNumber eq "XBR")
	{
		
	}
	else
	{
		if(length($siteNumber) eq 4)
		{
			$siteNumber=$siteNumber."A";
		}
		
		$acmSite{$siteNumber}->{'status'}=$siteStatus;
		$acmSite{$siteNumber}->{'baud'}=$baudRate;
		$acmSite{$siteNumber}->{'cpriority'}=$currentPriority;
		$acmSite{$siteNumber}->{'stop'}=$stopTime;
		$acmSite{$siteNumber}->{'type'}=$type;
		$acmSite{$siteNumber}->{'priority'}=$priority;
		$acmSite{$siteNumber}->{'substatus'}=$subStatus;
		$acmSite{$siteNumber}->{'ptype'}=$primaryType;
		$acmSite{$siteNumber}->{'tasks'}=$tasks;
		$acmSite{$siteNumber}->{'locked'}=$locked;
		$acmSite{$siteNumber}->{'group'}=$group;
		$acmSite{$siteNumber}->{'sessionretry'}=$sessionRetryLimit;
		$acmSite{$siteNumber}->{'rdelay'}=$retryDelay;
		$acmSite{$siteNumber}->{'cretry'}=$currentRetry;
		$acmSite{$siteNumber}->{'cpath'}=$currentPath;
		$acmSite{$siteNumber}->{'keys'}=$defaultKeys;
		$acmSite{$siteNumber}->{'tzoffset'}=$timeZoneOffset;
		$acmSite{$siteNumber}->{'dst'}=$dst;
		$acmSite{$siteNumber}->{'sessorig'}=$sessionOriginator;
		$acmSite{$siteNumber}->{'systype'}=$systemType;
		$acmSite{$siteNumber}->{'svrtype'}=$serverType;
		$acmSite{$siteNumber}->{'svrsitenbr'}=$serverSiteNumber;
		$acmSite{$siteNumber}->{'svctype'}=$serviceType;
		$acmSite{$siteNumber}->{'portgrp'}=$portGroup;
	}
}
#********************************************************************************************************************************************************************
# Parse the sit1.out dump
#********************************************************************************************************************************************************************
#
sub parseSite2
{
	our $record=shift;
	our $siteNumber;
	our $f2;
	our $f3;
	our $siteName;
	our $address;
	our $ipAddress;
	our $port;
	our $f6;
	our $credentials;
	our $user;
	our $password;
	
	($siteNumber, $f2, $f3, $siteName, $address, $f6, $credentials)=split(/\|/, $record);
	($ipAddress, $port)=split(/\,/, $address);
	($user, $password)=split(/\,/, $credentials);

	$ipAddress="None" if not defined($ipAddress);
	$port="None" if not defined $port;
	
	if(uc $siteNumber eq "EVENT" || uc $siteNumber eq "*DEFAULT" || uc $siteNumber eq "XBR")
	{
		
	}
	else
	{
		if(length($siteNumber) eq 4)
		{
			$siteNumber=$siteNumber."A";
		}
		
		$acmSite{$siteNumber}->{'acm'}="Yes";
		$acmSite{$siteNumber}->{'poll'}="No";
		$acmSite{$siteNumber}->{'name'}=$siteName;
		$acmSite{$siteNumber}->{'ipACM'}=$ipAddress || "Not Defined";
		$acmSite{$siteNumber}->{'ipPOLL'}="Not Defined";
		$acmSite{$siteNumber}->{'port'}=$port;
		
		if(not defined $port)
		{
			print "Port not defined....$siteNumber\n";
		}
		
		if ($ipAddress =~ m/^(\d{1,3})\.(\d{1,3})\.(\d{1,3})\.(\d{1,3})$/)
		{
		    if(($1>0) && ($1<=255) && ($2<=255) && ($3<=255) && ($4<=255))
		    {
		    	
		    }
		    else
		    {
		    	print "Not an IP Address[$ipAddress]\n";
		    }
		}
		else
		{
		    print "Not an IP Address[$ipAddress]\n";	
		}
	}
}	
#********************************************************************************************************************************************************************
# 
#********************************************************************************************************************************************************************
#
sub parseLog
{
	our $record=shift;
	our $fileHandle=shift;
	
	our $date;
	our $time;
	our $siteNumber;
	our $machineNumber;
	our $processNumber;
	our $port;
	our $status;
	our $subStatus;
	our $statusMessage;
	
	($date, $time, $siteNumber, $machineNumber, $processNumber, $port, $status, $subStatus, $statusMessage)=split(/\|/, $record);
	
	return if not defined $statusCode{$status}->{'fatal'};
	return if $date ne $today && $date ne $yesterday;
	
	if(length($siteNumber) eq 4)
	{
		$siteNumber=$siteNumber."A";	
	}
	
	my $sub=$subStatusCode{$status}->{$subStatus} || "<None>";
	my $loc=$acmSite{$siteNumber}->{'location'} || "UNK";
	
	print $fileHandle "$loc|$siteNumber|$date|$time|$machineNumber|$processNumber|$port|$status|$subStatus|$statusMessage|$statusCode{$status}->{'msg'}|$sub\n";
	
	if($status eq "5700" && $subStatus eq "007")
	{
		#print "$loc|$siteNumber|$date|$time|$machineNumber|$processNumber|$port|$status|$subStatus|$statusMessage|$statusCode{$status}->{'msg'}|$sub\n"; 
		$noAnswer{$loc}->{$siteNumber}="Yes";
	}
}
#********************************************************************************************************************************************************************
# 
#********************************************************************************************************************************************************************
#
sub reportLogErrors
{
	our $fileName=shift;
	
	our $location;
	our $siteNumber;
	our $date;
	our $time;
	our $machineNumber;
	our $processNumber;
	our $port;
	our $status;
	our $subStatus;
	our $messageText;
	our $statusMessage;
	our $subStatusMessage;
	our $last="<None>";

	$error="N";
	$body="<P></P><BR />";
	$body.="<TABLE WIDTH=\"100%\">";
	$body.="<TR><TH>Date Time</TH><TH>Port</TH><TH>Status</TH><TH>Sub Status</TH><TH>Text</TH></TR>";
	
	system("sort -o /var/log/mlink/$fileName.sorted /var/log/mlink/$fileName");
	
	open(LOG, "</var/log/mlink/$fileName.sorted");
	
	while(<LOG>)
	{
		chomp($_);
		
		($location, $siteNumber, $date, $time, $machineNumber, $processNumber, $port, $status, $subStatus, $messageText, $statusMessage, $subStatusMessage)=split(/\|/, $_);
		
		if($last eq "<None>")
		{
			$body.="<TR BGCOLOR=\"#C6CAFF\"><TD COLSPAN=\"5\">$location-$siteNumber&nbsp;&nbsp;$acmSite{$siteNumber}->{'name'}</TD></TR>";
		}
		else
		{
			if($last ne "$location-$siteNumber")
			{
				$body.="<TR><TD COLSPAN=\"5\">&nbsp;&nbsp;</TD></TR>";
				$body.="<TR BGCOLOR=\"#C6CAFF\"><TD COLSPAN=\"5\">$location-$siteNumber&nbsp;&nbsp;$acmSite{$siteNumber}->{'name'}</TD></TR>";
			}
		}
		
		$error="Y";
		
		$body.=sprintf("<TR BGCOLOR=\"#FDA3A3\"><TD>%s</TD><TD ALIGN=\"CENTER\">%s</TD><TD>%s</TD><TD>%s</TD><TD>%s</TD></TR>", substr($date,0,4)."-".substr($date,4,2)."-".substr($date,6,2)." ".substr($time,0,2).":".substr($time,2,2).":".substr($time,4,2), $port, $status."-".$statusMessage, $subStatus."-".$subStatusMessage, $messageText) if $status eq "9700";
		$body.=sprintf("<TR BGCOLOR=\"#FFCCCC\"><TD>%s</TD><TD ALIGN=\"CENTER\">%s</TD><TD>%s</TD><TD>%s</TD><TD>%s</TD></TR>", substr($date,0,4)."-".substr($date,4,2)."-".substr($date,6,2)." ".substr($time,0,2).":".substr($time,2,2).":".substr($time,4,2), $port, $status."-".$statusMessage, $subStatus."-".$subStatusMessage, $messageText) if $status eq "5702" || $status eq "5703";
		$body.=sprintf("<TR><TD>%s</TD><TD ALIGN=\"CENTER\">%s</TD><TD>%s</TD><TD>%s</TD><TD>%s</TD></TR>", substr($date,0,4)."-".substr($date,4,2)."-".substr($date,6,2)." ".substr($time,0,2).":".substr($time,2,2).":".substr($time,4,2), $port, $status."-".$statusMessage, $subStatus."-".$subStatusMessage, $messageText) if $status ne "9700" && $status ne "5702" && $status ne "5703";
		
		$last="$location-$siteNumber";
	}	
	
	close LOG;
	
	$body.="</TABLE>";
	$body.="<P></P>";
	
	if($error eq "Y")
	{
		sendMailMessage("[Error] ACM Error Report", $body) if defined $opt{'m'};
	}
	else
	{
		sendMailMessage("[Success] ACM Error Report, No Errors", "No ACM Errors were found."); # if defined $opt{'m'};
	}
	
	$error="N";
	$body="<P></P><BR />";
	$body.="<TABLE WIDTH=\"100%\">";
	$body.="<TR><TH>Location</TH><TH>Register</TH><TH>Store</TH></TR>";
	for our $k1 (sort keys %noAnswer) 
	{
    	for our $k2 (sort keys %{$noAnswer{$k1}})
    	{
    		$error="Y";
			$body.=sprintf("<TR><TD ALIGN=\"CENTER\">%s</TD><TD ALIGN=\"CENTER\">%s</TD><TD>%s</TD></TR>", $k1, $k2, $acmSite{$k2}->{'name'});   		
    	}
    }
    
    $body.="</TABLE>";
	$body.="<P></P>";
	
	if($error eq "Y")
	{
		sendMailMessage("[Error] ACM No Answer Report", $body) if defined $opt{'m'};
	}
	else
	{
		sendMailMessage("[Success] ACM No Answer Report, Everybody Answered", "All sites answered polling."); # if defined $opt{'m'};
	}
}
#********************************************************************************************************************************************************************
# Get A Connection to the Database
#********************************************************************************************************************************************************************
#
sub isDuplicateIP
{
	our $site=shift;
	our $ip=shift;
	our $area=shift;
	
	return "N";
	
	foreach our $key(sort keys %acmSite)
	{
		next if $key eq $site;
		
		if($area eq "A" && defined $acmSite{$key}->{'ipACM'})
		{
			if($acmSite{$key}->{'ipACM'} eq $ip)
			{
				return "Y";
			}	
		}
		
		if($area eq "P" && defined $acmSite{$key}->{'ipPOLL'})
		{
			if($acmSite{$key}->{'ipPOLL'} eq $ip)
			{
				return "Y";
			}	
		}
	}
	return "N";	
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

	sendErrorMessage("$0 Database Error", $message);

	exit 1 if uc $abend eq "Y";
}
#********************************************************************************************************************************************************************
# sendEmailMessage
#********************************************************************************************************************************************************************
#
sub sendMailMessage
{
	our $subject=shift || "[Informational] ACM Parsing Results";
	our $body=shift;
	
    our $msg = MIME::Lite->new(
            From    => '"ACM Parser"<ACM.Parser@paradies-na.com>',
            To      => 'L2-SC@paradies-na.com',
            Cc      => 'nevin.harton@paradies-na.com',
            Subject => $subject,
            Type    => 'text/html',
            Data    => $body
        );

	$msg->send('smtp','mail1.tpscorp.theparadiesshops.com', Debug=>0 );
}
#Cc      => 'L2-SC@paradies-na.com',
#********************************************************************************************************************************************************************
# sendErrorMessage
#********************************************************************************************************************************************************************
#
sub sendErrorMessage
{
	our $subject=shift || "[Failure] ACM Parser";
	our $body=shift;
	
    our $msg = MIME::Lite->new(
            From    => '"ACM Parser"<ACM.Parser@paradies-na.com>',
            To      => 'L2-SC@paradies-na.com',
            Cc      => 'nevin.harton@paradies-na.com',
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
#********************************************************************************************************************************************************************
# main
#********************************************************************************************************************************************************************
#
sub main
{
	printChronologicalMessage("$0 Started");
	
	printChronologicalMessage("Parsing Command Line Arguments");
	getOptions();
	
	#
	#
	our $ix=1;
	foreach("A".."Z")
	{
		$regs{sprintf("%02s", $ix)}="$_";
		$ix++;
	}
	
	$ENV{LD_LIBRARY_PATH}="/opt/perl-5.10.1/instantclient/instantclient_11_2";
	our $connection = DBI->connect( "dbi:Oracle:host=172.20.8.21;sid=GENRET;port=1521", 'system', 'genret', {RaiseError=>1, AutoCommit=>0});

	($today, $yesterday)=getProcessingDates($connection);
	
	printChronologicalMessage("Loading Status Codes");
	loadStatusCode();
	printChronologicalMessage(" ");
	
	printChronologicalMessage("Loading SubStatus Codes");
	loadSubStatusCode();
	printChronologicalMessage(" ");
	
	printChronologicalMessage("Loading Schedule SubStatus Codes");
	loadSchedSubStatus();
	printChronologicalMessage(" ");
	
	printChronologicalMessage("Parsing /gers/mlink/genret/event.out");
	parseFile("event.out");
	printChronologicalMessage(" ");
	
	printChronologicalMessage("Parsing /gers/mlink/genret/port.out");
	parseFile("port.out");
	printChronologicalMessage(" ");
	
	printChronologicalMessage("Parsing /gers/mlink/genret/sched.out");
	parseFile("sched.out");
	printChronologicalMessage(" ");
	
	printChronologicalMessage("Parsing /gers/mlink/genret/site1.out");
	parseFile("site1.out");
	printChronologicalMessage(" ");
	
	printChronologicalMessage("Parsing /gers/mlink/genret/site2.out");	
	parseFile("site2.out");
	printChronologicalMessage(" ");
	
	printChronologicalMessage("Parsing /gers/mlink/genret/task.out");
	parseFile("task.out");
	printChronologicalMessage(" ");
	
	printChronologicalMessage("Loading Polling Table Registers");
	loadPolling($connection);
	printChronologicalMessage(" ");
	
	printChronologicalMessage("Loading Store Table");
	loadStore($connection);
	printChronologicalMessage(" ");
	
	printChronologicalMessage("Loading District Table");
	loadDistrict($connection);
	printChronologicalMessage(" ");
	
	printChronologicalMessage("Reconciling Register Inventory");
	#parseFile("event.out");
	printChronologicalMessage(" ");
	
	#
	# Start validating the 
	#
	$error="N";
	$errors=0;
	
	$body="<P></P><BR />";
	$body.="<TABLE WIDTH=\"100%\">";
	$body.="<TR ALIGN=\"LEFT\"><TH>Site</TH><TH>Site Name</TH><TH>ACM?</TH><TH>POLL?</TH><TH>IP(ACM)</TH><TH>IP(POLL)</TH><TH>Port</TH><TH>Issue Description</TH></TR>";
	foreach our $key(sort keys %acmSite)
	{
		if($acmSite{$key}->{'acm'} eq "Yes") 
		{
			if($acmSite{$key}->{'poll'} eq "Yes")
			{
				if($acmSite{$key}->{'ipACM'} ne $acmSite{$key}->{'ipPOLL'} )
				{
					$error="Y";
					$errors++;
					$body.=sprintf("<TR><TD ALIGN=\"CENTER\">%s</TD><TD>%s</TD><TD ALIGN=\"CENTER\">%s</TD><TD ALIGN=\"CENTER\">%s</TD><TD>%s</TD><TD>%s</TD><TD ALIGN=\"CENTER\">%s</TD><TD>%s</TD></TR>", $key, $acmSite{$key}->{'name'}, $acmSite{$key}->{'acm'}, $acmSite{$key}->{'poll'}, $acmSite{$key}->{'ipACM'}, $acmSite{$key}->{'ipPOLL'}, $acmSite{$key}->{'port'}, "IP Address Mismatch");
				}
				else
				{
#					if(isDuplicateIP($key, $acmSite{$key}->{'ipACM'}, "A"))
#					{
#						$error="Y";
#					$errors++;
#					$body.=sprintf("<TR><TD>%s</TD><TD>%s</TD><TD>%s</TD><TD>%s</TD><TD>%s</TD><TD>%s</TD><TD>%s</TD><TD>%s</TD></TR>", $key, $acmSite{$key}->{'name'}, $acmSite{$key}->{'acm'}, $acmSite{$key}->{'poll'}, $acmSite{$key}->{'ipACM'}, $acmSite{$key}->{'ipPOLL'}, $acmSite{$key}->{'port'}, "ACM IP In Use");
#					}
#					
#					if(isDuplicateIP($key, $acmSite{$key}->{'ipPOLL'}, "P"))
#					{
#						$error="Y";
#					$errors++;
#					$body.=sprintf("<TR><TD>%s</TD><TD>%s</TD><TD>%s</TD><TD>%s</TD><TD>%s</TD><TD>%s</TD><TD>%s</TD><TD>%s</TD></TR>", $key, $acmSite{$key}->{'name'}, $acmSite{$key}->{'acm'}, $acmSite{$key}->{'poll'}, $acmSite{$key}->{'ipACM'}, $acmSite{$key}->{'ipPOLL'}, $acmSite{$key}->{'port'}, "POLLING IP In Use");
#					}
				}
			}
			else
			{
				$error="Y";
				$errors++;
				$body.=sprintf("<TR><TD ALIGN=\"CENTER\">%s</TD><TD>%s</TD><TD ALIGN=\"CENTER\">%s</TD><TD ALIGN=\"CENTER\">%s</TD><TD>%s</TD><TD>%s</TD><TD ALIGN=\"CENTER\">%s</TD><TD>%s</TD></TR>", $key, $acmSite{$key}->{'name'}, $acmSite{$key}->{'acm'}, $acmSite{$key}->{'poll'}, $acmSite{$key}->{'ipACM'}, $acmSite{$key}->{'ipPOLL'}, $acmSite{$key}->{'port'}, "In ACM, Not In POLLING");
			}
		}
		else
		{
			$error="Y";
			$errors++;
			$body.=sprintf("<TR><TD ALIGN=\"CENTER\">%s</TD><TD>%s</TD><TD ALIGN=\"CENTER\">%s</TD><TD ALIGN=\"CENTER\">%s</TD><TD>%s</TD><TD>%s</TD><TD ALIGN=\"CENTER\">%s</TD><TD>%s</TD></TR>", $key, $acmSite{$key}->{'name'}, $acmSite{$key}->{'acm'}, $acmSite{$key}->{'poll'}, $acmSite{$key}->{'ipACM'}, $acmSite{$key}->{'ipPOLL'}, $acmSite{$key}->{'port'}, "In POLLING, Not in ACM");
		}
	}
	$body.="</TABLE>";
	$body.="<P>$errors issues were found in the ACM and POLLING register inventories.  Please take appropriate action to address the issues above.</P>";
	
	if($error eq "Y")
	{
		sendMailMessage("[Warning] ACM/POLLING Reconciliation Issues", $body) if defined $opt{'m'};
	}
	else
	{
		sendMailMessage("[Success] ACM/POLLING Reconciliation Issues, No Reconciliation Issues", "No reconciliation issues were found."); # if defined $opt{'m'};
	}
	
	
	our $stat;
	our $skip;
	
	$error="N";
	
	$body="<P></P><BR />";
	$body.="<TABLE WIDTH=\"100%\">";
	$body.="<TR ALIGN=\"LEFT\"><TH>Site</TH><TH>Site Name</TH><TH>Session</TH><TH>Status</TH><TH>Skip</TH></TR>";
	foreach our $key(sort keys %sched)
	{
		next if $sched{$key}->{'status'} ne "F" && $sched{$key}->{'status'} ne "S" && $sched{$key}->{'status'} ne "N" && $sched{$key}->{'action'} ne "X";
		
		$error="Y";
		
		$stat=" ";
		$stat="Waiting for First Call" if $sched{$key}->{'status'} eq "I";
		$stat="Session Complete" if $sched{$key}->{'status'} eq "C";
		$stat="Failed($schedSubStatus{$sched{$key}->{'substat'}})" if $sched{$key}->{'status'} eq "F";
		$stat="Suspended($schedSubStatus{$sched{$key}->{'substat'}})" if $sched{$key}->{'status'} eq "S";
		$stat="No Schedule($schedSubStatus{$sched{$key}->{'substat'}})" if $sched{$key}->{'status'} eq "N";
		
		$skip="Yes" if $sched{$key}->{'action'} eq "X";
		$skip=" " if $sched{$key}->{'action'} ne"X";
		
		$body.=sprintf("<TR BGCOLOR=\"#FFCCCC\"><TD ALIGN=\"CENTER\">%s</TD><TD>%s</TD><TD>%s</TD><TD>%s</TD><TD ALIGN=\"CENTER\">%s</TD></TR>", $key, $acmSite{$key}->{'name'},$sched{$key}->{'name'}, "[".substr($sched{$key}->{'stattm'}, 0, 8)." ".substr($sched{$key}->{'stattm'}, 8, 4)."] ".$stat, $skip) if $skip eq "Yes";
		$body.=sprintf("<TR><TD ALIGN=\"CENTER\">%s</TD><TD>%s</TD><TD>%s</TD><TD>%s</TD><TD ALIGN=\"CENTER\">%s</TD></TR>", $key, $acmSite{$key}->{'name'},$sched{$key}->{'name'}, "[".substr($sched{$key}->{'stattm'}, 0, 8)." ".substr($sched{$key}->{'stattm'}, 8, 4)."] ".$stat, $skip) if $skip ne "Yes";
	}
	$body.="</TABLE>";
	
	if($error eq "Y")
	{
		sendMailMessage("[Error] ACM Session Status Report", $body) if defined $opt{'m'};
	}
	else
	{
		sendMailMessage("[Success] ACM Session Status Report, No Session Issues", "No Session Issues were found."); # if defined $opt{'m'};
	}
	
	
	printChronologicalMessage("Parsing /gers/mlink/genret/log.out");	
	parseFile("log.out", "log.".getFormattedDateAndTime("yyyy-MM-dd").".ext");
	reportLogErrors("log.".getFormattedDateAndTime("yyyy-MM-dd").".ext");
	printChronologicalMessage(" ");
	
	printChronologicalMessage("$0 Ended");
	printChronologicalMessage(" ");
}
