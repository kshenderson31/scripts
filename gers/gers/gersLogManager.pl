#!/usr/bin/perl
#********************************************************************************************************************************************************************
# gersLogManager.pl
#
# This process sweeps directories looking for identified logs.  When found the files will be parsed and moved into a common log location
# for simplified analysis of issues.
#
# This process is scheduled to run every day at [time] on the GERS server to process this information.
#
# Maintenance History
#
#  Date        Associate                   Changes
#  ----------  --------------------------  ------------------------------------------------------------------------------------------------------------------------- 
#  2012-10-13  Ken Henderson               Initial Coding
#********************************************************************************************************************************************************************
# Perl Modules Used
#
use strict;
use warnings;

use File::Basename;
use File::stat;
#********************************************************************************************************************************************************************
# Global variables
#********************************************************************************************************************************************************************
#
our $program = "gersLogManager.pl";
our $version = "1.0.0";

our %mon2num = qw(jan 01 feb 02 mar 03 apr 04 may 05 jun 06 jul 07 aug 08 sep 09 oct 10 nov 11 dec 12);
our %nums    = qw(0 00 1 01 2 02 3 03 4 04 5 05 6 06 7 07 8 08 9 09);
our $errors  = "N";
our $warns   = "N";
#********************************************************************************************************************************************************************
# Open the process log for this process
#********************************************************************************************************************************************************************
#
my($seconds, $minutes, $hours, $day, $month, $year, $wday, $yday, $isdst) =  localtime(time);

$year    = $year + 1900;
$month   = $nums{$month+1} || $month+1;
$day     = $nums{$day} || $day;
$hours   = $nums{$hours} || $hours;
$minutes = $nums{$minutes} || $minutes;
$seconds = $nums{$seconds} || $seconds; 

my $prcssFileName = "gersLogManager.$year-$month-$day.$hours$minutes$seconds.log";
my $errorFileName = "gersLogManager.$year-$month-$day.$hours$minutes$seconds.err";

if(!(open(LOG,">/gers/genret/logs/$prcssFileName")))
{
    print "Failed to open gersLogManager log file [$prcssFileName], see information below.\n";
    print "$!";
    exit 1;
}

if(!(open(ERR,">/gers/genret/logs/$errorFileName")))
{
    print "Failed to open gersLogManager error file [$errorFileName], see information below.\n";
    print "$!";
    exit 1;
}
#********************************************************************************************************************************************************************
# Validate command line arguments
#********************************************************************************************************************************************************************
#
our $parmFileName = $ARGV[0] || "/gers/genret/logManager.ctl";
our $parseFlag    = $ARGV[1] || "N";
our $moveFlag     = $ARGV[2] || "N";
#********************************************************************************************************************************************************************
# printChronologicalMessage
#********************************************************************************************************************************************************************
#
sub printChronologicalMessage
{
    my($msg, $log) = @_;
    my($seconds, $minutes, $hours, $day, $month, $year, $wday, $yday, $isdst) =  localtime(time);

    $year    = $year + 1900;
    $month   = $nums{$month+1} || $month+1;
    $day     = $nums{$day} || $day;
    $hours   = $nums{$hours} || $hours;
    $minutes = $nums{$minutes} || $minutes;
    $seconds = $nums{$seconds} || $seconds; 

    print "$year-$month-$day $hours:$minutes:$seconds  $msg\n";
    
    if(defined $log)
    {
        if(lc $log eq "y")
        {
            if(!(print LOG "$year-$month-$day $hours:$minutes:$seconds  $msg\n"))
            {
                print "$year-$month-$day $hours:$minutes:$seconds  Log file write failed [$prcssFileName]\n";
                print "$year-$month-$day $hours:$minutes:$seconds  $!\n";
                exit 10;
            }
        }
    }
    else
    {
        if(!(print LOG "$year-$month-$day $hours:$minutes:$seconds  $msg\n"))
        {
            print "$year-$month-$day $hours:$minutes:$seconds  Log file write failed [$prcssFileName]\n";
            print "$year-$month-$day $hours:$minutes:$seconds  $!\n";
            exit 10;
        }
    }
}
#********************************************************************************************************************************************************************
# logErrorMessage
#********************************************************************************************************************************************************************
#
sub logErrorMessage
{
    my($msg) = @_;
    my($seconds, $minutes, $hours, $day, $month, $year, $wday, $yday, $isdst) =  localtime(time);

    $errors  = "Y";
    $year    = $year + 1900;
    $month   = $nums{$month+1} || $month+1;
    $day     = $nums{$day} || $day;
    $hours   = $nums{$hours} || $hours;
    $minutes = $nums{$minutes} || $minutes;
    $seconds = $nums{$seconds} || $seconds; 

    if(!(print ERR "$year-$month-$day $hours:$minutes:$seconds  $msg\n"))
    {
        print "$year-$month-$day $hours:$minutes:$seconds  Log file write failed [$errorFileName]\n";
        print "$year-$month-$day $hours:$minutes:$seconds  $!\n";
        print "\n";
        print "$year-$month-$day $hours:$minutes:$seconds  Count not write [$msg]\n";
        
        exit 10;
    }
}
#********************************************************************************************************************************************************************
# parseLogFile()
#********************************************************************************************************************************************************************
#
sub parseLogFile()
{
    
}
#********************************************************************************************************************************************************************
# Main Processing
#********************************************************************************************************************************************************************

