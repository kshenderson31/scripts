#********************************************************************************************************************************************************************
# 
#********************************************************************************************************************************************************************
#
use strict;
use warnings;
use Net::Ping;
#********************************************************************************************************************************************************************
# 
#********************************************************************************************************************************************************************
#
use DBI;
use DBD::Oracle;
use MIME::Lite;
use Number::Format;
use Getopt::Std;
#********************************************************************************************************************************************************************
# 
#********************************************************************************************************************************************************************
#
our $p = Net::Ping->new("icmp", 1, 64);

our $businessDate;
our $oracleDate;
our $storeNumber;
our $storeName;
our $terminalNumber;
our $locationNumber;
our $phoneNumber;
our $comments;
our $ipAddress;
our $amount;

our %opt;
our %register;
our %regs;

$regs{"01"}="A";
$regs{"02"}="B";
$regs{"03"}="C";
$regs{"04"}="D";
$regs{"05"}="E";
$regs{"06"}="F";
$regs{"07"}="G";
$regs{"08"}="H";

#********************************************************************************************************************************************************************
# 
#********************************************************************************************************************************************************************
#
our %s0;
our %s1;
our %s2a;
our %s2;
our %s4a;
our %s4;

#********************************************************************************************************************************************************************
# 
#********************************************************************************************************************************************************************
#
our $body;
our $header = <<'__HEADER__';
This email is to notify users of possible issues related to polling. The IT Support Center is actively working the list throughout the morning to ensure all sales are captured and processed in a timely manner. Sections 1 and 2 denotes a problem; section 3 denotes equipment being maintained that is not currently in use. Please remember that polling is the process used to exchange data between GERS and the registers.<br>
<br>
__HEADER__
#********************************************************************************************************************************************************************
# 
#********************************************************************************************************************************************************************
#
our $footer = <<'__FOOTER__';
More Detail About Each Section<br><br>
Section 1: The goal is to complete all polling by 7:45am EST; however, due to possible network issues, EOD processing, or incorrect register dates the below registers did not automatically poll last night. If your location has a register listed below, the IT Support Center is working diligently to poll and process the sales into GERS. No action is required at this time; the IT Service Center will contact you if assistance is needed. If the register is working and was not used it still needs to be polled so it receives up-to-date pricing; if it has a problem please contact the IT Service Center. <br>
<br>
Section 2: These are registers that have hardware issues. If these issues have been addressed please notify the IT Service Center so they are removed from this list. All broken registers should be up and running with 24-48 hours (some exceptions may occur). <br>
<br>
Section 3: These registers have not posted sales for at least 7 days. If the register was not used, then it is correct. If the register was used, and is in this section you must contact the IT Helpdesk immediately to ensure the sales are retrieved. Some locations have a register that is rarely used but they keep it as a backup. That is fine, however, it is important that the register is opened and closed each day to ensure all PLUs remain current in case the register is needed.<br>
<br> 
NOT CALLING COULD RESULT IN LOST SALES AND/OR ITEMS NOT SCANNING CORRECTLY.<br>
__FOOTER__
#********************************************************************************************************************************************************************
# 
#********************************************************************************************************************************************************************
#
our $stmt1 = <<__SQL1__;
select a.store_cd, a.term_num, a.loc, a.phone, a.comments, a.rgstr_ip_addr
  from polling a
where NOT EXISTS 
  (
    select store_cd, term_num 
      from sa_stat b
    where a.store_cd = b.store_cd 
      and a.term_num = b.term_num
      and trn_dt = (select TO_CHAR(sysdate-1) from dual) 
      and term_num > '00'
  )
order by a.store_cd, a.term_num
__SQL1__

#********************************************************************************************************************************************************************
# 
#********************************************************************************************************************************************************************
#
our $stmt2 = <<__SQL2__;
select sum(a.amt) AS amt
  from sa_sls_tot a, 
  polling b
where a.store_cd = ?
  and a.term_num = ?
  and a.store_cd = b.store_cd
  and a.term_num = b.term_num
  and a.TRN_DT between (select TO_CHAR(sysdate-9) from dual) and (select TO_CHAR(sysdate-2) from dual)
__SQL2__

#********************************************************************************************************************************************************************
# Insert Statement for Polling History 
#********************************************************************************************************************************************************************
#
our $stmt3 = <<__SQL3__;
UPDATE misc.polling_status
  SET poll_stat_cd=?
