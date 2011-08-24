#!/bin/sh
###############################################################################
# This script is used to provide the password for an encrypted file system by #
# launching a minimal web server from the init script. It should be stored as #
# /etc/ec2/pre_init.sh on the pivoting AMI image to run in the main script.   #
#                                                                             #
# See this thread for some background information:                            #
#   http://developer.amazonwebservices.com/connect/thread.jspa?threadID=24091 #
#                                                                             #
###############################################################################
#                                                                             #
# Copyright (c) 2009, 2011 Henrik Gulbrandsen <henrik@gulbra.net>             #
#                                                                             #
# This software is provided 'as-is', without any express or implied warranty. #
# In no event will the authors be held liable for any damages arising from    #
# the use of this software.                                                   #
#                                                                             #
# Permission is granted to anyone to use this software for any purpose,       #
# including commercial applications, and to alter it and redistribute it      #
# freely, subject to the following restrictions:                              #
#                                                                             #
# 1. The origin of this software must not be misrepresented; you must not     #
#    claim that you wrote the original software. If you use this software     #
#    in a product, an acknowledgment in the product documentation would be    #
#    appreciated but is not required.                                         #
#                                                                             #
# 2. Altered source versions must be plainly marked as such, and must not be  #
#    misrepresented as being the original software.                           #
#                                                                             #
# 3. This notice may not be removed or altered from any source distribution,  #
#    except that more "Copyright (c)" lines may be added to already existing  #
#    "Copyright (c)" lines if you have modified the software and wish to make #
#    your changes available under the same license as the original software.  #
#                                                                             #
###############################################################################

### Variables reserved for this script ########################################

pi_priv="/etc/ssl/private/boot.key"
pi_cert="/etc/ssl/certs/bot.crt"
pi_host="boot.example.com"
pi_home="/var/bozo"

pi_fifo="$pi_home/tmp/fifo"
pi_open=false
pi_stop=false
pi_udev=false

### Functions reserved for this script ########################################

pi_startWebServer() {
    echo "Removing stale GIFs and locks"
    rm -f "$pi_home"/data/hiding[0-9]*.gif
    rm -f "$pi_home/tmp/lock"

    if ! ps -e | grep udev | grep -qv grep; then
        echo "Starting udev"
        udevd --daemon
        pi_udev=true
    fi

    echo "Starting web server"
    bozohttpd -b -s -S "Introdus 1.0" -U bozo -t $pi_home -n -c /cgi-bin \
        -Z $pi_cert $pi_priv data $pi_host

    # Remember the start
    pi_open=true
}

pi_stopWebServer() {
    if $pi_udev; then
        echo "Stopping udev"
        killall udevd
    fi

    echo "Stopping web server"
    killall bozohttpd
    pi_open=false
}

### API called from the init script ###########################################

fetch_password() {
    # Prepare the CGI script...
    if ! $pi_open; then
        start_net; pi_startWebServer;
    fi

    # ...and wait for its data
    echo "Waiting for password"
    password=$(cat $pi_fifo)
    echo "Got password"
}

accept_password() {
    echo "Accepting password"
    echo "OK" > $pi_fifo;
    sleep 1; pi_stopWebServer;
}

reject_password() {
    echo "Rejecting password"
    echo "BAD" > $pi_fifo;
}

###############################################################################
