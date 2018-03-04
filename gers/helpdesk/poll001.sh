#!/bin/bash
###############################################################################
# Name: poll001.sh
#
# Description : This script creates a request tracker ticket for each store
#               and register that is in an error status in the POLLING_STATUS
#               table
#
# Changelog :   09/17/2013 (lputnel): initial version
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

export ORACLE_SID=genret
export ORACLE_HOME=/gers/genret
export PATH=$PATH:$ORACLE_HOME/bin
export LD_LIBRARY_PATH=$ORACLE_HOME/lib

# set the umask for all files created by the script
umask 0033

# script path
SCRIPT_PATH=/scripts/helpdesk
# tmp path
TMP_PATH=${SCRIPT_PATH}/tmp

# locations file
LOC_FILE=${SCRIPT_PATH}/locations.txt
# store file
STORE_FILE=${SCRIPT_PATH}/stores.txt

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

# determine yesterday
YESTERDAY=$(TZ=aaa24 date "+%F")

# result file
RESULTS_FILE=${TMP_PATH}/${SCRIPT_NAME}.results
# the query
ERROR_QUERY="SELECT P.STORE_CD, S.OP_DIST_CD, P.TERM_NUM FROM POLLING_STATUS P, STORE S WHERE S.STORE_CD = P.STORE_CD AND P.POLL_STAT_CD = 'ER' AND P.POLLING_DT = TO_DATE('${YESTERDAY}', 'YYYY-MM-DD');"

# delete the results file if it still exists from a previous execution
rm -f ${RESULTS_FILE}

RTN=$?

# verify the file was deleted
if [ ${RTN} -ne 0 ]; then
  logError "an exception occurred deleting previous ${RESULTS_FILE}, rc=${RTN}"
  exit 1
fi

log "Querying database for polling errors for ${YESTERDAY}"

# query oracle for store number, price zone and price group data
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
SET LINESIZE 15

CONNECT GERS/a1rp0rt

SPOOL ${RESULTS_FILE}
${ERROR_QUERY}
SPOOL OFF

EXIT;
EOF

RTN=$?

# if there was an error
if [ ${RTN} -ne 0 ]; then
  logError "an error occurred querying the database, rc=${RTN}"
  exit 2
fi

# if records were found
if [ -s ${RESULTS_FILE} ]; then
  log "${RESULTS_FILE} exists and is not empty"

  # set the internal field seperator to a newline
  IFS="
"

  # store, location and terminal values
  STR_NBR=
  LOC_NBR=
  TERM_NBR=
  TERM_IND=
  RESP_DATA=
  POST_FILE=${TMP_PATH}/${SCRIPT_NAME}.post
  SUBJECT=

  # iterate the query results
  for row in $(cat ${RESULTS_FILE}); do
    # parse query results into store number and terminal number
    STR_NBR=${row:0:5}
    LOC_NBR=${row:6:4}
    TERM_NBR=${row:11:3}

    # remove any trailing white spaces
    STR_NBR=${STR_NBR/ */}
    LOC_NBR=${LOC_NBR/ */}
    TERM_NBR=${TERM_NBR/ */}

    # convert the terminal number into a terminal Identifier
    TERM_IND=$(printf \\$(printf '%03o' $(expr 64 + ${TERM_NBR})))
    
    # create the subject line
    SUBJECT="[ST#${STR_NBR} ${TERM_IND}] Polling Required for ${YESTERDAY}"

    # now lookup the store and location data that request tracker expects
    STR_NBR=$(grep \^${STR_NBR}- ${STORE_FILE})
    LOC_NBR=$(grep \^${LOC_NBR}= ${LOC_FILE})

    # remove the equals from the LOC_NBR
    LOC_NBR=${LOC_NBR#*=}

    # create the post data file that will be padded in to create the ticket
    echo "user=RPolling&pass=pixie123&content=id: ticket/new
Queue: IT Service Center Level I
Requestor: ITServiceCenter@paradies-na.com
Subject: ${SUBJECT}
Owner: Nobody in particular
Status: open
Priority: High
CF-Ticket Source: Automation
CF-Windows User ID: N/A
CF-Contact Name: N/A
CF-Contact Email Address: ITServiceCenter@paradies-na.com
CF-Type of Location: Store
CF-Location Number: ${LOC_NBR}
CF-Store Number: ${STR_NBR}
CF-Register Number: ${TERM_IND}
CF-Problem Area: Register
CF-Application: Not Applicable
CF-Problem: Register Needs Polling
CF-Status: Received\nCF-Priority: High" > ${POST_FILE}

    log "creating ticket for location: [${LOC_NBR}] store: [${STR_NBR}] register: [${TERM_NBR}:${TERM_IND}]"

    # create the ticket
    RESP_DATA=$(wget -qO- --post-file=${POST_FILE} http://172.20.8.243/SupportCenter/REST/1.0/ticket/new)

    # log the response
    log "${RESP_DATA}"

    log "removing ${POST_FILE}"
    # cleanup the post file
    rm -f ${POST_FILE}
  done
fi # end if

log "cleaning up ${RESULTS_FILE}"
# lastly delete the results file
rm -f ${RESULTS_FILE}

log "finished: $(date)"

exit 0