WHERE polling_dt=?
  AND store_cd=?
  AND term_num=?  
__SQL3__

#********************************************************************************************************************************************************************
# Insert Statement for Polling History 
#********************************************************************************************************************************************************************
#
our $stmt4 = <<__SQL4__;
INSERT INTO MISC.POLLING_STATUS
SELECT TO_DATE(TO_CHAR(SYSDATE-1)), store_cd, term_num, 'OK'
  FROM MISC.POLLING P
WHERE 'Y' NOT IN
  (
    SELECT 'Y'
      FROM MISC.POLLING_STATUS S
    WHERE S.POLLING_DT = TO_DATE(TO_CHAR(SYSDATE-1))
      AND S.STORE_CD   = P.STORE_CD
      AND S.TERM_NUM   = P.TERM_NUM
  )
__SQL4__

#********************************************************************************************************************************************************************
# Insert Statement for Polling History 
#********************************************************************************************************************************************************************
#
our $stmt5 = <<__SQL5__;
INSERT INTO MISC.POLLING_HISTORY
SELECT CURRENT_TIMESTAMP, POLLING_DT, STORE_CD, TERM_NUM, POLL_STAT_CD
  FROM MISC.POLLING_STATUS
__SQL5__

#********************************************************************************************************************************************************************
# Insert Statement for Polling History 
#********************************************************************************************************************************************************************
#
our $stmt6 = <<__SQL6__;
UPDATE MISC.POLLING_STATUS
  SET poll_stat_cd='OK'
WHERE polling_dt=TO_DATE(TO_CHAR(SYSDATE-1))
__SQL6__

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
	# Seed The Polling Status Table for the day 
	#****************************************************************************************************************************************************************
	#
	seedPollingStatus($databaseHandler);
	
	#****************************************************************************************************************************************************************
	# Build the hashes that will drive the reporting 
	#****************************************************************************************************************************************************************
	#
	buildHashes($databaseHandler);
	
	#****************************************************************************************************************************************************************
	# Generate the report 
	#****************************************************************************************************************************************************************
	#
	generateReport($databaseHandler);
	
	#****************************************************************************************************************************************************************
	# Commit Transaction 
	#****************************************************************************************************************************************************************
	#
	my $handler = $databaseHandler->prepare("COMMIT");
	
	if(!($handler->execute()))
	{
		print $DBI::errstr;
	}
	
	#****************************************************************************************************************************************************************
	# createHistorySnapshot 
	#****************************************************************************************************************************************************************
	#
	createHistorySnapshot($databaseHandler);
	
	
	#****************************************************************************************************************************************************************
	# Send the report via HTML email 
	#****************************************************************************************************************************************************************
	#
	printChronologicalMessage("Bypassing mail message", "N") if not defined $opt{'m'};
	sendMailMessage() if defined $opt{'m'};
	#****************************************************************************************************************************************************************
	# End database session 
	#****************************************************************************************************************************************************************
	#
	$databaseHandler->disconnect;
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
	getopts("d:e:imup", \%opt);
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
		databaseError("Could not establish database connection to $host:$port:$sid");
	} 
	
	return $connection;	
}
#********************************************************************************************************************************************************************
# 
#********************************************************************************************************************************************************************
#
sub buildHashes
{
	our $databaseHandler=shift;

	printChronologicalMessage("Gathering data", "N");
	
	$businessDate=getBusinessDate($databaseHandler);
	
	our $statementHandler;
	if(!($statementHandler=$databaseHandler->prepare($stmt1)))
	{
		databaseError("Prepare failed in buildHashes");
	}
	
	if(!($statementHandler->execute()))
	{
		databaseError("Statement execution failed in buildHashes");
	}
	
	$statementHandler->bind_columns(undef, \$storeNumber, \$terminalNumber, \$locationNumber, \$phoneNumber, \$comments, \$ipAddress);
	
	printChronologicalMessage("Processing results", "N")
	;
	while($statementHandler->fetch()) 
	{
		#my $statementHandler3 = $databaseHandler->prepare($stmt3);
		#if(!($statementHandler3->execute('OK', $oracleDate, $storeNumber, $terminalNumber)))
		#{
		#	databaseError("Insert to MISC.POLLING_STATUS failed ($oracleDate, $storeNumber, $terminalNumber)");
		#}
		#$statementHandler3->finish;
		
	    my $statementHandler2 = $databaseHandler->prepare($stmt2);
	    my $initAmount;
	    $statementHandler2->execute($storeNumber, $terminalNumber);
	    $statementHandler2->bind_columns(undef, \$amount );
	    $statementHandler2->fetch();
	    $statementHandler2->finish;
	    
	    $comments=$comments || "<null>";
	    $register{"$storeNumber\-$terminalNumber"}=$ipAddress;
	    next if index(lc $comments, "removed") >= 0;
	    next if index(lc $comments, "closed") >= 0 && index(lc $comments, "remodel") == -1;
	    
	    $initAmount = $amount || -1;
	    $amount = $amount / 7 if defined $amount;
	    $amount = 0 if not defined $amount;
	    $phoneNumber=$phoneNumber || "No Phone";
	    $locationNumber = $locationNumber || "UNK";
	    
	    $s0{"$locationNumber-$storeNumber-$terminalNumber"}="$storeNumber-$terminalNumber" if $comments eq "<null>" || $comments eq "MICROS";
	    $s1{"$storeNumber-$terminalNumber"}="$terminalNumber;$locationNumber;$phoneNumber;$comments;$amount;$initAmount" if $comments eq "<null>" || $comments eq "MICROS";
	    
	    $s2a{"$locationNumber-$storeNumber-$terminalNumber"}="$storeNumber-$terminalNumber" if $comments ne "<null>" && $comments ne "MICROS";
	    $s2{"$storeNumber-$terminalNumber"}="$terminalNumber;$locationNumber;$phoneNumber;$comments;$amount;$initAmount" if $comments ne "<null>" && $comments ne "MICROS";
	    
	    $s4a{"$locationNumber-$storeNumber-$terminalNumber"}="$storeNumber-$terminalNumber" if $initAmount == -1;
	    $s4{"$storeNumber-$terminalNumber"}="$terminalNumber;$locationNumber;$phoneNumber;$comments;$amount;$initAmount" if $initAmount == -1;
	}
	
	$statementHandler->finish;
}

