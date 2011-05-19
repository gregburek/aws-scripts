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

apt-get update && apt-get upgrade -y -q
apt-get -y -q install irb libopenssl-ruby libreadline-ruby rdoc ri ruby rake ruby-dev rubygems
apt-get -y -q install exuberant-ctags git-core vim-nox zsh
apt-get -y -q install build-essential psmisc python-dev libxml2 libxml2-dev python-setuptools libssl-dev
apt-get -y -q build-dep nginx

gem install github-markup redcarpet

mkdir /opt/run/
mkdir /opt/log/
mkdir /opt/log/nginx/
mkdir /opt/lock/
mkdir /opt/django-projects/
mkdir /opt/html/
sudo chmod -R 777 /opt/

useradd -m -p saB/M7hY0p7Bw gregburek -s /usr/bin/zsh
passwd -e gregburek
usermod -a -G adm,admin gregburek
echo "gregburek  ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers

su - gregburek -c "wget https://github.com/gregburek/aws-scripts/raw/master/dev.gregburek.com/env-gregburek.sh -O - | sh"

exit 0



