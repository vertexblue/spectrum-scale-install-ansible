#!/bin/sh
#
# This is wrapper script to generate hosts file
# and run afm-dr playbook.
#
basedir=$0
echo $basedir
config_file=afm-dr-config.json

source_gui_ip=`grep source_scale_gui_hostname $config_file|awk -F\" '{print $4}'`
target_gui_ip=`grep target_scale_gui_hostname $config_file|awk -F\" '{print $4}'`

echo "#hosts:
[afm-dr-source-gui-hostname]
$source_gui_ip

[afm-dr-target-gui-hostname]
$target_gui_ip" > afm-dr-inventory.ini

# execute ansible playbook
ansible-playbook -i afm-dr-inventory.ini afm-dr-playbook.yml