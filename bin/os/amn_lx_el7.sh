#!/bin/bash

########################################################################
# MIT License                             Copyright 2020 Quentin Petit #
# May 2020                                 <qpe-y9d37y@protonmail.com> #
#                                                                      #
#                             amn_lx_el7.sh                            #
#                                                                      #
# Current version: 0.1                                                 #
# Status: Work in progress                                             #
#                                                                      #
# This script purpose it to audit an Enterprise Linux 7 server.        #
#                                                                      #
# Version history:                                                     #
# +----------+------------+------+-----------------------------------+ #
# |   Date   |   Author   | Vers | Comment                           | #
# +==========+============+======+===================================+ #
# | 20200512 | Quentin P. | 0.1  | Starting development              | #
# +----------+------------+------+-----------------------------------+ #
#                                                                      #
########################################################################

#                                                                      #
#                               VARIABLES                              #
#                                                                      #

# Files and directories.
DIR_TMP="/tmp/audimina"
DIR_TMP_FIL="${DIR_TMP}/files"
FIL_INI_PKG="${DIR_TMP}/pkg_lx_el7.txt"
FIL_INI_CRON="${DIR_TMP}/crn_lx_el7.txt"
SCR_MK_INI="${DIR_TMP}/amn_mk_ini.sh"

# Default parameters
DEF_SYS_USR="root|bin|daemon|adm|lp|sync|shutdown|halt|mail|operator|games|ftp|nobody|systemd-network|dbus|polkitd|sshd|postfix"
DEF_SYS_GRP="root|bin|daemon|sys|adm|tty|disk|lp|mem|kmem|wheel|cdrom|mail|man|dialout|floppy|games|tape|video|ftp|lock|audio|nobody|users|utmp|utempter|input|systemd-journal|systemd-network|dbus|polkitd|ssh_keys|sshd|postdrop|postfix"
DEF_IFS=${IFS}
DEF_CRON_DIR="0hourly"
DEF_CRON_H="0anacron"
DEF_CRON_D="logrotate|man-db.cron|rhsmd"
DEF_CRON_W=""
DEF_CRON_M=""

# Exclusions.
EXC_FS_TYPE="-x tmpfs -x devtmpfs -x nfs"

#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~#
#                                                                      #
#                               FUNCTIONS                              #
#                                                                      #



#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~#
#                                                                      #
#                               BEGINNING                              #
#                                                                      #

# Identification.
SRVNAME=$(hostname -s)
if $(which facter >/dev/null 2>&1); then
  DOMAIN=$(facter domain)
elif [[ -n $(grep search /etc/resolv.conf | awk '{print $2}') ]]; then
  DOMAIN=$(grep search /etc/resolv.conf | awk '{print $2}')
elif [[ $(hostname -f) == *"."* ]]; then
  DOMAIN=$(hostname -f | cut -d"." -f2-)
elif [[ $(hostname) == *"."* ]]; then
  DOMAIN=$(hostname | cut -d"." -f2-)
elif [[ $(uname -n) == *"."* ]]; then
  DOMAIN=$(uname -n | cut -d"." -f2-)
else
  DOMAIN="unknown"
fi

# Operating System.
OS="Linux"
if [[ $(grep "Red Hat" /etc/system-release) ]]; then
  DISTRIB_NAME="RedHat"
elif [[ $(grep "CentOS" /etc/system-release) ]]; then
  DISTRIB_NAME="CentOS"
else
  DISTRIB_NAME="unknown"
fi
DISTRIB_RELEASE=$(cat /etc/system-release | sed -e 's/.*release[[:blank:]]*\([[:digit:]][[:graph:]]*\).*/\1/')
KERNEL_VERS=$(uname -r)

# Hardware.
MEM_SIZE=$(grep MemTotal /proc/meminfo | awk -F':' '{print $2}' | sed 's/^[ \t]*//')
SWAP_SIZE=$(grep SwapTotal /proc/meminfo | awk -F':' '{print $2}' | sed 's/^[ \t]*//')
CPU_COUNT=$(lscpu | grep "^CPU(s):" | awk -F':' '{print $2}' | sed 's/^[ \t]*//')
ARCH=$(uname -p)
PRODUCT_NAME=$(dmidecode -s system-product-name)
case ${PRODUCT_NAME} in
  KVM | "VMware Virtual Platform" | VirtualBox | "OpenStack Nova")
    TYPE="VM"
    SN="N/A"
    MANUFACTURER="N/A"
  ;;
  *)
    TYPE="BM"
    SN=$(dmidecode -s system-serial-number)
    MANUFACTURER=$(dmidecode -s system-manufacturer)
  ;;
