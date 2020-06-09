#!/bin/bash

########################################################################
# MIT License                             Copyright 2020 Quentin Petit #
# May 2020                                 <qpe-y9d37y@protonmail.com> #
#                                                                      #
#                              audimina.sh                             #
#                                                                      #
# Current version: 2.0                                                 #
# Status: Work in progress                                             #
#                                                                      #
# This script purpose it to audit Linux/UNIX servers.                  #
#                                                                      #
# Version history:                                                     #
# +----------+------------+------+-----------------------------------+ #
# |   Date   |   Author   | Vers | Comment                           | #
# +==========+============+======+===================================+ #
# | 20131010 | Quentin M. | 1.0  | First version                     | #
# | 20140102 | Quentin M. | 1.3  | Bugfix                            | #
# | 20200511 | Quentin P. | 2.0  | Split audimina per OS/distrib     | #
# +----------+------------+------+-----------------------------------+ #
#                                                                      #
########################################################################

#                                                                      #
#                               VARIABLES                              #
#                                                                      #

# Files and directories.
DIR_AMN=$(cd $(dirname ${0}) && pwd -P | awk -F'/' 'BEGIN{OFS=FS};NF{NF-=1};1')
DIR_BIN="${DIR_AMN}/bin"
DIR_INI="${DIR_AMN}/ini"
DIR_TMP="/tmp/audimina"
DIR_OUT="${DIR_AMN}/out"
DIR_LOG="${DIR_AMN}/log"
FIL_LOG="${DIR_LOG}/$(basename ${0} | sed 's/.sh/.log/')"
SCR_MK_INI="${DIR_BIN}/util/amn_mk_ini.sh"

# Default variables.
DEF_IFS=${IFS}

#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~#
#                                                                      #
#                               FUNCTIONS                              #
#                                                                      #

# Function to select the correct script to use.
function file_select {
  OS=$1
  DISTRIB=$2

  case ${OS} in
    Linux)
      AMN_SCRIPT="${DIR_BIN}/os/amn_lx_${DISTRIB}.sh"
      FIL_INI_PKG="${DIR_INI}/pkg_lx_${DISTRIB}.txt"
      FIL_INI_CRON="${DIR_INI}/crn_lx_${DISTRIB}.txt"
    ;;
    AIX)
      echo -e "[\e[91merror\e[0m] ${OS} is not yet supported, bye." > /dev/tty
      exit 1
#      AMN_SCRIPT="${DIR_BIN}/os/amn_ux_aix.ksh"
#      FIL_INI_PKG=""
#      FIL_INI_CRON=""
    ;;
    *)
      echo -e "[\e[91merror\e[0m] ${OS} is not supported, bye." > /dev/tty
      usage && exit 1
    ;;
  esac
}

# Function to print the usage.
function usage {
  echo "usage: $(basename $0) [-h] [--remote=SERVER] [--user=USER] [--file=FILE]

Create a local mirror of Ubuntu installation media repository

arguments:
  -h, --help      show this help message and exit
  --remote=SERVER remote server to audit (default is localhost)
  --user=USER     user to use to connect to remote server
  --file=FILE     file containing list of servers to audit" > /dev/tty
}

#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~#
#                                                                      #
#                               BEGINNING                              #
#                                                                      #

# Start logging.
if [[ ! -d ${DIR_LOG} ]]; then
  mkdir ${DIR_LOG}
fi
date > ${FIL_LOG}
exec 2>> ${FIL_LOG} 1>> ${FIL_LOG}
set -x
echo -e "[\e[92minfo\e[0m] log file:               ${FIL_LOG}" > /dev/tty

# Check arguments.
for ARG in $@; do
  if [[ ${ARG} == "--help" ]] || [[ ${ARG} == "-h" ]]; then
    usage && exit 0
  elif [[ ${ARG} == --remote=* ]]; then
    REMOTE=true
    REMOTE_SRV=$(echo ${ARG} | awk -F'=' '{print $2}')
  elif [[ ${ARG} == --user=* ]]; then
    REMOTE_USR=$(echo ${ARG} | awk -F'=' '{print $2}')
  elif [[ ${ARG} == --file=* ]]; then
    REMOTE=true
    REMOTE_FIL=$(echo ${ARG} | awk -F'=' '{print $2}')
  else
    echo -e "[\e[91merror\e[0m] argument ${ARG} unknown."
    usage && exit 1
  fi
