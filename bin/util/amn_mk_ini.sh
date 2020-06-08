#!/bin/bash

########################################################################
# Bash script                                            Quentin Petit #
# May 2020                                 <qpe-y9d37y@protonmail.com> #
#                                                                      #
#                             amn_mk_ini.sh                            #
#                                                                      #
# Current version: 0.1                                                 #
# Status: Work in progress                                             #
#                                                                      #
# This script purpose it to create an INI file from the data retrieved #
# by the OS scripts.
#                                                                      #
# Version history:                                                     #
# +----------+------------+------+-----------------------------------+ #
# |   Date   |   Author   | Vers | Comment                           | #
# +==========+============+======+===================================+ #
# | 20200522 | Quentin P. | 0.1  | Starting development              | #
# +----------+------------+------+-----------------------------------+ #
#                                                                      #
########################################################################

#                                                                      #
#                               VARIABLES                              #
#                                                                      #

# Files and directories.
DIR_TMP="/tmp/audimina"
FIL_OUT_INI="${DIR_TMP}/amn_$(hostname -s)-$(date +%s).ini"

#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~#
#                                                                      #
#                               FUNCTIONS                              #
#                                                                      #

# Function to transform variables
function tr_var {
  VAR=("$@")
  case $(echo ${#VAR[*]}) in
    0)
      echo "null"
    ;;
    1)
      echo "${VAR[0]}"
    ;;
    *)
      echo -n "["
      for INDEX in $(echo ${!VAR[*]}); do
        echo -n "\"${VAR[${INDEX}]}\","
      done | sed 's/,$/]/'
    ;;
  esac
}

#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~#
#                                                                      #
#                               BEGINNING                              #
#                                                                      #

cat << EOM > ${FIL_OUT_INI}
[identification]
hostname = $(tr_var "${SRVNAME[@]}")
domain = $(tr_var "${DOMAIN[@]}")

[operating-system]
os = $(tr_var "${OS[@]}")
distribution_name = $(tr_var "${DISTRIB_NAME[@]}")
distribution_release = $(tr_var "${DISTRIB_RELEASE[@]}")
kernel_release = $(tr_var "${KERNEL_VERS[@]}")

[hardware]
memory = $(tr_var "${MEM_SIZE[@]}")
swap = $(tr_var "${SWAP_SIZE[@]}")
cpu = $(tr_var "${CPU_COUNT[@]}")
architecture = $(tr_var "${ARCH[@]}")
product_name = $(tr_var "${PRODUCT_NAME[@]}")
server_type = $(tr_var "${TYPE[@]}")
serial_number = $(tr_var "${SN[@]}")
manufacturer = $(tr_var "${MANUFACTURER[@]}")

[boot]
default_target = $(tr_var "${DEF_TARGET[@]}")

[networking]
interface_count = $(tr_var "${NET_IF_COUNT[@]}")
main_ip_addr = $(tr_var "${NET_IP_MAIN[@]}")
interface_lst = $(tr_var "${NET_LIST[@]}")

[users-groups]
local_users = $(tr_var "${USR_LOCAL[@]}")
local_groups = $(tr_var "${GRP_LOCAL[@]}")

[ssh-keys]
known_hosts = $(tr_var "${KNOWN_HOSTS_FILES[@]}")
authorized_keys = $(tr_var "${AUTH_KEYS_FILES[@]}")
ssh_fingerprints = $(tr_var "${SSH_FIU[@]}")

[storage]
filesystems = $(tr_var "${FILESYSTEMS[@]}")
disks = $(tr_var "${DISKS[@]}")
partitions = $(tr_var "${PARTS[@]}")
physical_volumes = $(tr_var "${PVS[@]}")
volume_groups = $(tr_var "${VGS[@]}")
logical_volumes = $(tr_var "${LVS[@]}")
exported_filesystems = $(tr_var "${NFS_SHARED[@]}")
mounted_nfs = $(tr_var "${NFS_MOUNTED[@]}")

[package-management]
packages_installed = $(tr_var "${PKG_LST[@]}")
groups_installed = $(tr_var "${PKG_GRPS[@]}")
repositories = $(tr_var "${REPO_LST[@]}")

[services]
services_running = $(tr_var "${SVC_RUNNING[@]}")
services_enabled = $(tr_var "${SVC_ENABLED[@]}")
ports_listening = $(tr_var "${LSTN_PORTS[@]}")

[security]
firewall_status = $(tr_var "${FW_STATUS[@]}")
firewall_rules = $(tr_var "${FW_RULES[@]}")
selinux_status = $(tr_var "${SELINUX_STATUS[@]}")

[scheduled-jobs]
cron_users = $(tr_var "${CRON_USR[@]}")
cron_deny = $(tr_var "${CRON_DENY[@]}")
cron_allow = $(tr_var "${CRON_ALLW[@]}")
cron_file = $(tr_var "${CRON_FIL[@]}")
cron_dir = $(tr_var "${CRON_DIR[@]}")
cron_hourly = $(tr_var "${CRON_HR[@]}")
cron_daily = $(tr_var "${CRON_DAY[@]}")
cron_weekly = $(tr_var "${CRON_WEEK[@]}")
cron_monthly = $(tr_var "${CRON_MTH[@]}")

[divers]
motd = $(tr_var "${MOTD[@]}")
EOM

#                                                                      #
#                                 END                                  #
#                                                                      #
#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~#