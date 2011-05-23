#!/bin/bash
#
#Author : Greg Burek
#Date : 05-18-2011
#Purpose : Setup dev.apds.co env for my use
#Comments :

set -e -x
export DEBIAN_FRONTEND=noninteractive


function die()
{
	echo -e "$@" >> /dev/console
	exit 1
}

aptitude -yq update && aptitude -yq safe-upgrade
aptitude -yq install irb libopenssl-ruby libreadline-ruby rdoc ri ruby rake ruby-dev rubygems
aptitude -yq install exuberant-ctags git-core vim-nox zsh ack
aptitude -yq install build-essential psmisc python-dev libxml2 libxml2-dev python-setuptools libssl-dev
aptitude -yq build-dep nginx

gem install github-markup redcarpet

mkdir /opt/run/
mkdir /opt/log/
mkdir /opt/log/nginx/
mkdir /opt/lock/
mkdir /opt/django-projects/
mkdir /opt/html/
sudo chmod -R 777 /opt/

useradd -m -p saB/M7hY0p7Bw gregburek -s /usr/bin/zsh
usermod -a -G adm,admin gregburek
echo "gregburek ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers

su - gregburek -c "wget --no-check-certificate https://github.com/gregburek/aws-scripts/raw/master/dev.gregburek.com/env-gregburek.sh -O - | sh"

passwd -e gregburek
exit 0



