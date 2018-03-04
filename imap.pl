use strict;
use warnings;
use Authen::NTLM;
use Mail::IMAPClient;

## Option variables
my $debug;
my $authmech = "NTLM";
my $username = "khenderson";
my $password = "H3\@rtNur\$3";

## Settings for connecting to IMAP server
my $imap = Mail::IMAPClient->new(
    Server            => 'mail-atl.hughestelematics.com',
    User              => $username,
    Password         => $password,
    Port              => 993,
    Ssl                => 1,
    Authmechanism  => $authmech,
    Debug => 1
) or die "Cannot connect through IMAPClient: $@\n";