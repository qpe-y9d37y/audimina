#!/bin/ksh

########################################################################
# MIT License                             Copyright 2020 Quentin Petit #
# May 2020                                  <quentin.petit@sogeti.com> #
#                                                                      #
#                            amn_ux_aix.ksh                            #
#                                                                      #
# Current version: 0.1                                                 #
# Status: Work in progress                                             #
#                                                                      #
# This script purpose it to audit an AIX server.                       #
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



#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~#
#                                                                      #
#                               FUNCTIONS                              #
#                                                                      #



#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~#
#                                                                      #
#                               BEGINNING                              #
#                                                                      #

# Hostname and domain.
if [[ $(uname -n) == *"."* ]]; then
  HOSTNAME=$(uname -n | cut -d"." -f1)
  DOMAIN=$(uname -n | cut -d"." -f2-)
else
  HOSTNAME=$(uname -n)
  DOMAIN="unknown"
fi

# OS.
OS="AIX"
DISTRIB_NAME="N/A"
DISTRIB_RELEASE=$(oslevel)

# System.


#                                                                      #
#                                 END                                  #
#                                                                      #
#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~#
