#!/usr/bin/perl
#********************************************************************************************************************************************************************
# gersBatchQueueMonitor.pl
#
# 
# 
#
# 
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
our $program = "gersBatchQueueMonitor.pl";
our $version = "1.0.0";

our %mon2num = qw(jan 01 feb 02 mar 03 apr 04 may 05 jun 06 jul 07 aug 08 sep 09 oct 10 nov 11 dec 12);
our %nums    = qw(0 00 1 01 2 02 3 03 4 04 5 05 6 06 7 07 8 08 9 09);

our $errors = "N";
our $warns  = "N";
our $minTimeStamp;
our $maxTimeStamp;

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

my $prcssFileName = "gersBatchQueueMonitor.$year-$month-$day.$hours$minutes$seconds.log";
my $errorFileName = "gersBatchQueueMonitor.$year-$month-$day.$hours$minutes$seconds.err";

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
our $inputDirectoryName       = $ARGV[0] || "/gers/genret/prgi";
our $outputDirectoryName      = $ARGV[1] || "/gers/genret/prgo";
our $alternateSearchDirectory = $ARGV[2] || "/gers/genret/logs";
our $warnDepth                =  $ARGV[1] || 100;
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
# 
#********************************************************************************************************************************************************************
#
sub determineOutputFileName
{
    my($filename) = @_;
    
    if(substr($filename,0,6) eq "DECODE")
    {
        open(DEC, "/gers/genret/prgi/$filename");
        my $store = <DEC>;
        chomp($store);
        close DEC;
        
        my $sb = stat("/gers/genret/prgi/$filename");
        my(undef, $month, $day, $time, $year) = split(" ", scalar localtime $sb->mtime);
            
        my $m = $mon2num{lc $month};
        my $d = $nums{$day} || $day;

        open(FIND, "find /gers/genret/prgo -name \"siu*$store*$year$m$d.log\" |") || die "Failed: $!\n";

        my $grep = <FIND>;
        chomp($grep);
        
        close GREP;
        
        $filename = "siu*$store*$year$m$d.log";
    }
    
    return $filename;
}
#********************************************************************************************************************************************************************
# parseLogFile()
#********************************************************************************************************************************************************************
#
sub execFindCommand
{
    my($command) = @_;
    my $return   = 0;
    
    open(GREP, "$command |") || die "Failed: $!\n";
    
    my $rec = <GREP>;
    
    if(defined $rec)
    {
        $return = 1;
    }
    
    close GREP;
    
    return $return;
}
#********************************************************************************************************************************************************************
# parseLogFile()
#********************************************************************************************************************************************************************
#
sub findCompletionFile
{
    my($dir, $fil, $str) = @_;
    my $grep;
    # Query the BQ tables using the file name and extension to determine if the job is currently in the queue
    #
    # If there is no row in the table, then interrogate the file system to determin the status of the process.
    #
    #********************************************************************************************************************************************************************
    # 
    #********************************************************************************************************************************************************************
    $fil = determineOutputFileName($fil);
    #********************************************************************************************************************************************************************
    # Completed, processes
    #********************************************************************************************************************************************************************
    $grep = "find $dir \\( -type f -o -links 1 \\) -name \"$fil\" -exec grep -i \"successful completion\" {} \\;";
    if(execFindCommand($grep) eq 1)
    {
        return "C";
    }
    #********************************************************************************************************************************************************************
    # Completed, reports
    #********************************************************************************************************************************************************************
    $grep = "find $dir \\( -type f -o -links 1 \\) -name \"$fil\" -exec grep -i \"no oracle database errors\" {} \\;";
    if(execFindCommand($grep) eq 1)
    {
        return "C";
    }
    #********************************************************************************************************************************************************************
    # Completed, FTP
    #********************************************************************************************************************************************************************
    $grep = "find $dir \\( -type f -o -links 1 \\) -name \"$fil\" -exec grep -i \"elapsed time\" {} \\;";
    if(execFindCommand($grep) eq 1)
    {
        return "C";
    }
    #********************************************************************************************************************************************************************
    # Completed, DECODE
    #********************************************************************************************************************************************************************
    $grep = "find $dir \\( -type f -o -links 1 \\) -name \"$fil\" -exec grep -i \"pos_trn_ln processing complete\" {} \\;";
    if(execFindCommand($grep) eq 1)
    {
        return "C";
    }
    
    $grep = "find $dir \\( -type f -o -links 1 \\) -name \"$fil\" -exec grep -i \"errors detected\" {} \\;";
    if(execFindCommand($grep) eq 1)
    {
        return "F";
    }
    # FTP Errors
    $grep = "find $dir \\( -type f -o -links 1 \\) -name \"$fil\" -exec grep -i \"system error\" {} \\;";
    if(execFindCommand($grep) eq 1)
    {
        return "F";
    }
    # FTP Errors
    $grep = "find $dir \\( -type f -o -links 1 \\) -name \"$fil\" -exec grep -i \"returned exit code\" {} \\;";
    if(execFindCommand($grep) eq 1)
    {
        return "F";
    }


    $grep = "find $dir -name \"$fil\" -exec wc -l {} \\;";
    if(execFindCommand($grep) eq 1)
    {
        return "I";
    }
    else
    {
        return "W";       
    }
}
#********************************************************************************************************************************************************************
# Main Processing
#********************************************************************************************************************************************************************

#********************************************************************************************************************************************************************
# Print the execution information
#********************************************************************************************************************************************************************
printChronologicalMessage("$program $version");
printChronologicalMessage("Usage: $program <queue input directory> <queue output directory> <alternate search directory> <warn depth>");
printChronologicalMessage("Parameters: Input($inputDirectoryName) Output($outputDirectoryName) Alternate($alternateSearchDirectory) Depth($warnDepth)");
printChronologicalMessage(" ");