esac

# Boot.
DEF_TARGET=$(systemctl get-default)

# Networking.
NET_IF_COUNT=$(echo "$(ip l | sed '/^[ \t]/d' | wc -l) -1" | bc)
if $(which facter >/dev/null 2>&1); then
  NET_IP_MAIN=$(facter networking.ip)
elif [[ -n $(hostname -I | awk '{print $1}') ]]; then
  NET_IP_MAIN=$(hostname -I | awk '{print $1}')
elif [[ -n $(ip route get 1.2.3.4 | awk '{print $7}') ]]; then
  NET_IP_MAIN=$(ip route get 1.2.3.4 | awk '{print $7}')
elif [[ $(rpm -qa | grep bind-utils) ]]; then
  NET_IP_MAIN=$(dig +short $(hostname))
fi
for INTERFACE in $(ip l | sed '/^[ \t]/d' | cut -d":" -f2 | sed 's/^[ \t]*//' | grep -v lo); do
  if [[ $(ip a show dev ${INTERFACE} | grep inet) ]]; then
    IF_IP=$(ip a show dev ${INTERFACE} | grep inet | grep -v inet6 | awk '{print $2}')
  else
    IF_IP=""
  fi
  NET_LIST+=( "${INTERFACE} : { ip_address = ${IF_IP} }" )
done

# Users and groups.
if [[ $(cat /etc/passwd | egrep -v ${DEF_SYS_USR} | wc -l) == 0 ]]; then
  USR_LOCAL="none"
else
  for LOCAL_USR in $(cat /etc/passwd | egrep -v ${DEF_SYS_USR} | awk -F':' '{print $1}'); do
    USR_UID=$(grep "^${USER}:" /etc/passwd | awk -F':' '{print $3}')
    USR_GID=$(grep "^${USER}:" /etc/passwd | awk -F':' '{print $4}')
    USR_GECOS=$(grep "^${USER}:" /etc/passwd | awk -F':' '{print $5}')
    USR_HOME_DIR=$(grep "^${USER}:" /etc/passwd | awk -F':' '{print $6}')
    USR_SHELL=$(grep "^${USER}:" /etc/passwd | awk -F':' '{print $7}')
    USR_GROUPS=$(id ${USER} | awk '{print $3}' | awk -F'=' '{print $2}')
    USR_LOCAL+=( "${LOCAL_USR} : { uid = ${USR_UID}, gid = ${USR_GID}, gecos = ${USR_GECOS}, home_dir = ${USR_HOME_DIR}, shell = ${USR_SHELL}, groups = ${USR_GROUPS} }" )
  done
fi
if [[ $(cat /etc/group | egrep -v ${DEF_SYS_GRP} | wc -l) == 0 ]]; then
  GRP_LOCAL="none"
else
  for GROUP in $(cat /etc/group | egrep -v ${DEF_SYS_GRP}); do
    GRP_NAME=$(echo ${GROUP} | awk -F':' '{print $1}')
    GID=$(echo ${GROUP} | awk -F':' '{print $3}')
    GRP_LOCAL+=( "${GRP_NAME} : { gid = ${GID} }" )
  done
fi

# Known host keys.
if [[ $(find -xdev $(eval df -ThP ${EXC_FS_TYPE} | tail -n +2 | awk '{print $7}' | tr "\n" " ") -type f -name "known_hosts" | wc -l) == 0 ]]; then
  KNOWN_HOSTS_FILES="none"
else
  for KNOWN_HOSTS in $(find -xdev $(eval df -ThP ${EXC_FS_TYPE} | tail -n +2 | awk '{print $7}' | tr "\n" " ") -type f -name "known_hosts"); do
    KNOWN_HOSTS_FILE=$(echo ${KNOWN_HOSTS} | tr "/" "-" | cut -c 2-)
    cp ${KNOWN_HOSTS} ${DIR_TMP_FIL}/${KNOWN_HOSTS_FILE}
    KH_PATH=$(dirname ${KNOWN_HOSTS})
    OWNER=$(ls -l ${KNOWN_HOSTS} | awk '{print $3}')
    GROUP=$(ls -l ${KNOWN_HOSTS} | awk '{print $4}')
    MODE=$(ls -l ${KNOWN_HOSTS} | awk '{k=0; for(i=0;i<=8;i++) k+=((substr($1,i+2,1)~/[rwx]/)*2^(8-i)); if (k) printf(" %0o ",k); print}' | awk '{print $1}')
    KNOWN_HOSTS_FILES+=( "${KNOWN_HOSTS_FILE} : { path = ${KH_PATH}, owner = ${OWNER}, group = ${GROUP}, mode = ${MODE} }" )
  done
