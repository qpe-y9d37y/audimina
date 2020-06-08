#!/usr/bin/env python3

########################################################################
# Python 3                                               Quentin Petit #
# May 2020                                 <qpe-y9d37y@protonmail.com> #
#                                                                      #
#                              trinity.py                              #
#                                                                      #
# Current version: 1.0                                                 #
# Status: Stable                                                       #
#                                                                      #
# This script purpose it to transform an INI file to JSON or YAML.     #
#                                                                      #
# Version history:                                                     #
# +----------+------------+------+-----------------------------------+ #
# |   Date   |   Author   | Vers | Comment                           | #
# +==========+============+======+===================================+ #
# | 20200528 | Quentin P. | 1.0  | First stable version              | #
# +----------+------------+------+-----------------------------------+ #
#                                                                      #
########################################################################

#                                                                      #
#                              LIBRAIRIES                              #
#                                                                      #

import argparse
import configparser
import json
import os
import sys
import yaml

#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~#
#                                                                      #
#                               VARIABLES                              #
#                                                                      #

data = {}

#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~#
#                                                                      #
#                               FUNCTIONS                              #
#                                                                      #



#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~#
#                                                                      #
#                               BEGINNING                              #
#                                                                      #

# Retrieve arguments.
parser = argparse.ArgumentParser(description='Transform INI file to YAML or JSON.')
parser.add_argument('-s', action="store", dest="src", help="source file")
parser.add_argument('-y', action='store_true', dest="yaml", help="transform INI file to YAML")
parser.add_argument('-j', action='store_true', dest="json", help="transform INI file to JSON")
args = parser.parse_args()

# Check arguments.
if not args.src:
    print("error: source file not specified")
    parser.print_help()
    sys.exit(1)
elif args.yaml is False and args.json is False:
    print("error: target format not specified")
    parser.print_help()
    sys.exit(1)
elif args.yaml is True and args.json is True:
    print("error: cannot transform source file to JSON and YAML at the same time. Choose one.")
    parser.print_help()
    sys.exit(1)
else:
    ini_src = args.src

# Check if file exists.
if not os.path.isfile(ini_src):
    print("error: source file " + ini_src + " doesn't exist.")
    sys.exit(1)

# Open config file.
config = configparser.ConfigParser()
config.read(ini_src)

# Read each_section of ini_src to create data.
for each_section in config.sections():
    data[each_section] = {}
    # Read each key/value pair.
    for each_key, each_val in config.items(each_section):
        # If value is between square brackets.
        if each_val.startswith("[") and each_val.endswith("]"):
            # If value is a nested dictionary.
            if '{' in each_val and '}' in each_val:
                dict = {}
                for elem in each_val[2:-2].split('","'):
                    dict[elem.split(" : ")[0]] = {}
                    for pair in elem.split(" : ")[1][2:-2].split(", "):
                        dict[elem.split(" : ")[0]][pair.split(' = ')[0]] = pair.split(' = ')[1]
                data[each_section][each_key] = dict
            # Else value is a list.
            else:
                data[each_section][each_key] = [elem[1:-1] for elem in each_val[1:-1].split(',') if elem]
        # If value is a simple dictionary.
        elif '{' in each_val and '}' in each_val:
            dict = {}
            dict[each_val.split(" : ")[0]] = {}
            for pair in each_val.split(" : ")[1][2:-2].split(", "):
                dict[each_val.split(" : ")[0]][pair.split(' = ')[0]] = pair.split(' = ')[1]
            data[each_section][each_key] = dict
        # Else value is a simple value.
        else:
            data[each_section][each_key] = each_val

# Write JSON data if "-j" argument.
if args.json is True:
    # Set json_out.
    json_out = ini_src.replace('.ini', '.json')
    
    # Write data in json_out.
    with open(json_out, 'w') as outfile:
        json.dump(data, outfile, indent=4)

# Write YAML data if "-y" argument.
elif args.yaml is True:
    # Set yaml_out.
    yaml_out = ini_src.replace('.ini', '.yml')
    
    # Write data in yaml_out.
    with open(yaml_out, 'w') as outfile:
        yaml.dump(data, outfile, default_flow_style=False)

#                                                                      #
#                                  END                                 #
#                                                                      #
#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~#