my $completed = 0;
my $waiting = 0;
my $running = 0;
my $failed = 0;

my $prevRunningCount;
my $prevWaitingCount;
my $prevMinTimeStamp;
my $prevMinimum;
my $prevMaxTimeStamp;
my $prevMaximum;
my $prevRunTimeStamp;
my $prevRunTime;

if(!(open(OUT, "gersBatchQueueMonitor.cntl")))
{
    $prevRunningCount = 0;
    $prevWaitingCount = 0;
    $prevMinTimeStamp = 0;
    $prevMinimum = '0001-01-01';
    $prevMaxTimeStamp = 0;
    $prevMaximum = '0001-01-01';
    $prevRunTimeStamp = time;
    $prevRunTime = '0001-01-01 00:00:00';
}

my $x = <OUT>;
chomp($x);
($prevRunningCount, $prevWaitingCount, $prevMinTimeStamp, $prevMinimum, $prevMaxTimeStamp, $prevMaximum,$prevRunTimeStamp, $prevRunTime) = split(",", $x);
close OUT;

printChronologicalMessage("$prevRunningCount jobs running and $prevWaitingCount jobs waiting on last run");
printChronologicalMessage("Minimum Timestamp of $prevMinTimeStamp |$prevMinimum| found on last run");
printChronologicalMessage("Maximum Timestamp of $prevMaxTimeStamp |$prevMaximum| found on last run");
printChronologicalMessage("Last Run Time was $prevRunTimeStamp |$prevRunTime|");

open(QUE, "find $inputDirectoryName -type f -mtime +1 |") || die "Failed: $!\n";
while(our $record = <QUE>)
{
    chomp($record);

    my $base = basename($record);
    
    my $jobName   = substr($base, 0, index($base, "."));
    my $jobNumber = substr($base, index($base, ".")+1, length($base)-index($base, "."));
    
    chomp($base);
    
    my $status = findCompletionFile($outputDirectoryName, basename($record));
    
    if($status eq "C")
    {
        $completed++;
        next;
    }
    else
    {
        if($status eq "F")
        {
            printChronologicalMessage("Job $jobNumber($jobName), failed");
            $failed++;
            next;
        }
        else
        {
            if($status eq "I")
            {
                printChronologicalMessage("Job $jobNumber($jobName), is in process");
                $running++;    
            }
            else
            {
                printChronologicalMessage("Job $jobNumber($jobName), waiting to be processed");
                $waiting++;    
            }
        }
    }
    #********************************************************************************************************************************************************************
    # Remove the line feed from the input record
    #********************************************************************************************************************************************************************
    chomp($record);
    #********************************************************************************************************************************************************************
    # Get the information about the file to be processes
    #********************************************************************************************************************************************************************
    my $sb = stat($record);
    my(undef, $month, $day, $time, $year) = split(" ", scalar localtime $sb->mtime);

    if(defined $minTimeStamp)
    {
        if($sb->mtime < $minTimeStamp)
        {
            $minTimeStamp = $sb->mtime;
        }
    }
    else
    {
        $minTimeStamp = $sb->mtime;
    }
    
    if(defined $maxTimeStamp)
    {
        if($sb->mtime > $maxTimeStamp)
        {
            $maxTimeStamp = $sb->mtime;
        }
    }
    else
    {
        $maxTimeStamp = $sb->mtime;
    }
}

($seconds, $minutes, $hours, $day, $month, $year, $wday, $yday, $isdst) =  localtime($minTimeStamp);

$year    = $year + 1900;
$month   = $nums{$month+1} || $month+1;
$day     = $nums{$day} || $day;
$hours   = $nums{$hours} || $hours;
$minutes = $nums{$minutes} || $minutes;
$seconds = $nums{$seconds} || $seconds;
my $min  = "$year-$month-$day $hours:$minutes:$seconds";

($seconds, $minutes, $hours, $day, $month, $year, $wday, $yday, $isdst) =  localtime($maxTimeStamp);

$year    = $year + 1900;
$month   = $nums{$month+1} || $month+1;
$day     = $nums{$day} || $day;
$hours   = $nums{$hours} || $hours;
$minutes = $nums{$minutes} || $minutes;
$seconds = $nums{$seconds} || $seconds;
my $max     = "$year-$month-$day $hours:$minutes:$seconds";


my $runTimeStamp = time;
($seconds, $minutes, $hours, $day, $month, $year, $wday, $yday, $isdst) = localtime($runTimeStamp);

$year    = $year + 1900;
$month   = $nums{$month+1} || $month+1;
$day     = $nums{$day} || $day;
$hours   = $nums{$hours} || $hours;
$minutes = $nums{$minutes} || $minutes;
$seconds = $nums{$seconds} || $seconds;
my $run     = "$year-$month-$day $hours:$minutes:$seconds";

printChronologicalMessage($running." jobs running, $waiting jobs waiting to be processed, $failed errors reported");
printChronologicalMessage("Minimum Timestamp is $minTimeStamp |$min|");
printChronologicalMessage("Maximum Timestamp is $maxTimeStamp |$max|");
printChronologicalMessage("Last Run Time was $runTimeStamp |$run|");
printChronologicalMessage("Processing ended");

open(OUT, ">gersBatchQueueMonitor.cntl");
print OUT "$running,$waiting,$minTimeStamp,$min,$maxTimeStamp,$max,$runTimeStamp,$run\n";
close OUT;
 
if(!(close QUE))
{
    #printChronologicalMessage("Failed to close gersLogManager control file [$parmFileName], see information below.");
    print "Error closing system find command\n";
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
