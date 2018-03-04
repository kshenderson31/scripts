use strict;
use warnings;
use Cisco::Management;
use Data::Dumper;

our $ciscoManager;
our $ciscoSession;

our $cpuInformation;
our $interfaceInformation;
our $ipInformation;

open(LOG,">cisco.log");
while(<DATA>)
{
    chomp($_);
    interrogateCiscoDevice($_);    
}
close LOG;
exit 0;

sub interrogateCiscoDevice
{
    our $ip = shift;

    print "************************************************************************\n"; 
    print "Instantiating Cisco Manager for $ip\n";
    print "************************************************************************\n"; 
    if(!($ciscoManager = new Cisco::Management(-hostname => $ip, -community => 'public')))
    {
        print "Could not instantiate Cisco Manager; ".Cisco::Management->error."\n";
        return;
    }
    
    print "\nObtaining CPU Information\n";
    if(!($cpuInformation = $ciscoManager->cpu_info()))
    {
        print "Failed to obtain CPU information; ".Cisco::Management->error."\n";
        $ciscoManager->close;
        return;
    }
    ##print Dumper($cpuInformation);
    
    
    print "Obtaining Cisco Interfaces\n";
    if(!($interfaceInformation = $ciscoManager->interface_info()))
    {
        print "Failed to obtain interfaces; ".Cisco::Management->error."\n";
        $ciscoManager->close;
        return;
    }
    ##print Dumper($interfaceInformation);
    
    print "Obtaining Cisco IP Addresses\n";
    if(!($ipInformation = $ciscoManager->interface_ip()))
    {
        print "Failed to obtain IP Addresses; ".Cisco::Management->error."\n";
        $ciscoManager->close;
        return
    }
    ##print Dumper($ipInformation);
    
    our %ips = %{$ipInformation};
    
    my %x = %{$interfaceInformation};
    for my $key ( keys %x )
    {
        my @ipList = $ips{$key}->[0];
        my $value = $x{$key}->{'Description'};
        print "Interface #$key [$value]\n";
        
        print "\tType           $x{$key}->{'Type'}\n";
        print "\tSpeed          $x{$key}->{'Speed'}\n";
        print "\tOperStatus     $x{$key}->{'OperStatus'}\n";
        print "\tAdminStatus    $x{$key}->{'AdminStatus'}\n";
        print "\tLastChange     $x{$key}->{'LastChange'}\n";
        
        foreach my $i(@ipList)
        {
            print "\t\tIPAddress=$i->{'IPAddress'} IPMask=$i->{'IPMask'}\n" if defined $i->{'IPAddress'};
            print LOG "$ip Interface $key [$value]  $i->{'IPAddress'} $i->{'IPMask'}\n";
        }
    }
      
    $ciscoManager->close;
}

#172.20.100.1
#172.20.104.1
#172.20.108.1
#172.20.110.1
#172.20.112.1
#172.20.116.1
#172.20.120.1
#172.20.124.1
#172.20.125.1
#172.20.130.1
#172.20.144.1
#172.20.145.1
#172.20.16.1
#172.20.182.1
#172.20.182.6
#172.20.186.1
#172.20.190.1
#172.20.196.1
#172.20.198.1
#172.20.200.1
#172.20.202.1
#172.20.204.1
#172.20.220.1
#172.20.24.1
#172.20.25.1
#172.20.32.1
#172.20.35.1
#172.20.36.1
#172.20.40.1
#172.20.44.1
#172.20.48.1
#172.20.56.1
#172.20.60.1
#172.20.64.1
#172.20.68.1
#172.20.72.1
#172.20.76.1
#172.20.80.1
#172.20.84.1
#172.20.85.1
#172.20.88.1
#172.20.92.1
#172.20.96.1
#172.21.10.1
#172.21.100.1
#172.21.101.1
#172.21.102.1
#172.21.103.1
#172.21.104.1
#172.21.105.1
#172.21.106.1
#172.21.107.1
#172.21.108.1
#172.21.109.1
#172.21.110.1
#172.21.111.1
#172.21.112.1
#172.21.113.1
#172.21.115.1
#172.21.116.1
#172.21.117.1
#172.21.118.1
#172.21.119.1
#172.21.12.1
#172.21.120.1
#172.21.121.1
#172.21.122.1
#172.21.123.1
#172.21.124.1
#172.21.125.1
#172.21.13.1
#172.21.14.1
#172.21.150.1
#172.21.16.1
#172.21.17.1
#172.21.18.1
#172.21.19.1
#172.21.22.1
#172.21.23.1
#172.21.24.1
#172.21.25.1
#172.21.26.1
#172.21.27.1
#172.21.28.1
#172.21.29.1
#172.21.30.1
#172.21.31.1
#172.21.34.1
#172.21.35.1
#172.21.37.1
#172.21.38.1
#172.21.39.1
#172.21.40.1
#172.21.41.1
#172.21.42.1
#172.21.45.1
#172.21.46.1
#172.21.47.1
#172.21.48.1
#172.21.49.1
#172.21.50.1
#172.21.51.1
#172.21.52.1
#172.21.53.1
#172.21.54.1
#172.21.55.1
#172.21.56.1
#172.21.57.1
#172.21.59.1
#172.21.61.1
#172.21.64.1
#172.21.65.1
#172.21.66.1
#172.21.67.1
#172.21.68.1
#172.21.70.1
#172.21.71.1
#172.21.72.1
#172.21.73.1
#172.21.74.1
#172.21.75.1
#172.21.77.1
#172.21.78.1
#172.21.79.1
#172.21.8.1
#172.21.80.1
#172.21.81.1
#172.21.82.1
#172.21.83.1
#172.21.84.1
#172.21.85.1
#172.21.86.1
#172.21.87.1
#172.21.88.1
#172.21.89.1
#172.21.9.1
#172.21.90.1
#172.21.91.1
#172.21.92.1
#172.21.93.1
#172.21.94.1
#172.21.95.1
#172.21.96.1
#172.21.97.1
#172.21.98.1
#172.21.99.1
#172.26.1.1
#172.26.10.1
#172.26.20.1
__DATA__
172.21.107.1