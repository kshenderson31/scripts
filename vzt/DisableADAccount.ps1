#--------------------------------------------------------------------------------------------------------------------------------------
# This script will attempt to lock accounts provided by a comma-delimited file located in the file C:\accounts.txt
#
# The file should contain the account Full Name, Lastname, Firstname with the first row being a hader row as seen by the example
# below
#
# Fullname,Lastname,Firstname
# Ken Henderson,Henderson,Ken
#--------------------------------------------------------------------------------------------------------------------------------------
#

Write-Host "==============================================================================="
Write-Host "Account Disable Process Started"
Write-Host "==============================================================================="
Write-Host " "

$ok=0
$no=0

#--------------------------------------------------------------------------------------------------------------------------------------
# Import the CSV file for processing
#--------------------------------------------------------------------------------------------------------------------------------------
#
Try
{
    $File = Import-Csv -Path "c:\accounts.txt"
}
Catch
{
    Write-Host "Could not open account file, see information below"
    Write-Host "Caught an exception:" -ForegroundColor Red
    Write-Host "Exception Type: $($_.Exception.GetType().FullName)" -ForegroundColor Red
    Write-Host "Exception Message: $($_.Exception.Message)" -ForegroundColor Red      
    Exit 
}

Foreach ($d in $file)
{
    $full=$d.Fullname.Trim()
    
    If($d.Fullname.Substring(0,1) -eq "#")
    {
        Continue
    }
    
    Write-Host "Disabling ${full}"
    
    Try
    {
        #--------------------------------------------------------------------------------------------------------------------------------------
        # Get the AD account for the user
        #--------------------------------------------------------------------------------------------------------------------------------------
        #
        $user = Get-ADuser -Filter {Name -eq $d.Fullname} -Properties *
        
        Try
        {
            #--------------------------------------------------------------------------------------------------------------------------------------
            # Set the selected account to disabled
            #--------------------------------------------------------------------------------------------------------------------------------------
            #
            Set-ADUser -Identity $user.sAMAccountName -Enabled $False -Description "Account disabled for Verizon migration"
            
            Write-Host "User ${user} [${full}] has been disabled"
            $ok++
        }
        Catch
        {
            Write-Host "${full} was not disabled, see exception information below"
            Write-Host "Exception Encountered:" -ForegroundColor Red
            Write-Host "Exception Type: $($_.Exception.GetType().FullName)" -ForegroundColor Red
            Write-Host "Exception Message: $($_.Exception.Message)" -ForegroundColor Red       
            $no++
        }
    }
    Catch
    {
        Write-Host "${full} was not disabled, see exception information below"
        Write-Host "Exception Encountered:" -ForegroundColor Red
        Write-Host "Exception Type: $($_.Exception.GetType().FullName)" -ForegroundColor Red
        Write-Host "Exception Message: $($_.Exception.Message)" -ForegroundColor Red       
        $no++
    }
    Write-Host " "
}

Write-Host "==============================================================================="
Write-Host "Done; ${ok} accounts disabled, ${no} failures"
Write-Host "==============================================================================="
Write-Host "Account Disable Process Ended"
Write-Host " "