#********************************************************************************************************************************************************************
# Update PollingStatus Table for Dashboard
#********************************************************************************************************************************************************************
#
sub updatePollingStatus
{
	our $databaseHandler=shift;
	our $store=shift;
	our $terminal=shift;
	our $status=shift;
	
	return if not defined $opt{'u'};
	
	our $statementHandler;
	
	if(!($statementHandler=$databaseHandler->prepare($stmt3)))
	{
		databaseError("Prepare failed in updatePollingStatus");
	}
	
	if(!($statementHandler->execute($status, $oracleDate, $store, $terminal)))
	{
		databaseError("Update failed ($status, $oracleDate, $store, $terminal)");
	}
	
	$statementHandler->finish;
}
#********************************************************************************************************************************************************************
# 
#********************************************************************************************************************************************************************
#
sub seedPollingStatus
{
	our $databaseHandler=shift;
	
	return if not defined $opt{'u'};
	
	our $statementHandler;
	if(!($statementHandler=$databaseHandler->prepare($stmt4)))
	{
		databaseError("Prepare failed in seedPollingStatus");
	}
	
	if(!($statementHandler->execute()))
	{
		databaseError("Seeding of MISC.POLLING_STATUS failed");
	}
	
	$statementHandler->finish;
	
	if(!($statementHandler = $databaseHandler->prepare($stmt6)))
	{
		databaseError("Prepare failed* in seedPollingStatus");
	}
	
	if(!($statementHandler->execute()))
	{
		databaseError("Seeding* of MISC.POLLING_STATUS failed");
	}
	
	$statementHandler->finish;
}

#********************************************************************************************************************************************************************
# Create History Snapshot
#********************************************************************************************************************************************************************
#
sub createHistorySnapshot
{
	our $databaseHandler=shift;
	
	return if not defined $opt{'u'};
	
	our $statementHandler;
	if(!($statementHandler=$databaseHandler->prepare($stmt5)))
	{
		databaseError("Prepare failed in createHistorySnapshot");
	}	
	
	if(!($statementHandler->execute()))
	{
		databaseError("Updating of MISC.POLLING_HISTORY failed");
	}
	
	$statementHandler->finish;
}

