#! /bin/bash 
#
# Boinc uses a clear text password stored in the file gui_rpc_auth.cfg
# On first run the data directory should be empty, or at minimum should
# not contain the file gui_rpc_auth.cfg. We can use this to either set
# a user supplied password from an environment variable or create an
# empty file which will effectively diable the password. 
#
if [ ! -f /home/boinc/gui_rpc_auth.cfg ]; then
   if [ ! -z "$PASSWORD" ]; then
      echo "$PASSWORD" > /home/boinc/gui_rpc_auth.cfg 
   else
       touch /home/boinc/gui_rpc_auth.cfg
   fi
fi
/usr/bin/boinc --allow_remote_gui_rpc --dir /home/boinc 2>&1 | grep -vi "/dev/input"
