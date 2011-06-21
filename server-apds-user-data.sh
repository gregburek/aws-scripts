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
mkdir /opt/apps/
mkdir /opt/html/
mkdir /opt/source/
cd /opt/source/

wget http://projects.unbit.it/downloads/uwsgi-0.9.8.tar.gz
tar -xzf uwsgi-*.tar.gz
cd uwsgi-*
make
mv uwsgi /usr/local/lib/
ln -s /usr/local/lib/uwsgi /usr/local/bin/uwsgi
cd /opt/source/

wget http://nginx.org/download/nginx-1.0.4.tar.gz
tar -xzf nginx-*.tar.gz
cd nginx-*
touch /opt/run/nginx.pid
touch /opt/lock/nginx.lock
touch /opt/log/nginx/error.log
./configure --conf-path=/etc/nginx/nginx.conf \
--error-log-path=/opt/log/nginx/error.log \
--pid-path=/opt/run/nginx.pid \
--lock-path=/opt/lock/nginx.lock \
--sbin-path=/usr/sbin \
--with-http_ssl_module

make 
make install
wget -O /etc/init/nginx.conf http://wiki.nginx.org/index.php?title=Upstart&action=raw&anchor=nginx
#chmod -R 777 /opt/

useradd -m -p saB/M7hY0p7Bw gregburek -s /usr/bin/zsh
usermod -a -G adm,admin gregburek
echo "gregburek ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers

su - gregburek -c "wget --no-check-certificate https://github.com/gregburek/aws-scripts/raw/master/dev.gregburek.com/env-gregburek.sh -O - | sh"

passwd -e gregburek
exit 0



