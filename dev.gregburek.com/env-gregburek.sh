#!/bin/bash
#
#Author: Greg Burek
#Date: 05-18-2011
# If run as 
# su - gregburek -c "wget http://50.19.99.157/gregburek-setup.sh -O - | sh"
# as root, will setup my account properly

# Setup ssh keys
mkdir ~/.ssh
wget --no-check-certificate https://github.com/gregburek/aws-scripts/raw/master/dev.gregburek.com/id_rsa.pub -O ~/.ssh/airy-greg.pub
cat ~/.ssh/airy-greg.pub >> ~/.ssh/authorized_keys
chmod 700 ~/.ssh;
chmod 600 ~/.ssh/authorized_keys

# Setup Janus and Solarized for vim
curl https://github.com/gregburek/janus/raw/master/bootstrap.sh -o - | sh
curl https://github.com/posterous/vim/raw/master/vimrc.local > ~/.vimrc.local

# Setup Oh My zsh! shell
mkdir ~/.zsh
wget --no-check-certificate https://github.com/gregburek/aws-scripts/raw/master/dev.gregburek.com/zsh/oh-my-zsh -O ~/.zsh/oh-my-zsh
wget --no-check-certificate https://github.com/gregburek/aws-scripts/raw/master/dev.gregburek.com/zsh/zshrc -O ~/.zsh/zshrc
wget --no-check-certificate https://github.com/gregburek/aws-scripts/raw/master/dev.gregburek.com/zsh/aliases -O ~/.zsh/aliases
git clone git://github.com/robbyrussell/oh-my-zsh.git ~/.oh-my-zsh
ln -s ~/.zsh/zshrc ~/.zshrc

# Setup screen to run at login and screen to use ^O as the command key
wget --no-check-certificate https://github.com/gregburek/aws-scripts/raw/master/dev.gregburek.com/zprofile -O ~/.zprofile

# Setup git-flow
wget --no-check-certificate -q -O - https://github.com/nvie/gitflow/raw/develop/contrib/gitflow-installer.sh | sudo sh
sudo wget -O /usr/share/zsh/functions/Completion/Unix/_git http://zsh.git.sourceforge.net/git/gitweb.cgi?p=zsh/zsh;a=blob_plain;f=Completion/Unix/Command/_git;hb=HEAD

# Setup python tools
sudo easy_install pip
sudo pip install -U virtualenvwrapper
echo 'export WORKON_HOME=$HOME/.virtualenvs' >> ~/.zprofile
echo 'source /usr/local/bin/virtualenvwrapper.sh' >> ~/.zprofile
