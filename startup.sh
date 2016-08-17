#! /bin/bash -x 
client_state.xml

if [ ! -f /home/boinc/client_state.xml ]; then
   #
   # The boinc code that generates the host_cpid is reasonably determinstic
   # in that if it finds a mac address it uses a md5 hash of this with the 
   # boinc working directory name concatenated, the later ensure multiple
   # instances on the same host get different host_cpid values.
   #
   # Unfortunately Docker is also reasonably determinstic in the way it
   # chooses a private network subnet and allocates mac addresses to 
   # containers within that subnet.
   #
   # The net result is that it's highly likely we will generate identical 
   # host_cpid values running the container in different Docker instances.
   # If a given user runs this boinc image in multiple docker environments
   # the identical host_cpid can result in account managers such as BAM!
   # seeing different containers as the same host and allocating the same
   # BAM! Host ID to them. The results in them being recorded as a single
   # host who's name keep changing.
   #
   # The following code addresses this by generating a new host_cpid based
   # on the current nanosecond clock and replacing the value in the 
   # client_state files.
   #
   # If the client_state file is missing we assume this is a first run
   # situation and need to initialize boinc to create a default config, We
   # also want to generate a, hopefully unique host identifer and substitute
   # this for the boinc generated one.
   #
   # Run boinc as background process.
   #
   /usr/bin/boinc --dir /home/boinc 2>&1 > /dev/null &
   #
   # Capture its process id
   #
   pid=$!
   #
   # Wait for working directory initialization
   #
   sleep 5
   #
   # Stop boinc
   #
   kill $pid
   #
   # Wait for boinc to exit
   #
   sleep 5
   #
   # we should now have a brand-spanking-new working directory,
   # generat a uuid?
   # 
   cpid=$(date +%s%N|md5sum|cut -d' ' -f 1)
   #
   # Edit the host cpid in-situ
   #
   sed -i -e "s?<host_cpid>.*</host_cpid>?<host_cpid>${cpid}</host_cpid>?g" /home/boinc/client_state.xml 
   sed -i -e "s?<host_cpid>.*</host_cpid>?<host_cpid>${cpid}</host_cpid>?g" /home/boinc/client_state_prev.xml 
   #
   # remove default remote access password file, we have no way to access 
   # it without bloating the container with VNC or SSH. This also allows 
   # the user to set a password from the external environment if they
   # want..
   #
   rm /home/boinc/gui_rpc_auth.cfg
fi
if [ ! -f /home/boinc/gui_rpc_auth.cfg ]; then
   #
   # Boinc uses a clear text password stored in the file gui_rpc_auth.cfg
   # On first run this file will be missing, because I deleted it above, 
   # which will trigger this part of the script where we either set a user
   # supplied password from an environment variable or create an empty file 
   # which will effectively diable the password. 
   #
   if [ ! -z "$PASSWORD" ]; then
      echo "$PASSWORD" > /home/boinc/gui_rpc_auth.cfg 
   else
       touch /home/boinc/gui_rpc_auth.cfg
   fi
fi
/usr/bin/boinc --allow_remote_gui_rpc --dir /home/boinc 2>&1 | grep -vi "/dev/input"

