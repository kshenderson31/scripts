#*****************************************************************************
# backFirewalls.pl
#*****************************************************************************
#
use strict;
use warnings;

use Net::Appliance::Session;
use Net::FTP;
use MIME::Lite;

#*****************************************************************************
# Define Global Variables
#*****************************************************************************
#
our $ok=0;
our $no=0;
our $body;
our %device;
our %status;

#*****************************************************************************
# Execute main
#*****************************************************************************
#
main();

exit 0;


#*****************************************************************************
# trySSH
#*****************************************************************************
#
sub trySSH
{
        our $ip=shift;
		our $user=shift;
		our $pass=shift;
		our $enable=shift;
		our $person=shift || 'ios';
		
        our @result;
        our $s = Net::Appliance::Session->new({personality=>$person, transport=>'SSH', host=>"$ip", privileged_paging => 1});
        #$s->set_global_log_at('debug');

        print "$ip";

        our $cfg=sprintf("/usr/local/data/net/config/Paradies-%s-%s-Backup_%s.txt", $ip, $device{$ip}, getFormattedDateAndTime("yyyyMMdd"));

        eval
        {
                $s->connect(username=>$user, password=>$pass, privileged_password=>$enable, SHKC=>0);

                $s->begin_privileged;
                $s->begin_configure;

        		@result=$s->cmd('terminal pager 0');
                @result=$s->cmd('username netadmin password install1 privilege 15');

                foreach my $line(@result)
                {
                	chomp($line);
                	print "$line\n";
                    
                }
                
                @result=$s->cmd('snmp-server community M@g3ll@n');

                foreach my $line(@result)
                {
                	chomp($line);
                	print "$line\n";
                }
	        	
			$s->end_configure;	        	
        	$s->end_privileged;
        	$s->close;
        };
        print "\n";
}
#*****************************************************************************
# sendEmailMessage
#*****************************************************************************
#
sub sendMailMessage
{
        ##printChronologicalMessage("Sending email message", "N");
#To      => 'it.network.norifications@paradies-na.com',
        our $msg = MIME::Lite->new(
            From    => '"Network Engineering"<noreply@paradies-na.com>',
            To      => 'kehenderson@paradies-na.com',
            Subject => "Firewall Configuration Backup Status ($no Failed)",
            Type    => 'text/html',
            Data    => $body
        );

        $msg->send('smtp','mail1.tpscorp.theparadiesshops.com', Debug=>0 );
}

#*****************************************************************************
# printChronologicalMessage
#*****************************************************************************
#

sub printChronologicalMessage
{
    my $msg = shift;

    print "[".getFormattedDateAndTime("mmmm dd, yyyy hr:mn:sc")."] $msg\n";
}

#*****************************************************************************
# getFormattedDateAndTime
#*****************************************************************************
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
	my $user;
	my $pass;
	my $enable;
	my $person;
	
	while(<DATA>)
    {
    	chomp($_);

        next if substr($_, 0, 1) eq "#";

        our($asa, $desc, $user, $pass, $enable, $person)=split(",", $_);

        $device{$asa}->{"Name"}=$desc;
        
		$user='pix' 		if not defined $user;
		$pass='install'    	if not defined $pass;
		$enable='install1'	if not defined $enable;
		$person='ios'       if not defined $person;
		
        trySSH($asa, $user, $pass, $enable, $person);
   	}

    exit 0;
}

