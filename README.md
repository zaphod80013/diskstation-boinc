# Boinc

## Overview
This is a Docker container created specifically to run a [boinc client](https://boinc.berkeley.edu) on my [Synology](https://www.synology.com) DS1815+ NAS, Although only tested on the DS1815+ it should run on any compatible DiskStation running DSM 6.0 or above with the Docker package installed. There is nothing Synology specific in the build so it should also run in any compatible Docker environment. The image is based on Ubuntu "Xenial Xerus" and uses an externally mapped directory for boinc data. This approach preserves work in progress across container restarts and upgrades. 

The initial version of this image was my first foray into creating a Docker container. It's worked for me for about a year now (as of March 1st 2017) and I've tested data preservation across restarts and contain upgrades. However your milage may vary. Feedback always welcome. 

For the current version I've switched the base image from Debian Jessie to Ubuntu  Xenial. This has resulted in a slightly larger image but allowed me to  pick up the 7.31 client, Debian, as of 1st March 2017, was still shipping the Boinc 7.4 client. 

## Background

By default, on Debian derived systems, the Boinc client installs with a working directory of */var/lib/boinc-client* as part of building the container I delete the contents of this directory. There are three reasons for this:

* One of the files contains a generated uuid for this 'host' that is used to identify the machine, without this step all instances of the image would likely have the same identifier (see below for details). One consequence of this is that If you use an an Account Manager such as **BAM!** and run multiple containers they will likely all report under the same id and the hostname displayed on the website is unstable.

* Boinc will generate a random remote access password stored in *gui_rpc_auth.cfg* . Without visibility into the container (or host system) to retrieve this password we would not be able to access the client remotely, and to access it locally we incur the overhead of installing a desktop and VNC server adding bloat to the container. 

* We're going to map our working directory to an external location so these files are redundant. 

## Operation

The container entry point is a shell script called **startup.sh** placed in the */usr/local/bin* directory. This performs some first run setup and then starts the boinc client. The first run addresses the password issue outlined above, the code to do this follows:

	    if [ ! -f /home/boinc/gui_rpc_auth.cfg ]; then
	       if [ ! -z "$PASSWORD" ]; then
	          echo "$PASSWORD" > /home/boinc/gui_rpc_auth.cfg
	       else
	           touch /home/boinc/gui_rpc_auth.cfg
	       fi
	    fi
As you can see I determine first run by the absence of the password file. if it is not present one of two things will happen; if an environment variable called *PASSWORD* is passed to the docker run command its value is written to the file ***this appears to be a clear text password*** so avoid using a password you care about!  If the variable is not present an empty file is created which disables the remote access password altogether. After the first run the environment variable is no longer needed and may be removed to improve security, alternatively the file could be created manually and uploaded to the DiskStation via File Station at any point to create or change the password. 

The boinc client is then run as a foreground process using the command:

	      /usr/bin/boinc --allow_remote_gui_rpc  --dir /home/boinc 2>&1 | grep -vi "/dev/input"
This allows remote access from any host, maps the boinc data directory to */home/boinc* and filters the console output to remove certain error messages. The filtered messages are produce at a rate of about 3 per second and relate to physical devices not present in the Docker container, or as it happens on the DS1815+ (keyboard and mouse). I suspect these messages relate to detecting the "computer in use" condition that can be used to suspend boinc processing. Regardless we don't want to clutter the NAS with logs growing at the rate of over 250,000 lines a day.

## Usage

The container exposes 3 ports:

* The boinc management port (31416)
* The standard http (80) Used for project communication.
* The standard https ports (443) Again used for project communication.

And a single volume.

 * /home/boinc used to mount the external boinc data directory.
 
The directory mapped to */home/boinc* will likely need to be world writable in order to avoid permission problem when writing to it from the container. From the container's perspective the files will be owned by the BOINC user but from the NAS's perspective the directory is most likely owned by the Admin user. since their numeric user and group IDs will most likely differ the NAS will, by default, deny access to the container.

To run the container from the command line you will need a command something like:

    docker run -d -v <absolute path to data directory>:/home/boinc:rw -p 32768:31416 -p 32769:443 -p 32770:80 boinc
    
Or possibly for the first run only:

    docker run -d -v /Users/ray/docker/Boinc/local:/home/boinc:rw -p 32768:31416 -p 32769:443 -p 32770:80 -e PASSWORD=xxxx boinc

On the DiskStation the Container Launch wizard can be used to build a launch command equivalent to the above.

##The Boinc HostID

Based on inspecting the source code the Boinc code that generates the host_cpid is reasonably deterministic in that if it finds a mac address it uses a md5 hash of this with the Boinc working directory name concatenated, the later ensure multiple instances on the same host get different host_cpid values. Unfortunately Docker is also reasonably deterministic in the way it chooses a private network subnet and allocates mac addresses to containers within that subnet.

 The net result is that it's highly likely we will generate identical host_cpid values running the container in different Docker instances. If a given user runs this Boinc image in multiple docker environments the likely identical host_cpid can result in account managers such as BAM! seeing different containers as the same host and allocating the same BAM! Host ID to them. This results in them being recorded as a single host who's name keep changing.
 
 The startup.sh script addresses this by generating a new host_cpid based on the current nanosecond clock and using it to replace the original value in the client_state files. This has to occur only on the first run and before we connect to an account manager.
 
If the client_state file is missing we assume this is a first run situation and need to initialize Boinc to create a default config, this is where we generate our, hopefully unique host identifier and substitute this for the Boinc generated one.