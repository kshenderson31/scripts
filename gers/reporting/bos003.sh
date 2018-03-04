#!/bin/bash
###############################################################################
# Name: bos003.sh
#
# Description : Script invoked my CRON that generates the MTD balance of sales
#               (bos) report for each district setup in GERS. It then
#               saves these files in compressed form so they can be uploaded
#               to the enterprise portal (accesstps or other)
#
# Changelog :   10/16/2013 (lputnel): initial revision
###############################################################################

###
# Create a log entry with the PID as a reference
#
# @param message : the message to log
###
log()
{
  echo -e "($$) $1"
} # end log()

###
# Create an error entry in the log
#
# @param message : the error message
###
logError()
{
  log "** ERROR: $1"
} # end logError()

###
# MAIN
###

# capture the script name without the extension
SCRIPT_NAME=$(basename $0 .sh)

# export the variables that make sqlplus work
export ORACLE_SID=genret
export ORACLE_HOME=/gers/genret
export PATH=$PATH:$ORACLE_HOME/bin
export LD_LIBRARY_PATH=$ORACLE_HOME/lib

# set the umask for all files created by the script
umask 0033

# script path
SCRIPT_PATH=/scripts/reporting
# tmp path
TMP_PATH=${SCRIPT_PATH}/tmp

# setup the log
LOG=${SCRIPT_PATH}/logs/${SCRIPT_NAME}.log

# if the log file already exists
if [ -f ${LOG} ]; then
  # get the maximum number of bytes the log file can be (default to 512K)
  MAX_LOG_BYTES=${MAX_LOG_BYTES:-524288}

  # name of the backup log file
  BACKUP=${LOG}.bu

  # get the size of the log file
  typeset -i BYTES=$(/bin/ls -l ${LOG} | awk '{print $5}')

  # if the current size of the log file exceeds the maximum size
  if [ ${BYTES} -gt ${MAX_LOG_BYTES} ]; then
    # delete the backup file if it already exists
    rm -f ${BACKUP}
    # move the current log file to the backup
    mv ${LOG} ${BACKUP}
    # re-create the log file
    touch ${LOG}
  fi
fi

# redirect stderr and stdout to the log file
exec 1>>$LOG 2>>$LOG

# log a started message
echo ""
log "started: $(date)"

# result file
RESULTS_FILE=${TMP_PATH}/${SCRIPT_NAME}.results

# delete the results file if it still exists from a previous execution
rm -f ${RESULTS_FILE}

RTN=$?

# verify the file was deleted
if [ ${RTN} -ne 0 ]; then
  logError "an exception occurred deleting previous ${RESULTS_FILE}, rc=${RTN}"
  exit 1
fi

log "Querying the database to see if this is the first Monday of the fiscal period"

# query the database to see if today is the first Monday of the fiscal period
sqlplus -s /nolog >> /dev/null <<-EOF

WHENEVER OSERROR EXIT 2
WHENEVER SQLERROR EXIT SQL.SQLCODE

SET ECHO OFF
SET FEEDBACK OFF
SET TAB OFF
SET HEAD OFF
SET PAGESIZE 3000
SET NEWPAGE NONE
SET COLSEP ','
SET LINESIZE 20

CONNECT GERS/a1rp0rt

SPOOL ${RESULTS_FILE}
SELECT COUNT(*) FROM SLS_PER WHERE TO_CHAR(BEG_DT, 'YYYY-MM-DD') = TO_CHAR((SYSDATE - 1), 'YYYY-MM-DD');
SPOOL OFF

EXIT;
EOF

RTN=$?

# if there was an error
if [ ${RTN} -ne 0 ]; then
  logError "an error occurred querying the database, rc=${RTN}"
  exit 2
fi

# if this is not the first Monday of the month
if [ $(cat ${RESULTS_FILE} | tr -d ' ') -eq 0 ]; then
  log "This is not the first Monday of the fiscal period, exiting"
  exit 0
fi

log "This is the first Monday of the fiscal period, getting all districts"

# Base URL used to generate reports and get locations
BASE_URL=http://10.0.0.3

# invoke the web service call to get the districts
wget -q -O ${RESULTS_FILE} ${BASE_URL}/BosReport/services/locationService/districts?version=2

RTN=$?

# if there was an error
if [ ${RTN} -ne 0 ]; then
  logError "an error occurred getting the districts, rc=${RTN}"
  exit 2
fi

# if records were found
if [ -s ${RESULTS_FILE} ]; then
  log "${RESULTS_FILE} exists and is not empty"

  DIST_NBR=
  BOS_RPT_PATH=
 
  # iterate the results file
  for row in $(grep code ${RESULTS_FILE}); do
    # remove the code open tag 
    DIST_NBR=${row##'<code>'}
    # remove the code close tag
    DIST_NBR=${DIST_NBR%%'</code>'}
  
    BOS_RPT_PATH=${TMP_PATH}/MTDDistBos${DIST_NBR}.pdf

    log "persisting MTD BOS report for district ${DIST_NBR} to ${BOS_RPT_PATH}"
    # generate the bos report and write it to tmp
    wget -q -O ${BOS_RPT_PATH} ${BASE_URL}/BosReport/services/reportService/bos/district/${DIST_NBR}

    RTN=$?

    if [ ${RTN} -ne 0 ]; then
      logError "An error occurred generating MTD District BOS report for ${DIST_NBR}, RC=${RTN}"
      # delete the BosReport for the store that filed (it should be a 0 byte file)
      log "removing ${BOS_RPT_PATH}"
      rm -f ${BOS_RPT_PATH}
    fi
  done

  # next zip all the PDF files we generated
  ZIPFILE_NAME=MTDDistBosReports_$(date +%m%d%Y_%H%M%S).zip
  ZIPFILE_PATH="${TMP_PATH}/${ZIPFILE_NAME}"
  log "Creating ${ZIPFILE_PATH}"
#  jar -cMf ${ZIPFILE_PATH} ${TMP_PATH}/MTDDistBos*.pdf
  /prod/jre_1.4.2/bin/jar -cMf ${ZIPFILE_PATH} ${TMP_PATH}/MTDDistBos*.pdf

  RTN=$?

  # make sure the file was written
  if [ ${RTN} -ne 0 ]; then
    logError "An error occurred creating ${ZIPFILE_PATH}, RC=${RTN}"
    exit 3
  fi

  # this needs to be a distribution list! 
  EMAIL_RECIPIENTS=IT.BOSS.Distribution@THEPARADIESSHOPS.COM
  
  # send an email notification with the generated file as an attachment 
  log "sending attachment email to ${EMAIL_RECIPIENTS}"
  (echo "Attached are the generated month to date balance of sales reports for all districts"; /usr/bin/uuencode ${ZIPFILE_PATH} ${ZIPFILE_NAME}) | mailx -r no-reply@theparadiesshops.com -s "Month to Date Balance of Sales Reports for all Districts" ${EMAIL_RECIPIENTS}
  
  RTN=$?
  
  if [ ${RTN} -eq 0 ]; then
    log "successfully sent email to ${EMAIL_RECIPIENTS}"
  fi

  # lastly remove the generated PDF files 
  log "Cleaning up MTD District Bos pdf files"
  rm ${TMP_PATH}/MTDDistBos*.pdf
fi # end if

log "cleaning up ${RESULTS_FILE}"
# lastly delete the results file
rm -f ${RESULTS_FILE}

log "finished $(date)"

exit 0
