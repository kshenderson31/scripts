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
	# Load Register IPs 
	#****************************************************************************************************************************************************************
	#
	updateRegisters();

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
	getopts("r:i:", \%opt);
}
#********************************************************************************************************************************************************************
# 
#********************************************************************************************************************************************************************
#
sub updateRegisters
{
	our $cnt=0;
	
	while(<DATA>)
	{
		chomp($_);
		our($reg, $ip)=split(",", $_);
		our($store, $term)=split("-", $reg);
		next if not defined $ip;
		printChronologicalMessage("Updating $store\-$term with $ip");
		updateAddress($databaseHandler, $store, $term, $ip);
		$cnt++;
	}
	printChronologicalMessage("$cnt registers updated", "N");
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
# Get The Business Date
#********************************************************************************************************************************************************************
#
sub updateAddress
{
    my $dbh=shift;
    my $store=shift;
    my $register=shift;
    my $address=shift;
    
    my $sql="UPDATE MISC.POLLING SET rgstr_ip_addr=\'$address\' WHERE store_cd=\'$store\' AND term_num=\'$register\'";
	my $sth = $dbh->prepare($sql);
    
    if(!($sth->execute))
    {
    	printChronologialMessage("Error Encountered");
    	printChronologialMessage(DBI::errstr);
    }
    
    $sth = $dbh->prepare("COMMIT");
    $sth->execute;
    
    $sth->finish;
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

__DATA__
0019-01,172.23.212.5
0020-01,172.25.19.34
0021-01,172.25.19.66
0021-02,172.25.19.67
0023-01,172.25.19.98
0023-02,172.25.19.99
0024-01,172.25.19.130
0025-01,172.25.19.162
0025-03,172.25.19.164
0026-01,172.25.19.194
0026-02,172.25.19.195
0027-01,172.25.19.226
0027-02,172.25.19.227
0028-01,172.25.20.2
0028-02,172.25.20.3
0030-01,172.25.20.34
0031-01,172.25.102.2
0031-02,172.25.102.3
0031-03,172.25.102.98
0031-04,172.25.102.99
0032-01,172.25.102.34
0032-02,172.25.102.35
0033-01,172.25.102.66
0038-01,172.25.105.2
0038-02,172.25.105.3
0039-01,172.25.105.34
0041-01,172.25.109.2
0041-02,172.25.109.3
0044-01,172.25.25.2
0044-02,172.25.25.3
0045-01,172.25.25.34
0045-02,
0046-01,172.25.25.66
0046-02,172.25.25.67
0047-01,172.25.25.98
0047-02,172.25.25.99
0047-03,172.25.25.100
0047-04,172.25.25.101
0048-01,172.25.25.130
0048-02,172.25.25.131
0051-01,172.25.56.3
0052-01,172.25.25.162
0053-01,172.25.25.194
0053-02,172.25.25.195
0057-01,172.25.25.226
0057-02,172.25.25.227
0061-01,172.25.14.34
0061-02,172.25.14.35
0061-03,172.25.14.36
0062-01,10.100.0.34
0063-01,172.25.14.2
0063-02,172.25.14.3
0063-03,172.25.14.4
0064-01,10.100.0.50
0064-02,10.100.0.51
0067-01,10.100.0.66
0067-02,10.100.0.67
0068-01,172.25.44.2
0068-02,172.25.44.3
0068-03,172.25.44.4
0069-01,172.25.44.34
0070-01,172.25.44.66
0071-01,172.25.44.98
0071-02,172.25.44.99
0072-01,172.25.44.130
0072-02,172.25.44.131
0072-03,172.25.44.132
0073-01,172.25.44.162
0073-02,172.25.44.163
0074-01,172.25.44.194
0074-02,172.25.44.195
0075-01,172.25.44.226
0075-02,172.25.44.227
0076-01,172.25.45.2
0078-01,172.25.45.34
0084-01,172.25.45.66
0085-01,172.25.45.98
0085-02,172.25.45.99
0086-01,172.25.45.130
0087-01,172.25.45.162
0087-02,172.25.45.163
0087-03,172.25.45.164
0088-01,172.25.45.194
0088-02,172.25.45.195
0088-03,172.25.45.196
0091-01,172.25.97.2
0091-02,172.25.97.3
0093-01,172.25.97.34
0093-02,172.25.97.35
0093-03,172.25.97.36
0094-01,172.25.97.66
0094-02,172.25.97.67
0096-01,172.25.97.98
0097-01,172.25.97.130
0097-02,172.25.97.131
0099-01,172.25.97.162
0100-01,172.25.97.194
0100-02,172.25.97.195
0108-01,172.25.74.2
0108-02,172.25.74.3
0108-03,172.25.74.4
0111-01,172.25.74.34
0114-01,172.25.74.66
0114-02,172.25.74.67
0114-03,172.25.74.68
0117-01,172.25.74.98
0117-02,172.25.74.99
0118-01,172.25.74.130
0118-02,172.25.74.131
0118-03,172.25.74.132
0119-01,172.25.74.162
0119-02,172.25.74.163
0120-01,172.25.74.194
0121-01,172.25.34.2
0121-02,172.25.34.3
0121-03,172.25.34.4
0122-01,172.25.35.66
0122-02,172.25.35.67
0122-03,172.25.35.68
0123-01,172.25.34.34
0123-02,172.25.34.35
0123-03,172.25.34.36
0123-04,172.25.34.37
0123-05,172.23.206.5
0123-06,172.23.208.5
0124-01,172.25.34.66
0124-02,172.25.34.67
0126-01,172.25.34.98
0126-02,172.25.34.99
0127-01,172.25.35.98
0133-01,172.25.34.130
0133-02,172.25.34.131
0134-01,172.25.34.162
0134-02,172.25.34.163
0135-01,172.25.34.194
0136-01,172.25.34.226
0138-01,172.25.35.2
0138-02,172.25.35.3
0139-01,172.25.35.34
0139-02,172.25.35.35
0164-01,172.25.65.2
0164-02,172.25.65.3
0166-01,172.25.65.34
0167-01,172.25.65.66
0167-02,172.25.65.67
0169-01,172.25.65.98
0169-02,172.25.65.99
0171-01,172.25.65.130
0171-02,172.25.65.131
0172-01,172.25.65.162
0173-01,172.25.65.194
0173-02,172.25.65.195
0174-01,172.25.65.226
0174-02,172.25.65.227
0175-01,172.25.66.2
0177-01,172.25.66.34
0177-02,172.25.66.35
0178-01,172.25.66.66
0178-02,172.25.66.67
0178-03,172.25.66.68
0178-04,172.25.66.69
0178-05,172.25.66.70
0179-01,172.25.66.98
0180-01,172.25.115.2
0180-02,172.25.115.3
0181-01,172.25.115.34
0181-02,172.25.115.35
0182-01,172.25.66.130
0182-02,172.25.66.131
0183-01,172.25.66.162
0183-02,172.25.66.163
0184-01,172.25.66.194
0185-01,172.25.115.66
0185-02,172.25.115.67
0186-01,172.25.115.98
0186-02,172.25.115.99
0191-01,172.25.69.2
0191-02,172.25.69.3
0192-01,172.25.69.34
0192-02,172.25.69.35
0197-01,172.25.87.2
0197-02,172.25.87.3
0198-01,172.25.87.34
0198-02,172.25.87.35
0199-01,172.25.87.66
0201-01,172.25.87.98
0202-01,172.25.87.130
0202-02,172.25.87.131
0202-03,172.25.87.132
0202-04,172.25.87.133
0203-01,172.25.87.162
0203-02,172.25.87.163
0204-01,172.25.87.194
0204-02,172.25.87.195
0205-01,172.25.87.226
0205-02,172.25.87.227
0206-01,172.25.88.2
0206-02,172.25.88.3
0207-01,172.25.88.34
0207-02,172.25.88.35
0210-01,172.25.92.2
0210-02,172.25.92.3
0211-01,172.25.92.34
0211-03,172.25.92.36
0212-01,172.25.92.66
0213-01,172.25.92.98
0213-02,172.25.92.99
0214-01,172.25.92.130
0215-01,172.25.92.162
0216-01,172.25.92.194
0216-02,172.25.92.195
0222-01,172.25.103.2
0222-02,172.25.103.3
0223-01,172.25.103.34
0223-02,172.25.103.35
0223-03,172.25.103.36
0224-01,172.25.103.66
0225-01,172.25.103.98
0225-02,172.25.103.99
0231-01,172.25.62.2
0232-01,172.25.62.34
0232-02,172.25.62.35
0233-01,172.25.62.66
0233-02,172.25.62.67
0238-01,172.25.110.2
0238-02,172.25.110.3
0238-03,172.25.110.34
0240-01,172.25.113.2
0240-02,172.25.113.3
0245-01,172.25.36.2
0245-02,172.25.36.3
0245-03,172.25.36.4
0246-01,172.25.36.34
0246-02,172.25.36.35
0246-03,172.25.36.36
0247-01,172.25.36.66
0247-02,172.25.36.67
0247-03,172.25.36.68
0248-01,172.25.36.98
0248-02,172.25.36.99
0249-01,172.25.36.130
0251-01,172.25.36.162
0251-02,172.25.36.163
0252-01,172.25.36.194
0253-01,172.25.36.226
0254-01,172.25.37.2
0255-01,172.25.37.34
0255-02,172.25.37.35
0256-01,172.25.37.66
0256-02,172.25.37.67
0257-01,172.25.37.98
0260-01,172.25.37.130
0260-02,172.25.37.131
0265-01,172.25.37.162
0277-01,172.25.37.194
0278-01,172.25.37.226
0280-01,172.25.38.2
0281-01,172.25.38.34
0282-01,172.25.38.66
0282-02,172.25.38.67
0286-01,172.25.38.98
0288-01,172.25.38.130
0289-01,172.25.38.162
0290-01,172.25.38.194
0295-01,10.15.0.34
0295-02,10.15.0.35
0297-01,10.15.0.2
0297-02,10.15.0.3
0300-01,172.25.79.2
0300-02,172.25.79.3
0301-01,172.25.79.34
0301-02,172.25.79.35
0302-01,172.25.79.66
0303-01,172.25.79.98
0303-02,172.25.79.99
0304-01,172.25.79.130
0306-02,172.25.51.3
0307-01,172.25.79.162
0307-02,172.25.79.163
0308-01,172.25.51.2
0309-01,172.25.79.194
0309-02,172.25.79.195
0310-01,172.25.79.226
0310-02,172.25.79.227
0311-01,172.25.79.226
0311-02,172.25.79.227
0312-01,172.25.80.2
0312-02,172.25.80.3
0313-01,172.25.80.34
0313-02,172.25.80.35
0314-01,172.25.80.67
0314-02,172.25.80.67
0315-01,172.25.80.66
0316-03,172.25.9.36
0327-01,172.25.9.226
0327-02,172.25.9.227
0327-04,172.25.9.228
0327-05,172.25.9.229
0328-01,172.25.10.2
0328-02,172.25.10.3
0329-01,172.25.10.34
0330-01,172.25.10.66
0332-01,172.25.10.98
0335-01,172.25.10.130
0335-02,172.25.10.131
0337-01,172.25.10.162
0337-02,172.25.10.163
0338-01,172.25.9.98
0338-02,172.25.9.99
0345-03,172.25.63.4
0345-04,172.25.63.5
0346-01,172.25.63.34
0346-02,172.25.63.35
0347-01,172.25.63.66
0347-02,172.25.63.67
0356-01,172.25.47.2
0356-02,172.25.47.3
0357-01,172.25.47.34
0360-01,172.25.75.2
0360-02,172.25.75.3
0361-01,172.25.75.34
0361-02,172.25.75.35
0362-01,172.25.70.2
0362-02,172.25.70.3
0363-01,172.25.70.34
0363-02,172.25.70.35
0364-01,172.25.70.66
0366-01,172.25.70.98
0366-02,172.25.70.99
0367-01,172.25.70.130
0367-02,172.25.70.131
0368-01,172.25.70.162
0369-01,172.25.70.194
0369-02,172.25.70.195
0372-01,172.25.70.226
0372-02,172.25.70.227
0375-01,172.25.71.2
0375-02,172.25.71.3
0376-01,172.25.71.34
0377-01,172.25.71.66
0377-02,172.25.71.67
0379-01,172.25.71.98
0380-01,172.25.71.130
0380-02,172.25.71.131
0381-01,172.23.202.5
0381-02,172.25.72.98
0384-01,172.25.71.162
0384-02,172.25.71.163
0385-01,172.25.71.194
0385-02,172.25.71.195
0386-01,172.25.71.226
0387-01,172.25.72.2
0387-02,172.25.72.3
0388-01,172.25.72.34
0388-02,172.25.72.35
0389-01,172.25.59.2
0389-02,172.25.59.3
0390-01,172.25.59.34
0390-02,172.25.59.35
0392-01,172.25.59.66
0394-01,172.25.59.98
0395-01,172.25.59.130
0395-02,172.25.59.131
0395-03,172.25.59.132
0400-01,172.25.78.2
0400-02,172.25.78.3
0400-03,172.25.78.4
0401-01,172.25.78.34
0402-01,172.25.78.66
0404-01,172.25.78.98
0404-02,172.25.78.99
0404-03,172.25.78.100
0404-04,172.25.78.101
0405-01,172.25.78.130
0410-01,172.20.125.25
0411-01,172.20.125.35
0411-02,172.20.125.36
0412-01,172.20.125.20
0412-02,172.20.125.21
0413-01,172.20.125.30
0413-02,172.20.125.11
0415-01,172.20.125.10
0421-01,172.25.101.34
0422-01,172.25.101.66
0423-01,172.25.100.226
0423-02,172.25.100.227
0423-03,172.25.100.228
0423-04,172.25.100.229
0424-01,172.25.100.194
0425-01,172.25.100.130
0425-02,172.25.100.131
0426-01,172.25.101.98
0427-01,172.25.101.130
0428-01,172.20.112.4
0428-02,172.20.112.5
0428-03,172.20.112.6
0428-04,172.20.112.7
0429-01,172.25.99.34
0429-02,172.25.99.35
0433-01,172.25.99.98
0435-01,10.20.0.2
0435-02,10.20.0.3
0436-01,10.20.0.4
0437-01,10.20.0.5
0441-01,172.25.98.2
0441-02,172.25.98.3
0442-01,172.25.98.34
0442-02,172.25.98.35
0444-01,172.25.98.66
0444-02,172.25.98.67
0445-01,172.25.98.98
0445-02,172.25.98.99
0450-02,10.120.0.5
0450-03,10.120.0.2
0450-04,10.120.0.3
0450-05,10.120.0.4
0451-01,10.120.0.17
0451-02,10.120.0.18
0451-03,10.120.0.19
0452-01,10.120.0.34
0452-02,10.120.0.35
0454-01,10.120.0.50
0456-01,172.25.4.130
0458-01,10.120.0.66
0465-01,172.25.42.2
0465-02,172.25.42.3
0466-01,172.25.42.34
0467-01,172.25.42.66
0468-01,172.25.42.98
0470-01,172.25.42.130
0470-02,
0470-03,172.25.42.132
0471-01,172.25.42.162
0471-02,172.25.42.163
0471-03,172.25.42.164
0471-04,172.25.42.165
0472-01,172.25.42.194
0472-02,172.25.42.195
0473-01,172.25.42.226
0473-02,172.25.42.227
0474-01,172.25.43.2
0474-02,172.25.43.3
0475-01,172.25.43.34
0475-02,172.25.43.35
0476-01,172.25.43.66
0476-02,172.25.43.67
0476-03,172.25.43.68
0476-04,172.25.43.69
0478-01,172.25.43.98
0478-02,172.25.43.99
0481-01,172.25.43.130
0481-02,172.25.43.131
0483-01,172.25.43.162
0483-02,172.25.43.163
0485-01,172.25.89.2
0485-02,172.25.89.3
0486-01,172.25.89.34
0493-01,172.25.64.2
0493-02,172.25.64.3
0494-01,172.25.64.34
0494-02,172.25.64.35
0501-01,172.25.86.2
0501-02,172.25.86.3
0502-01,172.25.86.34
0502-02,172.25.86.35
0502-03,172.25.86.36
0503-01,172.25.86.66
0503-02,172.25.86.67
0510-01,172.25.53.2
0511-01,172.25.53.34
0511-02,172.25.53.35
0512-01,172.25.53.66
0512-02,172.25.53.67
0513-01,172.25.53.98
0513-02,172.25.53.99
0514-02,172.25.53.130
0514-03,172.25.53.131
0515-01,172.25.53.162
0515-02,172.25.53.163
0515-03,172.23.207.5
0515-04,172.23.211.5
0516-01,172.25.53.194
0516-02,172.25.53.195
0518-01,172.25.53.226
0519-01,172.25.54.2
0521-01,172.25.54.34
0521-02,172.25.54.35
0527-01,172.23.203.5
0527-02,172.23.200.5
0527-03,172.23.208.5
0527-04,172.23.206.5
0528-01,172.25.46.2
0528-02,172.25.46.3
0529-01,172.25.46.34
0529-02,172.25.46.35
0530-01,172.25.46.66
0530-02,172.25.46.67
0536-01,172.25.46.98
0536-02,172.25.46.99
0536-03,172.25.46.100
0537-01,172.25.46.130
0538-01,172.25.46.162
0539-01,172.25.46.194
0539-02,172.25.46.195
0539-03,172.25.46.196
0540-01,172.25.46.226
0540-02,172.25.46.227
0541-01,172.25.16.2
0542-01,172.25.16.34
0542-02,172.25.16.35
0543-01,172.25.16.66
0543-02,172.25.16.67
0544-01,172.25.16.98
0544-02,172.25.16.99
0545-01,172.25.16.130
0550-01,172.25.60.2
0550-02,172.25.60.3
0551-01,172.25.60.34
0551-02,172.25.60.35
0553-01,172.25.60.66
0554-01,172.25.60.98
0554-02,172.25.60.99
0555-01,172.25.60.130
0556-01,172.25.60.162
0556-02,172.25.60.163
0557-01,172.25.60.194
0558-01,172.25.60.226
0558-02,172.25.60.227
0558-03,172.25.60.228
0561-01,172.25.61.2
0561-02,172.25.61.3
0561-03,172.25.61.4
0562-01,172.25.61.34
0562-02,172.25.61.35
0581-01,172.25.84.2
0581-02,172.25.84.3
0583-01,172.25.84.34
0583-02,172.25.84.35
0583-03,172.23.200.5
0583-04,172.23.204.5
0583-05,172.23.203.5
0584-01,172.25.84.66
0585-01,172.25.84.98
0586-01,172.25.84.130
0586-02,172.25.84.131
0586-03,172.23.211.5
0586-04,172.23.207.5
0587-01,172.25.84.162
0587-02,172.25.84.163
0588-01,172.25.84.194
0589-01,172.25.84.226
0589-02,172.25.84.227
0590-01,172.25.85.2
0592-01,172.25.83.2
0592-02,172.25.83.3
0594-01,172.25.83.34
0594-02,172.25.83.35
0608-05,172.20.8.112
0618-01,172.25.81.2
0618-02,172.25.81.3
0619-01,172.25.81.34
0619-02,172.25.81.35
0641-01,172.25.73.2
0641-02,172.25.73.3
0642-01,172.25.73.34
0642-02,172.25.73.35
0643-01,172.25.73.66
0643-02,172.25.73.67
0644-01,172.25.73.98
0645-01,172.20.48.11
0654-01,172.21.94.4
0654-02,172.21.94.5
0656-01,172.25.23.194
0656-02,172.25.23.195
0656-03,172.25.23.196
0662-01,172.25.23.226
0666-01,172.25.48.2
0666-01,172.25.23.172
0666-02,172.25.23.173
0667-01,172.25.23.169
0667-02,172.25.23.170
0667-03,172.25.23.171
0668-01,172.25.23.167
0668-02,172.25.23.168
0669-01,172.25.23.164
0670-01,172.25.23.165
0670-02,172.25.23.166
0671-01,172.25.23.162
0671-02,172.25.23.163
0689-01,
0689-02,172.25.8.2
0689-03,
0690-01,172.25.8.34
0690-02,172.25.8.35
0690-03,172.25.8.36
0694-01,172.25.13.2
0694-02,172.25.13.3
0695-01,172.25.13.34
0695-02,172.25.13.35
0696-01,172.25.13.66
0696-02,172.25.13.67
0696-03,172.25.13.68
0697-01,172.25.13.98
0697-02,172.25.13.99
0718-01,172.25.55.2
0718-02,172.25.55.3
0719-01,172.25.55.34
0719-02,172.25.55.35
0720-01,172.25.55.66
0720-02,172.25.55.67
0721-01,172.25.55.98
0721-02,172.25.55.99
0735-01,172.25.108.2
0735-02,172.25.108.3
0735-03,172.23.207.5
0736-01,172.25.108.34
0736-02,172.25.108.35
0737-01,172.25.108.66
0738-01,172.25.108.98
0738-02,172.25.108.99
0738-03,172.25.108.100
0738-04,172.25.108.101
0739-01,172.25.108.130
0739-02,172.25.108.131
0740-01,172.25.108.162
0740-02,172.25.108.163
0740-03,172.25.108.164
0740-04,172.25.108.165
0742-01,172.25.108.194
0742-02,172.25.108.195
0743-01,172.25.67.2
0745-01,172.20.202.5
0746-01,172.25.22.2
0746-02,172.25.22.3
0746-03,172.25.22.4
0747-01,172.25.67.98
0747-02,172.25.67.99
0750-01,172.25.48.2
0750-02,172.25.48.3
0751-02,10.100.0.130
0751-03,172.23.201.5
0752-01,172.25.48.66
0752-02,172.25.48.67
0753-01,172.25.48.98
0753-02,172.25.48.99
0753-03,172.25.48.100
0753-04,172.23.203.5
0754-01,10.10.1.236
0754-02,10.10.1.234
0755-01,10.100.0.146
0755-02,10.100.0.147
0756-01,10.100.0.162
0756-02,10.100.0.163
0756-03,10.100.0.164
0756-04,10.100.0.165
0757-01,10.100.0.178
0757-02,10.100.0.179
0758-01,172.25.48.226
0758-02,172.25.48.227
0759-01,10.100.0.194
0770-01,172.25.94.2
0770-02,172.25.94.3
0771-01,172.25.94.34
0771-02,172.25.94.35
0772-01,172.25.94.66
0772-02,172.25.94.67
0784-01,172.25.50.2
0784-02,
0786-01,
0786-02,172.25.50.35
0786-03,172.25.50.36
0789-01,172.25.50.66
0790-01,
0790-02,
0791-01,
0791-02,
0801-01,172.25.58.2
0801-02,172.25.58.3
0802-01,172.25.58.34
0802-02,172.25.58.35
0802-03,172.25.58.36
0803-01,172.25.58.66
0803-02,172.25.58.67
0810-01,172.25.117.2
0810-02,172.25.117.3
0812-01,172.25.117.34
0813-01,172.25.117.66
0816-01,172.25.117.98
0816-02,172.25.117.99
0819-01,172.23.210.5
0821-01,172.25.118.2
0821-02,172.25.118.3
0822-02,172.25.118.35
0823-01,172.25.118.66
0823-02,172.25.118.67
0823-03,172.25.118.68
0825-01,172.21.55.5
0826-01,172.25.118.98
0826-02,172.25.118.99
0827-01,172.25.118.130
0827-02,172.25.118.131
0828-01,172.25.118.162
0828-02,172.25.118.163
0830-01,172.25.118.226
0830-02,172.25.118.227
0831-01,172.25.119.2
0831-02,172.25.119.3
0832-01,172.25.119.34
0833-01,172.25.119.66
0870-02,172.25.112.3
0871-01,172.25.112.34
0871-02,172.25.112.35
0872-01,172.25.112.66
0872-02,172.25.112.67
0882-01,172.25.17.98
0882-02,172.25.17.99
0882-03,172.25.17.100
0882-04,172.23.209.5
0883-01,172.25.17.130
0884-01,172.25.17.162
0886-01,172.25.17.2
0887-01,172.25.17.34
0888-01,172.25.17.66
0910-01,172.25.111.2
0910-02,172.25.111.3
0920-01,172.25.107.2
0920-02,172.25.107.3
0921-01,172.25.107.34
0921-02,172.25.107.35
0922-02,172.25.107.67
0923-01,172.25.107.98
0924-01,172.25.107.130
0924-02,172.25.107.131
0925-01,172.25.107.162
0925-02,172.25.107.163
0926-01,172.25.107.194
0926-02,172.25.107.195
0931-01,172.25.12.2
0932-01,172.25.12.34
0933-01,172.25.12.66
0934-01,172.25.12.98
0934-02,172.25.12.99
0934-03,172.25.12.100
0935-01,172.25.12.130
0935-02,172.25.12.131
0935-03,172.25.12.132
0936-01,172.25.12.162
0936-02,172.25.12.163
0937-01,172.25.12.194
0950-01,172.25.104.2
0950-02,172.25.104.3
0951-03,172.25.104.36
0955-01,172.25.104.162
0955-02,172.25.104.163
0955-03,172.25.104.164
0960-01,10.25.1.53
0960-02,10.25.1.54
0960-03,10.25.1.55
0961-01,10.25.1.50
0961-02,10.25.1.51
0961-03,10.25.1.52
0963-01,10.25.1.56
0963-02,10.25.1.57
0964-01,172.25.82.34
0964-02,172.25.82.66
0965-01,172.25.82.66
0966-01,172.25.82.98
0970-01,172.25.93.2
0971-01,172.25.93.34
0971-02,172.25.93.35
0980-01,172.25.30.2
0980-02,172.25.30.3
0980-03,172.25.30.4
0981-01,172.25.30.34
0981-02,172.25.30.35
0982-01,172.25.30.66
0982-02,172.25.30.67
0983-01,172.25.30.98
0983-02,172.25.30.99
0985-01,172.25.30.162
0985-02,172.25.30.163
0986-01,172.25.30.194
0986-02,172.25.30.195
0987-01,172.25.30.226
0987-02,172.25.30.227
0991-01,172.25.90.2
0991-02,172.25.90.3
0992-01,172.25.90.34
0992-02,172.25.90.35
0992-03,172.23.205.5
0992-04,172.23.211.5
0993-01,172.25.90.66
0993-02,172.25.90.67
0993-03,172.25.90.68
0994-01,172.25.90.98
0994-02,172.25.90.99
0994-03,172.25.90.100
0994-04,172.25.90.101
0995-01,172.25.90.130
0995-02,172.25.90.131
0995-03,172.25.90.132
1002-01,172.25.20.66
1002-02,172.25.20.67
1003-01,172.25.20.98
1003-02,172.25.20.99
1018-01,172.25.19.2
1018-02,172.25.19.3
1018-03,172.25.19.4
1022-01,172.25.20.130
1022-02,172.25.20.131
1022-03,172.25.20.132
1022-04,172.25.20.133
1060-01,10.100.0.82
1060-02,10.100.0.83
1060-03,10.100.0.84
1063-01,10.100.0.98
1063-02,10.100.0.99
1064-01,10.100.0.114
1065-01,172.25.15.2
1066-01,172.25.15.34
1067-01,172.25.15.66
1067-02,172.25.15.67
1067-03,172.25.15.68
1068-01,172.25.15.98
1068-02,172.25.15.99
1068-03,172.25.15.100
1069-01,172.25.15.130
1165-01,10.11.2.130
1165-02,10.10.2.131
1166-01,10.10.2.133
1166-02,10.10.2.134
1167-01,10.11.2.98
1167-02,10.11.2.99
1168-01,10.10.0.162
1169-01,10.10.0.194
1170-01,10.10.0.226
1170-02,10.10.0.227
1171-01,10.10.1.164
1171-02,10.10.1.163
1172-01,10.10.1.66
1172-02,10.10.1.67
1173-01,10.10.1.98
1175-01,10.10.1.131
1175-02,10.10.1.132
1176-01,10.10.2.2
1176-02,10.10.2.3
1375-01,172.25.72.66
1760-01,172.25.94.98
1760-02,172.25.94.99
1760-03,172.25.94.100
1761-01,172.25.94.130
1762-01,172.25.94.162
1763-01,172.25.94.194
1764-01,172.25.94.226
1764-02,172.25.94.227
1765-01,172.25.95.2
1765-02,172.25.95.3
1766-01,172.25.95.34
1766-02,172.25.95.35
1767-01,172.25.95.66
1767-02,172.25.95.67
1771-01,172.25.95.98
1771-02,172.25.95.99
1771-03,172.25.95.100
1771-04,172.23.210.5
1772-01,172.25.95.130
1772-02,172.25.95.131
1773-01,172.25.95.162
1774-01,172.25.95.194
1774-02,172.25.95.195
1775-01,172.25.95.226
1776-01,172.25.96.2
1776-02,172.25.96.3
1776-03,172.25.96.4
1777-01,172.25.96.34
1780-01,172.25.96.66
1780-02,172.25.96.67
2000-01,172.25.76.2
2001-02,172.25.76.34
2002-01,172.25.76.66
2002-02,172.25.76.67
2002-03,172.25.76.68
2003-01,172.25.76.98
2003-02,172.25.76.99
2003-03,172.25.76.100
2004-01,172.25.76.130
2004-02,172.25.76.131
2005-01,172.25.76.162
2006-01,172.25.76.194
2007-01,172.25.76.226
2008-01,172.25.77.2
2008-02,172.25.77.3
2008-03,172.25.77.4
2009-01,172.25.77.34
2009-02,172.25.77.35
2009-03,172.25.77.36
2010-01,10.10.0.34
2010-02,10.10.0.35
2011-01,10.10.0.36
2011-02,10.10.0.37
2017-01,172.20.35.36
2017-02,172.20.35.37
2018-01,172.20.35.11
2018-02,172.20.35.12
2018-03,172.20.35.13
2018-04,172.20.35.15
2019-01,172.20.35.33
2019-02,172.20.35.17
2020-01,10.10.1.5
2021-01,172.25.1.34
2021-02,172.25.1.35
2021-03,172.25.1.36
2021-04,172.23.208.5
2021-05,172.23.203.5
2022-01,172.25.1.2
2022-02,172.25.1.3
2023-01,172.25.1.66
2024-01,172.25.1.98
2024-02,172.25.1.99
2025-01,172.25.1.130
2025-02,172.25.1.131
2026-01,172.25.1.162
2027-01,172.25.1.194
2028-01,172.25.1.226
2028-02,172.25.1.227
2028-03,172.25.1.228
2028-04,172.25.2.2
2028-05,172.23.211.5
2028-06,172.25.2.3
2029-01,172.25.2.34
2029-02,172.25.2.35
2030-01,172.25.2.66
2030-02,172.25.2.67
2031-01,172.25.2.98
2031-02,172.25.2.99
2032-01,10.10.2.34
2032-02,10.10.2.35
2032-03,10.10.2.36
2032-04,172.23.205.5
2033-01,10.10.1.3
2033-02,10.10.1.4
2034-01,172.20.35.34
2035-01,172.20.35.35
2036-01,172.20.35.30
2036-02,172.20.35.31
2038-01,172.25.114.2
2038-02,172.25.114.3
2039-01,172.25.114.34
2039-02,172.25.114.35
2041-01,172.25.11.2
2041-02,172.25.11.3
2042-01,172.25.11.34
2050-01,172.25.57.2
2051-01,172.25.57.34
2051-02,172.25.57.35
2052-01,172.25.57.66
2053-01,172.25.57.98
2054-01,172.25.57.130
2054-02,172.25.57.131
2055-01,172.25.57.162
2055-02,172.25.57.163
2056-01,172.25.57.194
2061-01,172.25.7.2
2061-02,172.25.7.3
2061-03,172.25.7.4
2061-04,172.23.206.5
2061-05,172.23.208.5
2063-01,172.25.7.34
2070-01,172.25.27.194
2070-02,172.25.27.195
2071-01,172.25.27.226
2071-02,172.25.27.227
2071-03,172.25.27.228
2072-01,172.25.28.2
2072-02,172.25.28.3
2073-01,172.25.28.34
2073-02,172.25.28.35
2074-01,172.25.28.66
2074-02,172.25.28.68
2074-03,172.25.28.68
2075-01,172.25.28.98
2075-02,172.25.28.99
2075-03,172.25.28.100
2075-04,172.25.28.101
2076-01,172.25.28.130
2076-02,172.25.28.131
2076-03,172.25.28.132
2077-01,172.25.28.162
2077-02,172.25.28.163
2078-01,172.25.28.194
2078-02,172.25.28.195
2078-03,172.25.29.98
2078-04,172.25.29.99
2079-01,172.21.107.4
2080-01,172.25.29.66
2080-02,172.25.29.67
2081-01,172.25.27.2
2081-02,172.25.27.3
2082-01,172.25.27.34
2082-02,172.25.27.35
2083-01,172.25.27.66
2083-02,172.25.27.67
2084-01,172.25.28.226
2087-01,172.25.27.98
2087-02,172.25.27.99
2088-01,172.25.29.34
2089-01,172.25.27.130
2090-01,172.25.29.2
3021-01,172.25.24.34
3022-01,172.26.1.102
3022-02,172.26.1.103
3022-03,172.23.205.5
3023-01,172.26.1.100
3023-02,172.26.1.101
3030-01,172.25.40.226
3030-02,172.25.40.227
3031-01,172.25.40.3
3031-02,172.25.40.3
3032-01,172.25.40.2
3032-02,172.25.40.3
3033-01,172.25.40.130
3033-02,172.25.40.131
3034-01,172.25.41.66
3035-01,172.25.40.194
3035-02,172.25.40.195
3036-01,172.25.40.162
3036-02,172.25.40.163
3037-01,172.25.41.34
3037-02,172.25.41.35
3037-03,172.25.41.36
3037-04,172.25.41.37
3038-01,172.25.40.34
3038-02,172.25.40.35
3038-03,172.25.40.36
3039-01,172.25.41.98
3040-01,172.25.41.2
3041-01,172.25.41.162
3042-01,172.25.40.66
3042-02,172.25.40.67
3043-01,172.25.40.98
3055-01,10.25.0.66
3055-02,10.25.0.67
3056-01,10.25.0.98
3057-01,10.25.0.35
3057-02,10.25.0.36
3057-03,10.25.0.42
3058-01,10.25.0.130
3060-01,10.130.0.34
3060-02,10.130.0.35
3062-01,10.130.0.114