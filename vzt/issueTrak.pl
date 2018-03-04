#!perl 
use SOAP::Lite on_action => sub {sprintf '%s%s', @_}, trace => debug; 
# Create the proxy to the web service. 
my $IssueTrak = SOAP::Lite
 ->uri('http://hdticket.hti.com/IssueTrakService')
 
->proxy('http://hdticket.hti.com/IssueTrakService/IssueTrakService.asmx');
 
# Create the XML document to pass in to the GetIssues() web method.
 
# This creates a issueNums variable and assigns the XML as the value.
 
my @request = (
 SOAP::Data->name('userID', 'khenderson'),
 
SOAP::Data->name('password', 'H3@rtNur$3'),
 SOAP::Data->name('issueNums' => \ SOAP::Data->value(
 
SOAP::Data->name('IssueNums' => \ SOAP::Data->value( 
SOAP::Data->name('ReturnSchema', 'Y'), 
SOAP::Data->name('IssueNum', '878704'), 
SOAP::Data->name('IssueNum', '865231') 
))))); 
# Call the GetIssues() web method of the IssueTrak web service.
 
my $method = SOAP::Data->name('GetIssues')
 
->attr({xmlns => 'http://hdticket.hti.com/IssueTrakService/'});
 
# What came back to us?
 # This should return a SOAP response with requested Issue data.
 my $result = $IssueTrak->call($method, @request);
 