done

# Create temporary directory.
mkdir -p ${DIR_TMP}

# Localhost targets.
if [[ -z ${REMOTE} ]]; then

  # Make sure script is launched as root.
  if [[ $(whoami) != "root" ]]; then
    echo -e "[\e[91merror\e[0m] this script must be run as root." > /dev/tty
    usage && exit 1
  fi

  # Retrieve OS.
  OS=$(uname)

  # If Linux retrieve distribution.
  if [[ ${OS} == "Linux" ]]; then
    
    # Enterprise Linux.
    if [[ $(uname -r | grep el) ]]; then
      DISTRIB=$(uname -r | grep -o el.)
    else
      echo -e "[\e[91merror\e[0m] $(hostname) is not running a supported distribution, bye." > /dev/tty
      usage && exit 1
    fi

  else
    DISTRIB=false
  fi

  # Select the correct files to use.
  file_select ${OS} ${DISTRIB}

  # Copy files to DIR_TMP.
  cp ${AMN_SCRIPT} ${FIL_INI_PKG} ${FIL_INI_CRON} ${SCR_MK_INI} ${DIR_TMP}/

  # Launch script.
  case ${OS} in
    Linux) bash ${AMN_SCRIPT} ;;
    AIX) ksh ${AMN_SCRIPT} ;;
  esac