__DATA__
207.148.201.82,BWI-9410-Manager.Office,glstech,install,install1
108.178.219.34,MLI-9480-Manager.Office,admin,install,install1,pixos7
108.64.90.121,MFE-9956-Manager.Office,admin,install,install1
64.233.127.138,PSP-0000-Manager.Office
24.172.44.66,CAE-9030-Manager.Office
12.202.145.98,CLT-9704-CHARLOTTE.WAREHOUSE,glstech,rou73r,install1
12.202.164.122,CLT-9704-Manager.Office,glstech,rou73r,install1
12.238.139.34,DTW-9750-Cash.Office
142.179.111.25,YVR-9450-DTB.Warehouse
166.143.251.194,XNA-9479-Office,admin,install,install1
166.148.20.245,LAS-9921-Warehouse,admin,install,install1
166.239.25.155,SGF-9417-Office,admin,install,install1
173.9.129.129,FLL-9800-Warehouse,glstech,rou73r,install1
184.0.25.84,LAS-9921-Manager.Office
205.232.71.149,TYS-9635-Warehouse
207.148.201.86,PHX-9700-Manager.Office
207.28.250.84,DSM-9034-Des.Moines,admin,install,install1
208.13.143.236,LAS-9921-Warehouse,admin,install,install1
216.187.237.157,TYS-9635-KNOXVILLE,admin,install,install1
216.232.84.159,YVR-9450-Warehouse,admin,install,install1
216.68.146.106,CVG-9859-Warehouse
216.9.107.74,SFO-9415-Office,admin,install,install1
24.221.17.237,XNA-9479-Warehouse
24.97.47.130,PWM-9690-Manager.Office
64.114.6.105,YVR-9450-ITB.Warehouse
64.114.6.97,YVR-9450-Manager.Office
64.144.39.34,PDX-9515-Manager.Office
64.144.44.250,DAY-9600-Manager.Office,admin,install,install1
64.144.45.34,COS-9880-Manager.Office
64.192.235.82,SAV-9130-Manager.Office
64.218.250.234,MAF-9080-Manager.Office,admin,install,install1
64.222.47.250,PVD-9046-Warehouse,glstech,rou73r,install1
64.233.127.138,PNS-9436-Manager.Office,admin,install,install1
64.252.154.14,BDL-9850-Warehouse
65.101.4.33,PHX-9700-Manager.Office
65.160.187.6,SAV-9130-Manager.Office,admin,install,install1
65.163.59.130,MEM-9780-Office
65.196.126.221,PIT-9351-Pittsburgh.Brighton
65.36.48.27,MAF-9080-Manager.Office
66.134.86.90,BUR-9041-Manager.Office
66.14.182.80,SRQ-9200-Manager.Office,glstech,rou73r,install1
66.147.60.226,AVL-9828-Office,admin,install,install1
66.192.167.34,RDU-9090-RALEIGH.OFFICE.T2,glstech,rou73r,install1
67.100.1.122,HILT-9713-Manager.Office
67.101.181.220,SNA-9675-Manager.Office
67.135.118.33,SLC-9801-SALT.LAKE.CITY.106A.OFFICE,admin,install,install1
67.135.118.36,SLC-9801-SALT.LAKE.CITY.TU.OFFICE,admin,install,install1
67.135.118.40,SLC-9801-SALT.LAKE.CITY.115B.OFFICE,admin,install,install1
67.77.44.12,LAS-9921-Manager.Office,admin,install,install1
67.79.83.246,HRL-9035-Manager.Office
68.153.210.82,PBI-9120-Manager.Office,glstech,rou73r,install1,pixos
68.157.129.242,ATL-9770-Atrium.Office
68.157.80.154,PBI-9120-Manager.Office,glstech,rou73r,install1
68.161.235.242,JFK-9212-Office
68.163.70.67,DCA-9391-Manager.Office
68.165.74.178,ELP-9915-Warehouse
68.167.157.194,SNA-9675-Office,glstech,rou73r,install1
68.213.73.26,JAX-9056-Manager.Office
68.222.222.10,PNS-9436-Office
68.236.219.225,EWR-9973-Manager.Office
68.25.89.200,ISP-9140-Warehouse,admin,install,install1
68.79.137.97,MKE-9021-Warehouse
68.93.95.129,IAH-9281-GBH.Warehouse,glstech,rou73r,install1
68.96.151.83,BTR-9525-Stockroom-behind.tkt.counter,glstech,rou73r,install1
69.109.26.209,RNO-9250-Cash.Office
69.109.26.217,RNO-9250-Warehouse,admin,install,install1
69.11.139.143,MSN-9725-Manager.Office
69.216.31.145,MKE-9059-Manager.Office
69.3.13.66,IAH-9281-Manager.Office
69.33.189.2,RDU-9090-Warehouse,glstech,rou73r,install1
69.34.201.8,MCI-9352-Warehouse
69.69.15.24,RSW-9101-Manager.Office,admin,install,install1,pixos
70.107.225.202,JFK-9212-Warehouse
70.155.44.242,PBI-9120-WEST.PALM.BEACH.RMM.OFFICE,admin,install,install1
70.158.102.19,ATL-9770-Atlanta.F.Concourse,admin,install,install1
70.168.68.193,TUL-9918-Mgr-Office
70.182.221.185,TUL-9918-Warehouse
70.50.230.136,YYZ-9425-YYZ-Mgr-Office-T3
70.52.235.112,YYZ-9425-YYZ-Mgr-Office-T1
70.91.117.81,TLH-9210-Manager.Office,admin,install,install1
70.91.117.85,TLH-9210-Manager.Office
70.91.234.161,FNT-9875-Manager.Office
71.116.207.66,LGB-9562-Manager.Office
71.154.61.205,IAH-9281-PGA.Office
71.170.50.58,DFW-9031-Cash.Office,admin,install,install1
71.2.224.40,RSW-9101-Warehouse,admin,install,install1
71.242.122.146,PHL-9535-Warehouse,admin,install,install1,pixos
71.250.253.65,EWR-9973-Manager.Office.Liberty.News
71.39.253.226,PHX-9700-Warehouse
71.39.70.33,PHX-9700-Manager.Office
72.149.177.218,GSO-9630-Cash.Office
74.0.72.90,EWR-9973-Warehouse
74.188.103.74,ATL-9770-Atlanta.NET.Office
74.246.140.242,ATL-9770-ATLANTA.WAREHOUSE,admin,install,install1
74.247.192.90,JAX-9056-Warehouse,admin,install,install1,pixos
74.247.48.202,HSV-9575-Manager.Office
97.64.182.172,MLI-9480-MOLINE,admin,install,install1
98.19.106.57,LEX-9370-Manager.Office,admin,install,install1
98.19.106.58,LEX-9370-Office
99.191.239.57,BDL-9850-Manager.Office
99.30.113.185,SNA-9675-Warehouse
99.52.237.1,IND-9053-Manager.Office,glstech,rou73r,install1
99.56.225.65,BDL-9850-Manager.Office,glstech,rou73r,install1
99.68.118.33,RNO-9250-Warehouse