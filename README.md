# AUDIMINA

AUDIMINA is an UNIX/Linux auditing tool.

## File tree

```
audimina/
|-- LICENSE
|-- README.md
|-- bin/
|   |-- audimina.sh
|   |-- os/
|   |   |-- amn_lx_el6.sh
|   |   |-- amn_lx_el7.sh
|   |   |-- amn_lx_el8.sh
|   |   `-- amn_ux_aix.ksh
|   |-- util/
|   |   |-- amn_mk_ini.sh
|   |   `-- trinity.py
|-- ini/
|   |-- pkg_lx_el6.txt
|   |-- pkg_lx_el7.txt
|   |-- pkg_lx_el8.txt
|   |-- crn_lx_el6.txt
|   |-- crn_lx_el7.txt
|   `-- crn_lx_el8.txt
`-- out/
```

## Usage

## OS Compatibility

Here is the exhaustive list of fully supported OS:

* Enterprise Linux (RHEL and CentOS)
  - versions:
    + 6
    + 7
    + 8

## To do

Checks to add or improve:

* EL[6|7|8]:
  - Add other EL distributions (ie. Oracle Linux, Scientific Linux)
  - Add check of some applications (ie. apache, tomcat)
  - Add check of databases
  - Add check of cluster
  - Add check of NFS (mounted and exported)
  - Add check of identity management solution (ie. FreeIPA, OpenLDAP)
  - Add check of subscription
  - Add check of non-permanent firewall rules
  - Add check of installation date
  - Add check of necessary reboot
  - Add check of last reboot
* EL[7|8]:
  - Improve firewall rules check
* EL8:
  - Improve check of packages to include modules