#********************************************************************************************************************************************************************
# Print the execution information
#********************************************************************************************************************************************************************
printChronologicalMessage("$program $version");
printChronologicalMessage("Usage: $program [controlfile] parse[Y|N] move[Y|N]");
printChronologicalMessage("Parameters: Control File($parmFileName) Parse($parseFlag) Move($moveFlag)");
printChronologicalMessage(" ");

printChronologicalMessage("Processing started");
printChronologicalMessage("Opening Control File $parmFileName");

if(!(open(LOGS,"$parmFileName")))
{
    printChronologicalMessage(" ");
    printChronologicalMessage("Failed to open $parmFileName, process ending.");
    printChronologicalMessage("$!");
    printChronologicalMessage(" ");
    printChronologicalMessage("Process ended abnotmally. ");
    exit 10;
}

while(our $record = <LOGS>)
{
    #********************************************************************************************************************************************************************
    # Skip the comments in the control file
    #********************************************************************************************************************************************************************
    next unless substr($record, 0, 1) ne "#";
    #********************************************************************************************************************************************************************
    # Remove the line feed from the input record
    #********************************************************************************************************************************************************************
    chomp($record);
    #********************************************************************************************************************************************************************
    # Parse out the fields in the record for processing
    #********************************************************************************************************************************************************************
    our($key,$srcDirectory,$mask,$destDirectory,$logSubDirectory,$dateInFileNameFlag,$dateFormat,$dateBeginPosition,$dateLength,$warnFlag,$parseLogFlag) = split(",", $record);
    #********************************************************************************************************************************************************************
    # Reset the record counters
    #********************************************************************************************************************************************************************
    my $count = 0;
    my $moved = 0;
    
    printChronologicalMessage("Searching for pattern $mask in $srcDirectory");
    my $find = "$srcDirectory -type f -name \"$mask\"";
    printChronologicalMessage("\tCommand: $find");
    
    open(PS,"find $find |") || die "Failed: $!\n";
    while ( <PS> )
    {
        #********************************************************************************************************************************************************************
        # Skip the file is we have descended into the destination root directory
        #********************************************************************************************************************************************************************
        next if substr($_, 0, length($destDirectory)) eq $destDirectory;
        
        chomp($_);
        
        my @nodes = split(/[._]/, substr($_, 0, rindex($_, ".")));  # put the node of the date in the control file to make date processing easier
        
        $count++;
        #********************************************************************************************************************************************************************
        # Get the information about the file to be processes
        #********************************************************************************************************************************************************************
        my $file  = $_;
        my $b     = basename($file);
        my $c     = dirname($file);
    
        printChronologicalMessage("Processing file $c/$b");
        #********************************************************************************************************************************************************************
        # Check if a warning needs to be generated due to the existance of this file
        #********************************************************************************************************************************************************************
        if(defined $warnFlag)
        {
            if($warnFlag eq "Y")
            {
                
            }            
        }
        else
        {
            
        }
        #********************************************************************************************************************************************************************
        # If parsing is on and the log is to be parsed, invoke the parsing routine
        #********************************************************************************************************************************************************************
        if($parseFlag eq "Y" && $parseLogFlag eq "Y")
        {
            parseLogFile();
        }
        my $d1;

        if($dateInFileNameFlag eq "Y")
        {
            my $dateInFileName = substr($b, $dateBeginPosition, $dateLength);
            
            #Check if date is all numeric based on position of date in file name
            #
            if($dateFormat eq "YYYYMMDD")
            {
                $d1 = substr($b,$dateBeginPosition,4)."-".substr($b,$dateBeginPosition+4,2)."-".substr($b,$dateBeginPosition+6,2);
            }
            else
            {
                if($dateFormat eq "MMDDYYYY")
                {
                    $d1 = substr($b,$dateBeginPosition+4,4)."-".substr($b,$dateBeginPosition,2)."-".substr($b,$dateBeginPosition+2,2);
                }
            }
        }
        else
        {
            my $sb = stat("$c/$b");
            my(undef, $month, $day, $time, $year) = split(" ", scalar localtime $sb->mtime);
            
            my $m = $mon2num{lc $month};
            my $d = $nums{$day} || $day;
            
            $d1 = "$year-$m-$d";
            if(length($d1)==9)
            {
                $d1 = "$year-$m-0$day";
            }
        }

        my $logs = "$destDirectory/$d1";
        if($moveFlag eq "Y")
        {
            printChronologicalMessage("\tMoving File to $logs/$logSubDirectory ");
            
            if(!(-d $logs))
            {
                printChronologicalMessage("\tCreating log directory $logs ");
                if(!(mkdir $logs))
                {
                    printChronologicalMessage("\tUnable to create log directory [$logs], see information below.");
                    printChronologicalMessage("\t$!");
                    logErrorMessage("[$file] Unable to create log directory [$logs], see information below.");
                    logErrorMessage("$!");
                    next;
                }
            }
            
            $logs = "$logs/$logSubDirectory";
            if(!(-d $logs))
            {
                printChronologicalMessage("\tCreating log subdirectory $logs");
                if(!(mkdir $logs))
                {
                    printChronologicalMessage("\tUnable to create log directory [$logs], see information below.");
                    printChronologicalMessage("\t$!");
                    logErrorMessage("[$file] Unable to create log directory [$logs], see information below.");
                    logErrorMessage("$!");
                    next;
                }
            }
            
            my $move = system("mv $c/$b $logs/$b");
            if($move == 1)
            {
                printChronologicalMessage("\tFailed to move $file from $srcDirectory to $destDirectory, see information below.");
                printChronologicalMessage("\t$!");
                logErrorMessage("Failed to move $file from $srcDirectory to $destDirectory, see information below.");
                logErrorMessage("$?");
                next;
            }
            
            printChronologicalMessage("\tSuccessfully moved file to $logs");
            $moved++;
            
            printChronologicalMessage("\tCreating Symbolic Link to $logs/$b ");
            
            #my $unlink = system("find $c -links 1 -name \"$b\" -exec unlink {} \;");
            #if($link == 0)
            #{
            #    print "Link Creation failed!\n";
            #    printChronologicalMessage("\tFailed to create link to $logs/$b, see information below.");
            #    printChronologicalMessage("\t$!");
            #    logErrorMessage("Failed to create link to $logs/$b, see information below.");
            #    logErrorMessage("$?");
            #    next;
            #}
            
            my $link = system("ln -s $logs/$b $c/$b");
            if($link != 0)
            {
                print "Link Creation failed!\n";
                printChronologicalMessage("\tFailed to create link to $logs/$b, see information below.");
                printChronologicalMessage("\t$!");
                logErrorMessage("Failed to create link to $logs/$b, see information below.");
                logErrorMessage("$?");
                next;
            }
            printChronologicalMessage("\tSuccessfully created symbolic link to $logs/$b");
        }
        else
        {
            printChronologicalMessage("Move bypassed by argument[$destDirectory/$d1/$logSubDirectory]");
        }
    }
    printChronologicalMessage("Completed pattern $mask, $count files processed, $moved files moved.");
    printChronologicalMessage(" ");
}
printChronologicalMessage("Processing ended");
 
if(!(close LOGS))
{
    printChronologicalMessage("Failed to close gersLogManager control file [$parmFileName], see information below.");
    print "$!";
}

if(!(close ERR))
{
    printChronologicalMessage("Failed to close gersLogManager error file [$errorFileName], see information below.");
    print "$!";
}

if($errors eq "N")
{
    my($seconds, $minutes, $hours, $day, $month, $year, $wday, $yday, $isdst) =  localtime(time);

    $year    = $year + 1900;
    $month   = $nums{$month+1} || $month+1;
    $day     = $nums{$day} || $day;
    $hours   = $nums{$hours} || $hours;
    $minutes = $nums{$minutes} || $minutes;
    $seconds = $nums{$seconds} || $seconds; 

    print "$year-$month-$day $hours:$minutes:$seconds  Removing empty error file\n";
    
    my $result = system("rm -f $errorFileName");
    if($result == 1)
    {
        print "$year-$month-$day $hours:$minutes:$seconds  Could not remove empty error file\n";
        print "$year-$month-$day $hours:$minutes:$seconds  $?\n";
    }
}
if(!(close LOG))
{
    printChronologicalMessage("Failed to close gersLogManager log file [$prcssFileName], see information below.");
    print "$!";
}

exit 0;