#********************************************************************************************************************************************************************
# Generate the Polling Report
#********************************************************************************************************************************************************************
#
sub generateReport
{
	our $databaseHandler=shift;
	
	printChronologicalMessage("=" x 80);
	printChronologicalMessage("Section 1  - STORES THAT HAVE NOT YET POSTED SALES. THESE NEED TO BE POLLED");
	printChronologicalMessage("=" x 80);
	
	$body.="<p>$header</p>";
	
	printChronologicalMessage(" ");
	printChronologicalMessage(sprintf("%4s  %2s  %4s  %15s  %47s", "====", "==", "====", "=" x 15, "=" x 47));
	printChronologicalMessage(sprintf("%-4s  %-2s  %-4s  %-15s  %-47s", "Str", "T#", "Loc", "IP Address", "Comments"));
	printChronologicalMessage(sprintf("%4s  %2s  %4s  %15s  %47s", "====", "==", "====", "=" x 15, "=" x 47));
	
	$body.="<table border=\"0\" width=\"100%\">";
	$body.="<tr><td colspan=6><p>Section 1  - STORES THAT HAVE NOT YET POSTED SALES. THESE NEED TO BE POLLED</p></td></tr>";
	
	if(defined $opt{'p'})
	{
		$body.="<tr><th align=\"center\">Register</th><th align=\"center\">Location</th><th align=\"center\">7 Day Avg</th><th align=\"left\">Comments</th></tr>";	
	}
	else
	{
		$body.="<tr><th align=\"center\">Register</th><th align=\"center\">Location</th><th align=\"center\">Ping?</th><th align=\"center\">IP Address</th><th align=\"center\">7 Day Avg</th><th align=\"left\">Comments</th></tr>";
	}
	
	
	our $n = new Number::Format(-int_curr_symbol=>'$');
	
	open(HST, ">>/var/data/nightly.history");
	
	our ($mon, $day, $year)=split(" ", $businessDate);
	our $month=0;
	
	$day=~s/,//g;
	
	$month=1  if lc $mon eq "january";
	$month=2  if lc $mon eq "february";
	$month=3  if lc $mon eq "march";
	$month=4  if lc $mon eq "april";
	$month=5  if lc $mon eq "may";
	$month=6  if lc $mon eq "june";
	$month=7  if lc $mon eq "july";
	$month=8  if lc $mon eq "august";
	$month=9  if lc $mon eq "september";
	$month=10 if lc $mon eq "october";
	$month=11 if lc $mon eq "november";
	$month=12 if lc $mon eq "december";
	
	our $date=sprintf("%04d-%02d-%02d", $year, $month, $day);
	
	our $estimate=0;
	our $cnt=0;
	foreach our $key (sort keys %s0)
	{
		our $sorted=$s0{$key};
		our($str, undef)=split("-", $sorted);
		our($term, $loc, $phone, $comment, $a1, $a2)=split(";", $s1{$sorted});
		
		next if $a2 == -1;
		
		updatePollingStatus($databaseHandler, $str, $term, 'ER');
		
		our $status="IP Not Defined";
		
		our $indicator="No IP";
		our $address=$register{$sorted} || "No IP Found";
		
		$status=pingRegister($sorted) if defined $opt{'i'} && defined $register{$sorted};
		$status="Ping Bypassed" if not defined $opt{'i'};
		
		$indicator="Yes" if $status eq "Ping successful";
		$indicator="Fail" if $status eq "Ping failed";
		$indicator=" " if not defined $opt{'i'};
		
		$cnt++;
		$comment=" " if $comment eq "<null>";
		$estimate=$estimate+$a1;
		our $formatted=$n->format_picture($a1, '#,###,###.##');
		printChronologicalMessage(sprintf("%04d  %02d  %-4s  %-15s  %-47s", $str, $term, $loc, $address, "$indicator\;$comment"));
		if(defined $opt{'p'})
		{
			$body.="<tr><td width=\"7%\" align=\"center\">$str$regs{$term}</td><td width=\"7%\" align=\"center\">$loc</td><td width=\"8%\" align=\"right\">$formatted&nbsp;</td><td width=\"78%\">$comment</td></tr>";
		}
		else
		{
			$body.="<tr><td width=\"7%\" align=\"center\">$str$regs{$term}</td><td width=\"7%\" align=\"center\">$loc</td><td width=\"7%\" align=\"center\">$indicator</td><td width=\"15%\" align=\"center\">$address</td><td width=\"8%\" align=\"right\">$formatted&nbsp;</td><td width=\"56%\">$comment</td></tr>";
		}
	}
	
	close HST;
	
	$estimate=$n->format_price($estimate);
	$body.="<tr><td colspan=6><p style=\"font-style:italic\">There are $cnt registers that need to report sales. Based on a trailing seven day average, $estimate in sales may be waiting to be polled and posted to GERS.</p></td></tr>";
	$body.="</table>";
	
	printChronologicalMessage(" ");
	printChronologicalMessage("There are $cnt registers that need to be polled.") if $cnt > 0;
	printChronologicalMessage(" ");
	
	printChronologicalMessage("=" x 80);
	printChronologicalMessage("Section 2  - STORES THAT CANNOT POST SALES BECAUSE OF PROBLEMS");
	printChronologicalMessage("=" x 80);
	
	printChronologicalMessage(" ");
	printChronologicalMessage(sprintf("%4s  %2s  %4s  %12s  %50s", "====", "==", "====", "=" x 12, "=" x 50));
	printChronologicalMessage(sprintf("%-4s  %-2s  %-4s  %-12s  %-50s", "Str", "T#", "Loc", "Phone", "Comments"));
	printChronologicalMessage(sprintf("%4s  %2s  %4s  %12s  %50s", "====", "==", "====", "=" x 12, "=" x 50));
	
	$body.="<table border=\"0\" width=\"100%\">";
	$body.="<tr><td colspan=5><p>Section 2  - STORES THAT CANNOT POST SALES BECAUSE OF PROBLEMS</p></td></tr>";
	$body.="<tr><th align=\"center\">Store</th><th align=\"center\">Register</th><th align=\"center\">Location</th><th align=\"left\">Comments</th></tr>";
	
	$cnt=0;
	foreach our $key (sort keys %s2a)
	{
		$cnt++;
		our $sorted=$s2a{$key};
		our($str, undef)=split("-", $sorted);
		our($term, $loc, $phone, $comment, $a1, $a2)=split(";", $s2{$sorted});
		
		updatePollingStatus($databaseHandler, $str, $term, 'IN');
		
		printChronologicalMessage(sprintf("%04d  %02d  %-4s  %-12s  %-50s", $str, $term, $loc, $phone, $comment));
		$body.="<tr><td width=\"7%\" align=\"center\">$str</td><td width=\"7%\" align=\"center\">$term</td><td width=\"7%\" align=\"center\">$loc</td><td width=\"79%\">$comment</td></tr>";
	}
	
	$body.="<tr><td colspan=5><p style=\"font-style:italic\">There are $cnt registers that cannot post sales due to problems with equipment.</p></td></tr>";
	$body.="</table>";
	
	printChronologicalMessage(" ");
	printChronologicalMessage("$cnt registers cannot post sales due to problems") if $cnt > 0;
	printChronologicalMessage(" ");
	
#	printChronologicalMessage("=" x 80);
#	printChronologicalMessage("Section 3 - REGISTERS THAT DID NOT RECEIVE PRICING UPDATES");
#	printChronologicalMessage("=" x 80);
#	
#	$body.="<table border=\"0\" width=\"100%\">";
#	$body.="<tr><td colspan=5><p>Section 3 - REGISTERS THAT DID NOT RECEIVE PRICING UPDATES</p></td></tr>";
#	$body.="</table>";
	
	printChronologicalMessage(" ");
	printChronologicalMessage("=" x 80);
	printChronologicalMessage("Section 4  - STORES THAT SHOW A ZERO IN GERS");
	printChronologicalMessage("=" x 80);
	
	printChronologicalMessage(" ");
	printChronologicalMessage(sprintf("%4s  %2s  %4s  %12s  %50s", "====", "==", "====", "=" x 12, "=" x 50));
	printChronologicalMessage(sprintf("%-4s  %-2s  %-4s  %-12s  %-50s", "Str", "T#", "Loc", "Phone", "Comments"));
	printChronologicalMessage(sprintf("%4s  %2s  %4s  %12s  %50s", "====", "==", "====", "=" x 12, "=" x 50));
	
	$body.="<table border=\"0\" width=\"100%\">";
	$body.="<tr><td colspan=5><p>Section 4  - STORES THAT SHOW A ZERO IN GERS</p></td></tr>";
	$body.="<tr><th align=\"center\">Store</th><th align=\"center\">Register</th><th align=\"center\">Location</th><th align=\"left\">Comments</th></tr>";
	
	$cnt=0;
	foreach our $key (sort keys %s4a)
	{
		our $sorted=$s4a{$key};
		our($str, undef)=split("-", $sorted);
		our($term, $loc, $phone, $comment, $a1, $a2)=split(";", $s4{$sorted});
		next if $comment ne "<null>" && $comments ne "MICROS";
		
		updatePollingStatus($databaseHandler, $str, $term, 'ZS');
		
		$cnt++;
		printChronologicalMessage(sprintf("%04d  %02d  %-4s  %-12s  %-50s", $str, $term, $loc, $phone, " "));
		$body.="<tr><td width=\"7%\" align=\"center\">$str</td><td width=\"7%\" align=\"center\">$term</td><td width=\"7%\" align=\"center\">$loc</td><td width=\"79%\">$comment</td></tr>";
	}
	
	$body.="<tr><td colspan=5><p style=\"font-style:italic\">There are $cnt registers that have posted sales of \$0.00 to GERS.</p></td></tr>";
	$body.="</table>";
	
	printChronologicalMessage(" ");
	printChronologicalMessage("There are $cnt registers that have posted sales of \$0.00.") if $cnt > 0;
	printChronologicalMessage(" ");
	
	$body.="<p style=\"font-size:80%\">$footer</p>";	
}