else

  # Set current user as REMOTE_USR if unset.
  if [[ -z ${REMOTE_FIL} ]] && [[ -z ${REMOTE_USR} ]]; then
    REMOTE_USR=$(whoami)
  fi

  # If no REMOTE_FIL provided, create one.
  if [[ -z ${REMOTE_FIL} ]]; then
    REMOTE_FIL="${DIR_TMP}/remote_file"
    echo "${REMOTE_SRV};${REMOTE_USR}" > ${REMOTE_FIL} 
  fi

  # Make sure that REMOTE_FIL exists and is readable.
  if [[ ! -r ${REMOTE_FIL} ]]; then
    echo -e "[\e[91merror\e[0m] file ${REMOTE_FIL} doesn't exist or isn't readable." > /dev/tty
    usage && exit 1
  fi

  # Set IFS to newline.
  IFS=$'\n'

  # Start loop for each server in REMOTE_FIL.
  for LINE in $(cat ${REMOTE_FIL}); do

    # Set REMOTE_SRV and REMOTE_USR.
    REMOTE_SRV=$(echo ${LINE} | awk -F';' '{print $1}')
    REMOTE_USR=$(echo ${LINE} | awk -F';' '{print $2}')

    # Check that server is reachable.
    if $(ssh -o StrictHostKeyChecking=no -o ConnectTimeout=3 -o BatchMode=yes -l ${REMOTE_USR} ${REMOTE_SRV} "exit"); then
      echo -e "[\e[92minfo\e[0m] \e[1mstarting audit of ${REMOTE_SRV}\e[0m" > /dev/tty
    else
      echo -e "[\e[91merror\e[0m] ${REMOTE_SRV} is not reachable, bye." > /dev/tty
      usage && exit 1
    fi

    # Retrieve OS of REMOTE_SRV.
    REMOTE_OS=$(ssh -o StrictHostKeyChecking=no -o ConnectTimeout=3 -o BatchMode=yes -l ${REMOTE_USR} ${REMOTE_SRV} "uname")

    # If Linux retrieve distribution.
    if [[ ${REMOTE_OS} == "Linux" ]]; then
      
      # Enterprise Linux.
      if [[ $(ssh -o StrictHostKeyChecking=no -o ConnectTimeout=3 -o BatchMode=yes -l ${REMOTE_USR} ${REMOTE_SRV} "uname -r | grep el") ]]; then
        REMOTE_DISTRIB=$(ssh -o StrictHostKeyChecking=no -o ConnectTimeout=3 -o BatchMode=yes -l ${REMOTE_USR} ${REMOTE_SRV} "uname -r | grep -o el.")
      else
        echo -e "[\e[91merror\e[0m] ${REMOTE_SRV} is not running a supported distribution, bye." > /dev/tty
        usage && exit 1
      fi

    elif [[ ${REMOTE_OS} == "AIX" ]]; then

      REMOTE_DISTRIB=false

      # If OS is AIX, check if VIOS.
      if $(ssh -o StrictHostKeyChecking=no -o ConnectTimeout=3 -o BatchMode=yes -l ${REMOTE_USR} ${REMOTE_SRV} "ls /usr/ios/cli/ioscli") ]]; then
        REMOTE_OS="VIOS"
      fi

    else
      REMOTE_DISTRIB=false
    fi

    # Select the correct files to use.
    file_select ${REMOTE_OS} ${REMOTE_DISTRIB}

    # Create DIR_TMP on REMOTE_SRV.
    ssh -o StrictHostKeyChecking=no -o ConnectTimeout=3 -o BatchMode=yes -tt -l ${REMOTE_USR} ${REMOTE_SRV} \
      "sudo mkdir -p ${DIR_TMP}/files"

    # Set REMOTE_USR as owner of DIR_TMP
    ssh -o StrictHostKeyChecking=no -o ConnectTimeout=3 -o BatchMode=yes -tt -l ${REMOTE_USR} ${REMOTE_SRV} \
      "sudo chown -R ${REMOTE_USR} ${DIR_TMP}"

    # Send files to REMOTE_SRV.
    for FILE in ${AMN_SCRIPT} ${FIL_INI_PKG} ${FIL_INI_CRON} ${SCR_MK_INI}; do
      scp -o StrictHostKeyChecking=no -o ConnectTimeout=3 -o BatchMode=yes ${FILE} ${REMOTE_USR}@${REMOTE_SRV}:${DIR_TMP}/
    done

    # Set correct mode.
    ssh -o StrictHostKeyChecking=no -o ConnectTimeout=3 -o BatchMode=yes -tt -l ${REMOTE_USR} ${REMOTE_SRV} \
      "sudo chmod 755 ${DIR_TMP}/$(basename ${AMN_SCRIPT})"

    # Launch script.
    ssh -o StrictHostKeyChecking=no -o ConnectTimeout=3 -o BatchMode=yes -tt -l ${REMOTE_USR} ${REMOTE_SRV} \
      "sudo ${DIR_TMP}/$(basename ${AMN_SCRIPT})"

    # Set REMOTE_USR as owner of all files under DIR_TMP
    ssh -o StrictHostKeyChecking=no -o ConnectTimeout=3 -o BatchMode=yes -tt -l ${REMOTE_USR} ${REMOTE_SRV} \
      "sudo chown -R ${REMOTE_USR} ${DIR_TMP}"

    # Get output files.
    mkdir -p ${DIR_OUT}/${REMOTE_SRV}/
    scp -o StrictHostKeyChecking=no -o ConnectTimeout=3 -o BatchMode=yes ${REMOTE_USR}@${REMOTE_SRV}:${DIR_TMP}/amn_*.ini ${DIR_OUT}/
    scp -o StrictHostKeyChecking=no -o ConnectTimeout=3 -o BatchMode=yes ${REMOTE_USR}@${REMOTE_SRV}:${DIR_TMP}/files/* ${DIR_OUT}/${REMOTE_SRV}/

    # Retrieve name of INI file.
    INI_FILE=$(ssh -o StrictHostKeyChecking=no -o ConnectTimeout=3 -o BatchMode=yes -tt -l ${REMOTE_USR} ${REMOTE_SRV} "ls ${DIR_TMP}/amn_*.ini")

    # Print output files location.
    echo -e "[\e[92minfo\e[0m] generated INI file:     ${DIR_OUT}/$(basename ${INI_FILE})" > /dev/tty
    echo -e "[\e[92minfo\e[0m] retrieved config files: ${DIR_OUT}/${REMOTE_SRV}/" > /dev/tty

    # Cleanup all audimina files on REMOTE_SRV.
    ssh -o StrictHostKeyChecking=no -o ConnectTimeout=3 -o BatchMode=yes -tt -l ${REMOTE_USR} ${REMOTE_SRV} \
      "sudo rm -r ${DIR_TMP}"

  done

fi

# Cleanup DIR_TMP.
rm -r ${DIR_TMP}

#                                                                      #
#                                 END                                  #
#                                                                      #
#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~#
