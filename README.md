# Boinc 
## Overview
This is a Docker container created specifically to run a [boinc client](https://boinc.berkeley.edu) on my [Synology](https://www.synology.com) DS1815+ NAS, Although only tested on the DS1815+ it should run on any Intel compatible DiskStation running DSM 6.0 or above with the Docker package installed. There is nothing Synology specific in the build so it should also run in any compatible Docker environment. The image is based on Debian Jesse and uses an externally mapped directory for boinc data. This preserves work in progress across container restarts and upgrades. 

This is my first foray into creating a Docker container, it's working for me and I've tested data preservation across restarts and contain upgrades. However your milage may vary. Feedback welcomed. 

## Background

By default Debian installs the boinc client with a working directory of */var/lib/boinc-client* as part of the container build I delete the contents of this directory. There are three reasons for this:

* One of the files contains a generated uuid for this 'host' that is used to identify them machine, without this step all instances of the image would have the same identifier. One consequence of this is that If you use an an Account Manager such as **BAM!** and run multiple containers they all report under the same id and the displayed hostname is not stable. I saw this behavior during testing and believe it will always report the name of the host that most recently connected.

* Boinc will generate a random remote access password stored in *gui_rpc_auth.cfg* . Without visibility into the container to retrieve this password we would not be able to access the client remotely, and to access it locally we incur the overhead of a desktop and VNC server adding bloat to the container.

* We're going to map our working directory to an external location so these files are redundant. 

## Operation

The container entry point is a shell script called **startup.sh** placed in the */usr/local/bin* directory. This performs some first run setup and then starts the boinc client. The first run addresses the password issue outlined above, the code ot do this is:

	    if [ ! -f /home/boinc/gui_rpc_auth.cfg ]; then
	       if [ ! -z "$PASSWORD" ]; then
	          echo "$PASSWORD" > /home/boinc/gui_rpc_auth.cfg
	       else
	           touch /home/boinc/gui_rpc_auth.cfg
	       fi
	    fi
I determine first run by the absence of the password file. if it is not present one of two things will happen; if an environment variable called *PASSWORD* is passed to the docker run command its value is written to the file ***note this is a clear text password*** if the variable is not passed an empty file is created which disables the password altogether. After the first run the environment variable is no longer needed and may be removed to improve security, alternatively the file could be created manually and uploaded to the DiskStation via File Station at any point to create or change the password. 

The boinc client is then run as a foreground process using the command:

	      /usr/bin/boinc --allow_remote_gui_rpc  
	      --dir /home/boinc 2>&1 | grep -vi "/dev/input"
This allows remote access from any host, maps the boinc data directory to */home/boinc* and filters the console output to remove certain error messages. The filtered messages are produce at a rate of about 3 per second and relate to physical devices not present in the Docker container, or as it happens on the DS1815+ (keyboard and mouse). I suspect these messages relate to detecting the "computer in use" condition that can be used to suspend boinc processing. Regardless we don't want to clutter the NAS with logs growing at the rate of over 250,000 lines a day.

## Usage

The container exposes 3 ports:

* The boinc management port (31416)
* The standard http (80) Used for project communication.
* The standard https ports (443) Again used for project communication.

And a single volume.

 * /home/boinc used to mount the external boinc data directory.
 
The directory mapped to */home/boinc* will likely need to be world writable in order to avoid permission problem when writing to it from the container. From the container's perspective the files will be owned by the BOINC user but from the NAS's perspective the directory is owned by the Admin user. since their numeric user and group ids will not match the NAS will by default deny access to the container.

To run the container from the command line you will need a command something like:

    docker run -d -v <absolute path to data directory>:/home/boinc:rw -p 32768:31416 -p 32769:443 -p 32770:80 boinc
    
Or possibly for the first run only:

    docker run -d -v /Users/ray/docker/Boinc/local:/home/boinc:rw -p 32768:31416 -p 32769:443 -p 32770:80 -e PASSWORD=xxxx boinc

On the DiskStation the Container Launch wizard can be used to build a launch command equivalent to the above.	    