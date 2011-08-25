#!/bin/bash
#
#Author : Greg Burek
#Date : 05-18-2011
#Purpose : Setup dev.apds.co env for my use
#Comments :

# Necessary for complete logging. Stock User-Data logs are capped and cut out early
exec > >(tee /var/log/user-data.log|logger -t user-data -s 2>/dev/console) 2>&1

set -e -x
export DEBIAN_FRONTEND=noninteractive

# Adds ec2-api-tool repo
sudo apt-add-repository ppa:awstools-dev/awstools
sudo aptitude -yq update && sudo aptitude -yq safe-upgrade
sudo aptitude -yq install ec2-api-tools

# recommended packages for ruby and rails for ruby and rails
sudo aptitude -yq install build-essential bison openssl libreadline6
sudo aptitude -yq install libreadline6-dev curl git-core zlib1gz lib1g-dev
sudo aptitude -yq install libssl-dev libyaml-dev libsqlite3-0 libsqlite3-dev sqlite3
sudo aptitude -yq install libxml2-dev libxslt-dev autoconf

sudo aptitude -yq install exuberant-ctags git-core vim-nox zsh ack curl tmux
sudo aptitude -yq install build-essential psmisc python-dev libxml2 libxml2-dev python-setuptools libssl-dev
sudo aptitude -yq build-dep nginx

#sudo gem install github-markup redcarpet


sudo useradd -m -p saB/M7hY0p7Bw gregburek -s /usr/bin/zsh
sudo usermod -a -G adm,admin gregburek
echo "gregburek ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers

# mkdir /opt/
sudo chown gregburek:gregburek /opt

su - gregburek -c "bash < <(wget --no-check-certificate https://github.com/gregburek/aws-scripts/raw/master/gregburek-env/setup_gregburek.sh -O -)"

passwd -e gregburek
exit 0