fi

# Authorized SSH keys.
if [[ $(find -xdev $(eval df -ThP ${EXC_FS_TYPE} | tail -n +2 | awk '{print $7}' | tr "\n" " ") -type f -name "authorized_keys" 2>/dev/null | wc -l) == 0 ]]; then
  AUTH_KEYS_FILES="none"
else
  for AUTH_KEYS in $(find -xdev $(eval df -ThP ${EXC_FS_TYPE} | tail -n +2 | awk '{print $7}' | tr "\n" " ") -type f -name "authorized_keys" 2>/dev/null); do
    AUTH_KEYS_FILE=$(echo ${AUTH_KEYS} | tr "/" "-" | cut -c 2-)
    cp ${AUTH_KEYS} ${DIR_TMP_FIL}/${AUTH_KEYS_FILE}
    AK_PATH=$(dirname ${AUTH_KEYS})
    OWNER=$(ls -l ${AUTH_KEYS} | awk '{print $3}')
    GROUP=$(ls -l ${AUTH_KEYS} | awk '{print $4}')
    MODE=$(ls -l ${AUTH_KEYS} | awk '{k=0; for(i=0;i<=8;i++) k+=((substr($1,i+2,1)~/[rwx]/)*2^(8-i)); if (k) printf(" %0o ",k); print}' | awk '{print $1}')
    AUTH_KEYS_FILES+=( "${AUTH_KEYS_FILE} : { path = ${AK_PATH}, owner = ${OWNER}, group = ${GROUP}, mode = ${MODE} }" )
  done
fi

# SSH fingerprints.
for PUB_SSH_FIU in $(ls -1 /etc/ssh/ssh_host*.pub); do
  PRIV_SSH_FIU=$(echo ${PUB_SSH_FIU} | awk -F'.' 'BEGIN{OFS=FS};NF{NF-=1};1')
  cp ${PUB_SSH_FIU} ${PRIV_SSH_FIU} ${DIR_TMP_FIL}/
  FIU_PATH=$(dirname ${PUB_SSH_FIU})
  PUB_OWNER=$(ls -l ${PUB_SSH_FIU} | awk '{print $3}')
  PUB_GROUP=$(ls -l ${PUB_SSH_FIU} | awk '{print $4}')
  PUB_MODE=$(ls -l ${PUB_SSH_FIU} | awk '{k=0; for(i=0;i<=8;i++) k+=((substr($1,i+2,1)~/[rwx]/)*2^(8-i)); if (k) printf(" %0o ",k); print}' | awk '{print $1}')
  PRIV_KEY=$(basename ${PRIV_SSH_FIU})
  PRIV_OWNER=$(ls -l ${PRIV_SSH_FIU} | awk '{print $3}')
  PRIV_GROUP=$(ls -l ${PRIV_SSH_FIU} | awk '{print $4}')
  PRIV_MODE=$(ls -l ${PRIV_SSH_FIU} | awk '{k=0; for(i=0;i<=8;i++) k+=((substr($1,i+2,1)~/[rwx]/)*2^(8-i)); if (k) printf(" %0o ",k); print}' | awk '{print $1}')
  SSH_FIU+=( "$(basename ${PUB_SSH_FIU}) : { path = ${FIU_PATH}, pub_owner = ${PUB_OWNER}, pub_group = ${PUB_GROUP}, pub_mode = ${PUB_MODE}, priv_key = ${PRIV_KEY}, priv_owner = ${PRIV_OWNER}, priv_group = ${PRIV_GROUP}, priv_mode = ${PRIV_MODE} }" )
done