#********************************************************************************************************************************************************************
# Ping the register
#********************************************************************************************************************************************************************
#
sub pingRegister
{
	our $key=shift;
	our $return="Ping failed";
	our $try=1;
	
	while($try <= 10)
	{
		if($p->ping($register{$key}))
		{
			$try=10;
			$return="Ping successful";	
		}
		$try++;
	}
	return $return;
}
#********************************************************************************************************************************************************************
# Get The Business Date
#********************************************************************************************************************************************************************
#
sub getBusinessDate
{
    my $dbh=shift;
    
    my $bd;
    my $od;
    
	my $sth = $dbh->prepare("select initcap(trim(to_char(sysdate-1, 'MONTH'))) || to_char(sysdate-1, ' DD, YYYY') || initcap(to_char(sysdate-1, ' DAY')), sysdate-1 from dual");
    
    $sth->execute;
    $sth->bind_columns(undef, \$bd, \$od );
    $sth->fetch();
    $sth->finish;
	
	$oracleDate=$od;
	
	return $bd;
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
	
	sendFailureMessage($message);
	
	exit 1 if uc $abend eq "Y";
	
}
#********************************************************************************************************************************************************************
# Send Failure Message
#********************************************************************************************************************************************************************
#
sub sendFailureMessage
{
	our $error=shift;
	
	our $msg = MIME::Lite->new(
    	    From    => '"IT Service Center"<itservicecenter@paradies-na.com>',
    	    To      => '"IT Service Center"<itservicecenter@paradies-na.com>',
       		Subject => "[Failure] Polling Status For $businessDate",
        	Type    => 'text/html',
        	Data    => $error
    	);
    	
    $msg->send('smtp','mail1.tpscorp.theparadiesshops.com', Debug=>0 );
}
#********************************************************************************************************************************************************************
# Send Email
#********************************************************************************************************************************************************************
#
sub sendMailMessage
{
	our $msg;
	
	printChronologicalMessage("Sending email message", "N");
	
	if(defined $opt{'e'})
	{
		$msg = MIME::Lite->new(
    	    From    => '"IT Service Center"<itservicecenter@paradies-na.com>',
    	    To      => $opt{'e'},
       		Subject => "Polling Status For $businessDate",
        	Type    => 'text/html',
        	Data    => $body
    	);
		
	}
	else
	{
		if(defined $opt{'p'})
		{
			$msg = MIME::Lite->new(
	    	    From    => '"IT Service Center"<itservicecenter@paradies-na.com>',
	    	    To      => 'tfyarbrough@paradies-na.com',
	    	    Cc      => 'pollingdistribution@paradies-na.com', 
	       		Subject => "Polling Status For $businessDate",
	        	Type    => 'text/html',
	        	Data    => $body
	    	);
		}
		else
		{
			$msg = MIME::Lite->new(
	    	    From    => '"IT Service Center"<itservicecenter@paradies-na.com>',
	    	    To      => 'L1-SC@paradies-na.com',
	    	    Cc      => 'L2-SC@paradies-na.com',
	       		Subject => "Polling Status For $businessDate",
	        	Type    => 'text/html',
	        	Data    => $body
	    	);
		}
	}
	
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
