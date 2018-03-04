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
our %s1;
our %s2;
our %s4;
#********************************************************************************************************************************************************************
# 
#********************************************************************************************************************************************************************
#
our $body;
our $header = <<'__HEADER__';
The goal is to not be on this email. Sections 1 and 2 denotes a problem; section 3 denotes equipment being maintained that is not currently in use. Please remember that polling is the process used to exchange data between GERS and the registers.<br>
<br>
__HEADER__
#********************************************************************************************************************************************************************
# 
#********************************************************************************************************************************************************************
#
our $footer = <<'__FOOTER__';
More Detail About Each Section<br><br>
Section 1: These are the stores we have yet to reach at the time we sent out the email. We strive to reach all registers by 7:45am EST. If your location has a register listed here please have someone go to this register and call the IT helpdesk ASAP. If the register is working and was not used it still needs to be polled so it receives up to date pricing, if it does not work the IT Service Center must be notified immediately. <br>
<br>
Section 2: These are stores/registers that have hardware issues. If these issues have been addressed please notify the IT Service Center so they are removed from this list. All broken registers should be up and running with 24-48 hours (some exceptions may occur). <br>
<br>
Section 3: These registers have not posted sales for at least 7 days. If the register was not used, then it is correct. If the register was used, and is in this section you must contact the IT Helpdesk immediately to ensure the sales are retrieved. Some locations have a register that is rarely used but they keep it as a backup. That is fine, however, it is important that the register is opened and closed each day to ensure all PLU.s remain current in case the register is needed.<br>
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
	# Build the hashes that will drive the reporting 
	#****************************************************************************************************************************************************************
	#
	buildHashes($databaseHandler);
	
	#****************************************************************************************************************************************************************
	# Generate the report 
	#****************************************************************************************************************************************************************
	#
	generateReport();
	
	#****************************************************************************************************************************************************************
	# Send the report via HTML email 
	#****************************************************************************************************************************************************************
	#
	printChronologicalMessage("Bypassing mail message", "N") if not defined $opt{'m'};
	sendMailMessage() if defined $opt{'m'};
	
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
	getopts("d:e:mup", \%opt);
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
# 
#********************************************************************************************************************************************************************
#
sub buildHashes
{
	our $databaseHandler=shift;

	printChronologicalMessage("Gathering data", "N");
	
	$businessDate=getBusinessDate($databaseHandler);
	our $statementHandler1 = $databaseHandler->prepare($stmt1);
	
	$statementHandler1->execute();
	
	$statementHandler1->bind_columns(undef, \$storeNumber, \$terminalNumber, \$locationNumber, \$phoneNumber, \$comments, \$ipAddress);
	
	printChronologicalMessage("Processing results", "N")
	;
	while($statementHandler1->fetch()) 
	{
	    my $statementHandler2 = $databaseHandler->prepare($stmt2);
	    my $initAmount;
	    $statementHandler2->bind_param(1, $storeNumber);
	    $statementHandler2->bind_param(2, $terminalNumber);
	    $statementHandler2->execute;
	    $statementHandler2->bind_columns(undef, \$amount );
	    $statementHandler2->fetch();
	    
	    $comments=$comments || "<null>";
	    $register{"$storeNumber\-$terminalNumber"}=$ipAddress;
	    next if index(lc $comments, "removed") >= 0;
	    next if index(lc $comments, "closed") >= 0 && index(lc $comments, "remodel") == -1;
	    
	    $initAmount = $amount || -1;
	    $amount = $amount / 7 if defined $amount;
	    $amount = 0 if not defined $amount;
	    $phoneNumber=$phoneNumber || "No Phone";
	    $locationNumber = $locationNumber || "UNK";
	    
	    
	    $s1{"$storeNumber-$terminalNumber"}="$terminalNumber;$locationNumber;$phoneNumber;$comments;$amount;$initAmount" if $comments eq "<null>" || $comments eq "MICROS";
	    $s2{"$storeNumber-$terminalNumber"}="$terminalNumber;$locationNumber;$phoneNumber;$comments;$amount;$initAmount" if $comments ne "<null>" && $comments ne "MICROS";
	    $s4{"$storeNumber-$terminalNumber"}="$terminalNumber;$locationNumber;$phoneNumber;$comments;$amount;$initAmount" if $initAmount == -1;
	}
	
	$statementHandler1->finish;
	$databaseHandler->disconnect;
}
#********************************************************************************************************************************************************************
# Generate the Polling Report
#********************************************************************************************************************************************************************
#
sub generateReport
{
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
	foreach our $key (sort keys %s1)
	{
		our($str, undef)=split("-", $key);
		our($term, $loc, $phone, $comment, $a1, $a2)=split(";", $s1{$key});
		next if $a2 == -1;
		
		our $status="IP Not Defined";
		our $indicator="No IP";
		our $address=$register{$key} || "No IP Found";
		$status=pingRegister($key) if defined $register{$key};
		$indicator="Yes" if $status eq "Ping successful";
		$indicator="Fail" if $status eq "Ping failed";
		print HST "$date,$str,$term,$status\n" if defined $opt{'u'};
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
	foreach our $key (sort keys %s2)
	{
		$cnt++;
		our($str, undef)=split("-", $key);
		our($term, $loc, $phone, $comment, $a1, $a2)=split(";", $s2{$key});
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
	foreach our $key (sort keys %s4)
	{
		our($str, undef)=split("-", $key);
		our($term, $loc, $phone, $comment, $a1, $a2)=split(";", $s4{$key});
		next if $comment ne "<null>" && $comments ne "MICROS";
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
# Get The Business Date
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
    
	my $sth = $dbh->prepare("select initcap(trim(to_char(sysdate-1, 'MONTH'))) || to_char(sysdate-1, ' DD, YYYY') || initcap(to_char(sysdate-1, ' DAY')) from dual");
    
    $sth->execute;
    $sth->bind_columns(undef, \$bd );
    $sth->fetch();
    $sth->finish;
	
	return $bd;
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
