#!/bin/bash

printmessage() {
  local now=`date +%Y-%m-%d\ %H:%M:%S.$(( $(date +%-N) / 1000000 ))`
  local message="$now $*"
  echo -e ${message} | tee -a ${repl_log_file}
}

trap_log_int() {

  printmessage "Ctrl-C attempted. Aborting!"
 
  # Removing lock file upon completion of run
  # A second script checking the lock and exiting should not remove the lock
  # of the first instance which is running. Henc adding a pid check
  if [[$(cat ${RUN_DIR}/${script_name}.lock) == $$]]; then
    rm ${RUN_DIR}/${script_name}.lock 
  fi

}

trap_log_exit() {

  # Removing unnecessary warnings from SLF4J library, 
  sed -i '/^SLF4J:/d' ${repl_log_file}
  
  # Removing some empty lines generated by beeline
  sed -i '/^$/d' ${repl_log_file}
  
  # Removing lock file upon completion of run
  # A second script checking the lock and exiting should not remove the lock
  # of the first instance which is running. Henc adding a pid check
  if [[$(cat ${RUN_DIR}/${script_name}.lock) == $$]]; then
    rm ${RUN_DIR}/${script_name}.lock 
  fi
  
  printmessage "Uploading replication log to HDFS Upload directory."
  hdfs dfs -put ${repl_log_file} ${hdfs_upload_dir}
  local retval=$?
  
  if [[ ${retval} -eq 0 ]]; then
    echo "Uploaded replication log to HDFS Upload directory."
  else
    echo "Replication log upload to HDFS Upload directory failed."
  fi

}

check_prev_instance_running() {

## If the lock file exists
if [ -e ${RUN_DIR}/${script_name}.lock ]; then

    ## Check if the PID in the lockfile is a running instance
    ## of ${script_name} to guard against failed runs
    if ps $(cat ${RUN_DIR}/${script_name}.lock ) | grep ${script_name} >/dev/null; then
        printmessage "Script ${script_name} is already running, exiting"
        exit 1
    else
        printmessage "Lockfile  ${RUN_DIR}/${script_name}.lock contains a stale PID."
        printmessage "A previous replication run may still be running. Please confirm"
        printmessage "there's no replication run in progress and remove the lock file to continue."
        exit 1
    fi
fi
## Create the lockfile by printing the script's PID into it
echo $$ > ${RUN_DIR}/${script_name}.lock 

}

script_usage() {
  echo -e "Usage : ${BASENAME} <database-name> \n"
  echo -e "**  It is recommended to run this script at the target cluster, but it should work in either cluster.\n" 
  echo -e "**  The database name is a required argument and is validated against the dblist variable in env.sh. \n"
}