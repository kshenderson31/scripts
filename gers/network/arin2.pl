use Net::Whois::ARIN;

our $arin = Net::Whois::ARIN->new(host=>'whois.arin.net', port=>43, timeout=>45);
our %ips;
our %info;
our $circuits=0;

while(<DATA>)
{
	chomp($_);

	our $ip=$_;
	$ip =~ s/^\s+|\s+$//g;
	$ips{$ip}="Yes";
	
	our @result = $arin->query($_);
	our $idx=0;

	foreach(@result)
	{
		$_ =~ s/^\s+|\s+$//g;

		next if length($_) == 0;
		next if substr($_, 0, 1) eq "#";
		next if substr($_, 0, 1) eq ":";
		next if $_ eq " ";

		our($key, $data)=split(":", $_);

		if(defined $data)
		{
			$data =~ s/^\s+|\s+$//g;	
		}
		else
		{
			$idx++;
			$data=$key;
			$key=sprintf("%03d", $idx);
			#print "Key is $key";
		}
		
		$info{"$ip-$key"}=$data;
		#print "|$_|\n" if $ip eq "70.158.102.19";
	}
}

foreach our $key(sort keys %ips)
{
	printf("|%s|%s|%s|%s|%s|\n", $key, $info{"$key-OrgName"}, $info{"$key-City"}, $info{"$key-StateProv"}, $info{"$key-OrgTechPhone"}) if defined $info{"$key-OrgName"};
	printf("|%s|%s|%s|\n", $key, $info{"$key-001"}, $info{"$key-002"}) if defined $info{"$key-001"};
	foreach our $pre(sort keys %info)
	{
		our($k1, undef)=split("-", $pre);
		next if $k1 ne $key;
		#print "$pre:  $info{$pre}\n";
	}
	$circuits++;
}

print "\n\n$circuits circuits processed\n";

exit;

__DATA__
108.178.219.34
108.64.90.121
166.143.251.194
166.148.20.245
166.239.25.155
207.28.250.84
208.13.143.236
216.187.237.157
216.232.84.159
216.9.106.159
216.9.107.74
24.221.17.237
64.144.39.34
64.144.44.250
64.218.250.234
64.233.127.138
65.160.187.6
66.147.60.226
67.135.118.33
67.135.118.36
67.135.118.40
67.77.44.12
68.153.210.82
68.25.89.200
69.109.26.217
69.69.15.24
70.155.115.242
70.155.44.242
70.158.102.19
70.91.117.81
71.170.50.58
71.2.224.40
71.242.122.146
74.246.140.242
74.247.192.90
97.64.182.172
98.19.106.57
