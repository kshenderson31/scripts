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
		our $person=shift;
		
        our @result;
        our $s = Net::Appliance::Session->new({personality=>$person, transport=>'SSH', host=>"$ip", privileged_paging => 1});
        #$s->set_global_log_at('debug');

        print "SSH to $ip, ";

        our $cfg=sprintf("/usr/local/data/net/config/Paradies-%s-%s-Backup_%s.txt", $ip, $device{$ip}, getFormattedDateAndTime("yyyyMMdd"));

        eval
        {
                $s->connect(username=>$user, password=>$pass, privileged_password=>$enable, SHKC=>0);

                print "successful";

                $s->begin_privileged;

        		@result=$s->cmd('terminal pager 0');
                @result=$s->cmd('show running-config');

                print ", saving to $cfg";
                if(open(CFG, ">$cfg"))
                {
                        our $cnt=0;
                        foreach my $line(@result)
                        {
                                chomp($line);
                                print CFG "$line\n";
                                $cnt++;
                        }
                        close CFG;
                        print ", $cnt lines written";
                }
                else
                {
                        print ", failed to save configuration\n";
                        print "$!";
                }
        $s->end_privileged;
        $s->close;

                $status{$ip}="OK;Successfully backed up";

        print "\n";
        };

        if(!(-e $cfg))
        {
                our $msg=$@;
                our $save=$@;
                $msg=~s/\n/<br>/g;

                if(index(lc $msg, "connection refused") >= 0 || index(lc $msg, "timed-out") >= 0)
                {
                        print "failed, trying telnet, ";
                        tryToTelnet($ip, $user, $pass, $enable, $person);
                        if(!(-e $cfg))
                        {
                                $status{$ip}="Fail;$msg";
                                print "failed\n";
                                print "$save\n";
                        }
                }
                else
                {
                        $status{$ip}="Fail;$msg";
                        print "failed\n";
                        print "$@\n";
                }
        }
}
#*****************************************************************************
# tryToTelnet
#*****************************************************************************
#
sub tryToTelnet
{
        our $ip=shift;
        our $user=shift;
        our $pass=shift;
        our $enable=shift;
        our $person=shift;
        
        our @result;
        our $s = Net::Appliance::Session->new({personality=>$person, transport=>'Telnet', host=>"$ip", privileged_paging => 1});

        #$s->set_global_log_at('debug');

        our $cfg=sprintf("/usr/local/data/net/config/Paradies-%s-%s-Backup_%s.txt", $ip, $device{$ip}, getFormattedDateAndTime("yyyyMMdd"));

        eval
        {
                $s->connect(username=>$user, password=>$pass, privileged_password=>$enable, SHKC=>0);

                print "successful";

                $s->begin_privileged;

        @result=$s->cmd('terminal pager 0');
                @result=$s->cmd('show running-config');

                print ", saving to $cfg";
                if(open(CFG, ">$cfg"))
                {
                        our $cnt=0;
                        foreach my $line(@result)
                        {
                                chomp($line);
                                print CFG "$line\n";
                                $cnt++;
                        }
                        close CFG;
                        print ", $cnt lines written";
                }
                else
                {
                        print ", failed to save configuration\n";
                        print "$!";
                }
        $s->end_privileged;
        $s->close;

                $status{$ip}="OK;Successfully backed up";

        print "\n";
        };
}

#*****************************************************************************
# generateBackupReport
#*****************************************************************************
#
sub generateBackupReport
{
        $body .="<p>Contained below is the firewall configuration backup report.  Any devices in red need attention as a backup was not taken for some reason.</p>";
		
		$body .="<p>The following devices were not backed up and need attention.  Please review the list and take appropriate action based on the failure description.<br/></p>";
        
        $body.="<table border=\"0\" width=\"100%\"";
        $body.="<tr><th align=\"center\">IP Address</th><th align=\"left\">Location</th><th align=\"center\">Status</th><th align=\"left\">Description</th></tr>";

        foreach my $key (sort keys %status)
        {
                our($stat, $desc)=split(";", $status{$key});
                
                next if $stat eq "OK";

                $body.="<tr bgcolor=\"#FFCCCC\"><td align=\"center\">$key</td><td align=\"left\">$device{$key}</td><td align=\"center\">$stat</td><td>$desc</td></tr>" if $stat eq "Fail";
                $no++ if $stat eq "Fail";
        }

        $body.="<tr><td colspan=\"3\"><br />$no devices were not backed up</td></tr>";
        $body.="</table>";

        $body .="<p>The following devices were successfully backed up.<br/></p>";

        $body.="<table border=\"0\" width=\"100%\"";
        $body.="<tr><th align=\"center\">IP Address</th><th align=\"left\">Location</th><th align=\"center\">Status</th><th align=\"left\">Description</th></tr>";

		foreach my $key (sort keys %status)
        {
                our($stat, $desc)=split(";", $status{$key});
                
                next if $stat eq "Fail";
                
                $body.="<tr bgcolor=\"#C2FFC2\"><td align=\"center\">$key</td><td align=\"left\">$device{$key}</td><td align=\"center\">$stat</td><td>$desc</td></tr>" if $stat eq "OK";
                $ok++ if $stat eq "OK";
        }


        $body.="<tr><td colspan=\"3\"><br />$ok devices successfully backed up</td></tr>";
        $body.="</table>";

        $body .="<p></p>";

        sendMailMessage();
}