# File systems.
IFS=$'\n'
for FS in $(eval df -ThPx ${EXC_FS_TYPE} | tail -n +2); do
  FILESYS=$(echo ${FS} | awk '{print $1}')
  SIZE=$(echo ${FS} | awk '{print $3}')
  USE=$(echo ${FS} | awk '{print $4}')
  MOUNT_PT=$(echo ${FS} | awk '{print $7}')
  FS_TYPE=$(echo ${FS} | awk '{print $2}')
  FILESYSTEMS+=( "${FILESYS} : { size = ${SIZE}, used = ${USE}, mount_pt = ${MOUNT_PT}, type = ${FS_TYPE} }" )
done
IFS=${DEF_IFS}

# Disks.
IFS=$'\n'
for DISK in $(lsblk -rno NAME,TYPE,SIZE | awk '$2 == "disk" { print $0 }'); do
  NAME=$(echo ${DISK} | awk '{print $1}')
  SIZE=$(echo ${DISK} | awk '{print $3}')
  DISKS+=( "${NAME} : { size = ${SIZE} }" )
done
IFS=${DEF_IFS}

# Partitions.
IFS=$'\n'
for PART in $(lsblk -rno NAME,SIZE,TYPE,MOUNTPOINT,FSTYPE | awk '$3 == "part" { print $0 }' | sed 's/  / N\/A /'); do
  NAME=$(echo ${PART} | awk '{print $1}')
  SIZE=$(echo ${PART} | awk '{print $2}')
  MOUNT_PT=$(echo ${PART} | awk '{print $4}')
  FSTYPE=$(echo ${PART} | awk '{print $5}')
  PARTS+=( "${NAME} : { size = ${SIZE}, mount_pt = ${MOUNT_PT}, type = ${FSTYPE} }" )
done
IFS=${DEF_IFS}

# Physical volumes.
IFS=$'\n'
for PV in $(pvs --noheadings); do
  NAME=$(echo ${PV} | awk '{print $1}')
  VG=$(echo ${PV} | awk '{print $2}')
  SIZE=$(echo ${PV} | awk '{print $5}')
  PVS+=( "${NAME} : { vg = ${VG}, size = ${SIZE} }" )
done
IFS=${DEF_IFS}

# Volume groups.
IFS=$'\n'
for VG in $(vgs --noheadings); do
  NAME=$(echo ${VG} | awk '{print $1}')
  VG_COUNT=$(echo ${VG} | awk '{print $2}')
  LV_COUNT=$(echo ${VG} | awk '{print $3}')
  SIZE=$(echo ${VG} | awk '{print $6}')
  VGS+=( "${NAME} : { vg_count = ${VG_COUNT}, lv_count = ${LV_COUNT}, size = ${SIZE} }" )
done
IFS=${DEF_IFS}

# Logical volumes.
IFS=$'\n'
for LV in $(lvs --noheadings); do
  NAME=$(echo ${LV} | awk '{print $1}')
  VG_NAME=$(echo ${LV} | awk '{print $2}')
  SIZE=$(echo ${LV} | awk '{print $4}')
  LVS+=( "${NAME} : { vg_name = ${VG_NAME}, size = ${SIZE} }" )
done
IFS=${DEF_IFS}

# Exported file systems.
NFS_SHARED="unknown"

# Mounted network file systems.
NFS_MOUNTED="unknown"

# Installed packages.
if [[ $(rpm -qa | egrep -v $(cat ${FIL_INI_PKG} | tr '\n' '|' | sed 's/.\{1\}$//') | wc -l) != 0 ]]; then
  for PACKAGE in $(rpm -qa | egrep -v $(cat ${FIL_INI_PKG} | tr '\n' '|' | sed 's/.\{1\}$//') | awk -F'-' 'BEGIN{OFS=FS};NF{NF-=2};1'); do
    PKG_LST+=( "${PACKAGE}" )
  done
else
  PKG_LST="none"
fi

# Installed package groups.
IFS=$'\n'
for GROUP in $(yum groups list installed -q | sed 's/^[ \t]*//'); do
  PKG_GRPS+=( "${GROUP}" )
IFS=${DEF_IFS}

