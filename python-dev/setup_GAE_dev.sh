#!/bin/bash
#
#Author: Greg Burek
#Date: Nov 10 2011

run_output=$(ec2-run-instances ami-e358958a -k gregburek-ec2-keypair -t t1.micro --region us-east-1 )
instance_id=$(echo $run_output |  awk '/INSTANCE/{print $2}')
ip_address=$(echo $run_output |  awk '/INSTANCE/{print $4}')
while [$ip_address == 'pending']; do
  ip_address=$(ec2-describe-instances | grep $instance_id | awk '/INSTANCE/{print $4}')
done
echo "ec2kill $instance_id" | at now + 360 minutes
ssh ubuntu@$ip_address -i ~/.ec2/gregburek-ec2-keypair.pem 



sudo add-apt-repository ppa:fkrull/deadsnakes
sudo apt-get update
sudo apt-get install python2.5 vim-nox rake git rubygems1.8 exuberant-ctags zsh

# Install oh-my-zsh
sudo chsh -s zsh ubuntu
git clone git://github.com/robbyrussell/oh-my-zsh.git ~/.oh-my-zsh
cp ~/.oh-my-zsh/templates/zshrc.zsh-template ~/.zshrc
wget http://googleappengine.googlecode.com/files/google_appengine_1.6.0.zip

# Setup Janus for vim
bash < <(wget https://raw.github.com/carlhuda/janus/master/bootstrap.sh -O -)

# Setup gitconfig
wget --no-check-certificate https://github.com/gregburek/aws-scripts/raw/master/gregburek-env/git-config -O ~/.gitconfig