#*****************************************************************************
# archiveRunningConfiguration
#*****************************************************************************
#
sub archiveRunningConfiguration
{
        our $ftp;

        if(!($ftp = Net::FTP->new("204.75.12.80", Debug=>0, Passive=>0)))
        {
                print "Failed to connect to FTP site\n";
                print "$@";
                exit 10;
        }

        if(!($ftp->login("paradies-na",'Und3r$tudy')))
        {
                print "Login to FTP failed\n";
                print $ftp->message;
                exit 10;
        }

        if(!(opendir (DIR, "/usr/local/data/net/config")))
        {
                print "Failed to open directory\n";
                print $!;
                exit 10;
        }


        while (my $file = readdir(DIR))
        {
            next if ($file =~ m/^\./);

                print "Archiving $file";

                if(!($ftp->put("/usr/local/data/net/config/$file")))
                {
                        print ", failed\n";
                        printf("\t%s\n", $ftp->message);
                }
                else
                {
                        print ", archived";
                }

                print "\tRemoving configuration backup";

                if(!(unlink "/usr/local/data/net/config/$file"))
                {
                        print ", failed\n";
                        printf("\t%s\n", $!);
                }
                else
                {
                        print ", removed successfully";
                }
        }

        closedir(DIR);

        $ftp->quit;
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

        $device{$asa}=$desc;
        
		$user='pix' 		if not defined $user;
		$pass='install'    	if not defined $pass;
		$enable='install1'	if not defined $enable;
		
        trySSH($asa, $user, $pass, $enable, $person || 'ios');
   	}

    generateBackupReport();
    archiveRunningConfiguration();
    
    print "\n\n";

    exit 0;
}

__DATA__
207.148.201.82,BWI-9410-Manager.Office,glstech,rou73r,install1
108.178.219.34,MLI-9480-Manager.Office,glstech,rou73r,install1,pixos
108.64.90.121,MFE-9956-Manager.Office,glstech,rou73r,install1
12.202.145.98,CLT-9704-CHARLOTTE.WAREHOUSE,glstech,rou73r,install1
12.202.164.122,CLT-9704-Manager.Office,glstech,rou73r,install1
166.143.251.194,XNA-9479-Office,glstech,rou73r,install1
166.148.20.245,LAS-9921-Warehouse,glstech,rou73r,install1
166.239.25.155,SGF-9417-Office,glstech,rou73r,install1
173.9.129.129,FLL-9800-Warehouse,glstech,rou73r,install1
207.28.250.84,DSM-9034-Des.Moines,glstech,rou73r,install1
208.13.143.236,LAS-9921-Warehouse,glstech,rou73r,install1
216.187.237.157,TYS-9635-KNOXVILLE,glstech,rou73r,install1
216.232.84.159,YVR-9450-Warehouse,glstech,rou73r,install1
216.9.106.159,SFO-9415-Warehouse,glstech,rou73r,install1
216.9.107.74,SFO-9415-Office,glstech,rou73r,install1
64.144.44.250,DAY-9600-Manager.Office,glstech,rou73r,install1
64.218.250.234,MAF-9080-Manager.Office,glstech,rou73r,install1
64.222.47.250,PVD-9046-Warehouse,glstech,rou73r,install1
64.233.127.138,PNS-9436-Manager.Office,glstech,rou73r,install1
65.160.187.6,SAV-9130-Manager.Office,glstech,rou73r,install1
66.147.60.226,AVL-9828-Office,glstech,rou73r,install1
66.192.167.34,RDU-9090-RALEIGH.OFFICE.T2,glstech,rou73r,install1
67.135.118.33,SLC-9801-SALT.LAKE.CITY.106A.OFFICE,glstech,rou73r,install1
67.135.118.36,SLC-9801-SALT.LAKE.CITY.TU.OFFICE,glstech,rou73r,install1
67.135.118.40,SLC-9801-SALT.LAKE.CITY.115B.OFFICE,glstech,rou73r,install1
67.77.44.12,LAS-9921-Manager.Office,glstech,rou73r,install1
68.153.210.82,PBI-9120-Manager.Office,glstech,rou73r,install1,pixos
68.167.157.194,SNA-9675-Office,glstech,rou73r,install1
68.25.89.200,ISP-9140-Warehouse,glstech,rou73r,install1
68.96.151.83,BTR-9525-Stockroom-behind.tkt.counter
69.109.26.217,RNO-9250-Warehouse,glstech,rou73r,install1
69.33.189.2,RDU-9090-Warehouse,glstech,rou73r,install1
69.69.15.24,RSW-9101-Manager.Office,glstech,rou73r,install1,pixos
70.155.115.242,ATL-9770-Manager.Office,glstech,rou73r,install1
70.155.44.242,PBI-9120-WEST.PALM.BEACH.RMM.OFFICE,glstech,rou73r,install1
70.158.102.19,ATL-9770-Atlanta.F.Concourse,glstech,rou73r,install1
70.91.117.81,TLH-9210-Manager.Office,glstech,rou73r,install1
71.170.50.58,DFW-9031-Cash.Office,glstech,rou73r,install1
71.2.224.40,RSW-9101-Warehouse,glstech,rou73r,install1
71.242.122.146,PHL-9535-Warehouse,glstech,rou73r,install1,pixos
74.246.140.242,ATL-9770-ATLANTA.WAREHOUSE,glstech,rou73r,install1
74.247.192.90,JAX-9056-Warehouse,glstech,rou73r,install1,pixos
97.64.182.172,MLI-9480-MOLINE,glstech,rou73r,install1
98.19.106.57,LEX-9370-Manager.Office,glstech,rou73r,install1
99.52.237.1,IND-9053-Manager.Office,glstech,rou73r,install1
99.56.225.65,BDL-9850-Manager.Office,glstech,rou73r,install1