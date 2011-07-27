#!/bin/bash
#
#Author : Greg Burek
#Date : 05-18-2011
#Purpose : Setup dev.apds.co env for my use
#Comments :

exec > >(tee /var/log/user-data.log|logger -t user-data -s 2>/dev/console) 2>&1

set -e -x
export DEBIAN_FRONTEND=noninteractive


function die()
{
	echo -e "$@" >> /dev/console
	exit 1
}

aptitude -yq update && aptitude -yq safe-upgrade
aptitude -yq install libopenssl-ruby libreadline-ruby ruby rake ruby-dev rubygems

aptitude -yq install exuberant-ctags git-core vim-nox zsh ack
aptitude -yq install build-essential psmisc python-dev libxml2 libxml2-dev python-setuptools libssl-dev
aptitude -yq build-dep nginx

gem install github-markup redcarpet


useradd -m -p saB/M7hY0p7Bw gregburek -s /usr/bin/zsh
usermod -a -G adm,admin gregburek
echo "gregburek ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers

mkdir /opt/
chown gregburek:gregburek /opt

su - gregburek -c "wget --no-check-certificate https://github.com/gregburek/aws-scripts/raw/master/gregburek-env/setup_gregburek.sh -O - | sh"

passwd -e gregburek
exit 0