# Enabled repos.
if [[ $(awk -v RS='' "/enabled[[:space:]]?=[[:space:]]?1/" /etc/yum.repos.d/* | wc -l) != 0 ]]; then
  for REPO_ID in $(awk -v RS='' "/enabled[[:space:]]?=[[:space:]]?1/" /etc/yum.repos.d/* | grep "^\[" | sed 's/^.//;s/.$//'); do
    REPO_LST+=( "${REPO_ID}" )
  done
else
  REPO_LST="none"
fi

# Services.
for SERVICE in $(systemctl -t service --state=active --no-legend | awk '{print $1}'); do
  SVC_RUNNING+=( "${SERVICE}" )
done
for SERVICE in $(systemctl list-unit-files -t service --no-legend | grep enabled | awk '{print $1}'); do
  SVC_ENABLED+=( "${SERVICE}" )
done

# Open ports.
if [[ $(rpm -qa | grep net-tools) ]]; then
  IFS=$'\n'
  for LSTN_PORT in $(netstat -punta | grep LISTEN | awk '{print $4,$7}' | egrep -v "127.0.0.1:|::1:" | awk -F':' '{print $2}' | grep -v "^$"); do
    PORT=$(echo ${LSTN_PORT} | awk '{print $1}')
    SERVICE=$(echo ${LSTN_PORT} | awk  -F'/' '{print $2}')
    LSTN_PORTS+=( "${PORT} : { service = ${SERVICE} }" )
  done
  IFS=${DEF_IFS}
fi

# Firewall configuration.
if [[ $(systemctl is-active firewalld) ]]; then
  FW_STATUS="Running"
  for ZONE in $(firewall-cmd --get-active-zones | egrep -v "interfaces"); do
    TARGET=$(firewall-cmd --zone=${ZONE} --permanent --get-target)
    ICMP_BLK_INVERSION=$(firewall-cmd --zone=${ZONE} --query-icmp-block-inversion)
    INTERFACES=$(firewall-cmd --zone=${ZONE} --list-interfaces)
    if [[ $(firewall-cmd --zone=${ZONE} --list-sources) != "" ]]; then
      SOURCES=$(firewall-cmd --zone=${ZONE} --list-sources)
    else
      SOURCES="none"
    fi
    if [[ $(firewall-cmd --zone=${ZONE} --list-services) != "" ]]; then
      SERVICES="["
      for SVC in $(firewall-cmd --zone=${ZONE} --list-services); do
        SERVICES="${SERVICES} \"${SVC}\","
      done
      SERVICES="$(echo ${SERVICES} | sed 's/.$//') ]"
    else
      SERVICES="none"
    fi
    if [[ $(firewall-cmd --zone=${ZONE} --list-ports) != "" ]]; then
      PORTS=$(firewall-cmd --zone=${ZONE} --list-ports)
    else
      PORTS="none"
    fi
    if [[ $(firewall-cmd --zone=${ZONE} --list-protocols) != "" ]]; then
      PROTOCOLS=$(firewall-cmd --zone=${ZONE} --list-protocols)
    else
      PROTOCOLS="none"
    fi
    MASQUERADE=$(firewall-cmd --zone=${ZONE} --query-masquerade)
    if [[ $(firewall-cmd --zone=${ZONE} --list-forward-ports) != "" ]]; then
      FWD_PORTS=$(firewall-cmd --zone=${ZONE} --list-forward-ports)
    else
      FWD_PORTS="none"
    fi
    if [[ $(firewall-cmd --zone=${ZONE} --list-source-ports) != "" ]]; then
      SRC_PORTS=$(firewall-cmd --zone=${ZONE} --list-source-ports)
    else
      SRC_PORTS="none"
    fi
    if [[ $(firewall-cmd --zone=${ZONE} --list-icmp-blocks) != "" ]]; then
      ICMP_BLK=$(firewall-cmd --zone=${ZONE} --list-icmp-blocks)
    else
      ICMP_BLK="none"
    fi
    if [[ $(firewall-cmd --zone=${ZONE} --list-rich-rules) != "" ]]; then
      RICH_RULES=$(firewall-cmd --zone=${ZONE} --list-rich-rules)
    else
      RICH_RULES="none"
    fi
    FW_RULES+=( "${ZONE} : { target = ${TARGET}, icmp_block_inversion = ${ICMP_BLK_INVERSION}, interfaces = ${INTERFACES}, sources = ${SOURCES}, services = ${SERVICES}, ports = ${PORTS}, protocols = ${PROTOCOLS}, masquerade = ${MASQUERADE}, forward_ports = ${FWD_PORTS}, source_ports = ${SRC_PORTS}, icmp_blocks = ${ICMP_BLK}, rich_rules = ${RICH_RULES} }" )
  done
else
  FW_STATUS="Stopped"
  FW_RULES=false
fi

# SELinux.
SELINUX_STATUS=$(getenforce)

# Users' crontabs.
if [[ $(ls /var/spool/cron/*) ]]; then
  for FILE in $(ls -1 /var/spool/cron/); do
    if [[ -s /var/spool/cron/${FILE} ]]; then
      CRON_USR+=( "${FILE}" )
      cp /var/spool/cron/${FILE} ${DIR_TMP_FIL}/cron-${FILE}
    fi
  done
else
  CRON_USR=false
fi

# File /etc/cron.deny.
if [[ -s /etc/cron.deny ]]; then
  CRON_DENY=true
  cp /etc/cron.deny ${DIR_TMP_FIL}/
else
  CRON_DENY=false
fi

# File /etc/cron.allow.
if [[ -s /etc/cron.allow ]]; then
  CRON_ALLW=true
  cp /etc/cron.allow ${DIR_TMP_FIL}/
else
  CRON_ALLW=false
fi

# File /etc/crontab.
if $(diff /etc/crontab ${FIL_INI_CRON}); then
  CRON_FIL=false
else
  CRON_FIL=true
  cp /etc/crontab ${DIR_TMP_FIL}/
fi

# Directory /etc/cron.d.
if [[ $(ls -1 /etc/cron.d/ | egrep -v ${DEF_CRON_DIR} | wc -l) != 0 ]]; then
  for FILE in $(ls -1 /etc/cron.d/ | egrep -v ${DEF_CRON_DIR}); do
    if [[ -s /etc/cron.d/${FILE} ]]; then
      CRON_DIR+=( "${FILE}" )
      cp /etc/cron.d/${FILE} ${DIR_TMP_FIL}/cron_dir-${FILE}
    fi
  done
else
  CRON_DIR=false
fi

# Directory /etc/cron.hourly.
if [[ $(ls -1 /etc/cron.hourly/ | egrep -v ${DEF_CRON_H} | wc -l) != 0 ]]; then
  for FILE in $(ls -1 /etc/cron.hourly/ | egrep -v ${DEF_CRON_H}); do
    if [[ -x /etc/cron.hourly/${FILE} ]]; then
      CRON_HR+=( "${FILE}" )
      cp /etc/cron.hourly/${FILE} ${DIR_TMP_FIL}/cron_hr-${FILE}
    fi
  done
else
  CRON_HR=false
fi

# Directory /etc/cron.daily.
if [[ $(ls -1 /etc/cron.daily/ | egrep -v ${DEF_CRON_D} | wc -l) != 0 ]]; then
  for FILE in $(ls -1 /etc/cron.daily/ | egrep -v ${DEF_CRON_D}); do
    if [[ -x /etc/cron.daily/${FILE} ]]; then
      CRON_DAY+=( "${FILE}" )
      cp /etc/cron.daily/${FILE} ${DIR_TMP_FIL}/cron_day-${FILE}
    fi
  done
else
  CRON_DAY=false
fi

# Directory /etc/cron.weekly.
if [[ $(ls -1 /etc/cron.weekly/ | egrep -v ${DEF_CRON_W} | wc -l) != 0 ]]; then
  for FILE in $(ls -1 /etc/cron.weekly/ | egrep -v ${DEF_CRON_W}); do
    if [[ -x /etc/cron.weekly/${FILE} ]]; then
      CRON_WEEK+=( "${FILE}" )
      cp /etc/cron.weekly/${FILE} ${DIR_TMP_FIL}/cron_week-${FILE}
    fi
  done
else
  CRON_WEEK=false
fi

# Directory /etc/cron.monthly.
if [[ $(ls -1 /etc/cron.monthly/ | egrep -v ${DEF_CRON_M} | wc -l) != 0 ]]; then
  for FILE in $(ls -1 /etc/cron.monthly/ | egrep -v ${DEF_CRON_M}); do
    if [[ -x /etc/cron.monthly/${FILE} ]]; then
      CRON_MTH+=( "${FILE}" )
      cp /etc/cron.monthly/${FILE} ${DIR_TMP_FIL}/cron_mth-${FILE}
    fi
  done
else
  CRON_MTH=false
fi

# Message of the day.
if [[ -s "/etc/motd" ]]; then
  cp /etc/motd ${DIR_TMP_FIL}/
  MOTD=true
else
  MOTD=false
fi

# Create the INI file.
source ${SCR_MK_INI}

#                                                                      #
#                                 END                                  #
#                                                                      #
#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~#
