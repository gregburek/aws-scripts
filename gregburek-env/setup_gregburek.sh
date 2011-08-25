#!/bin/bash
#
#Author: Greg Burek
#Date: 05-18-2011
# If run as 
# su - gregburek -c "wget http://50.19.99.157/gregburek-setup.sh -O - | sh"
# as root, will setup my account properly

# Setup ssh keys
mkdir ~/.ssh
wget --no-check-certificate https://github.com/gregburek/aws-scripts/raw/master/gregburek-env/id_rsa.pub -O ~/.ssh/airy-greg.pub
cat ~/.ssh/airy-greg.pub >> ~/.ssh/authorized_keys
chmod 700 ~/.ssh;
chmod 600 ~/.ssh/authorized_keys

# Setup tmux 
wget --no-check-certificate https://github.com/gregburek/aws-scripts/raw/master/gregburek-env/tmux.conf -O ~/.tmux.conf
wget --no-check-certificate https://github.com/gregburek/aws-scripts/raw/master/gregburek-env/local.rc -O ~/.localrc

# Setup RVM and ruby
bash < <(wget https://rvm.beginrescueend.com/install/rvm -O -)
source ~/.localrc
echo 'gem: --no-ri --no-rdoc' >> ~/.gemrc
rvm install 1.8.7
rvm use 1.8.7 --default

# Setup Janus and Solarized for vim
bash < <(wget https://raw.github.com/carlhuda/janus/master/bootstrap.sh -O -)
#curl https://github.com/posterous/vim/raw/master/vimrc.local > ~/.vimrc.local

# Setup Oh My zsh! shell
mkdir ~/.zsh
wget --no-check-certificate https://github.com/gregburek/aws-scripts/raw/master/gregburek-env/zsh/oh-my-zshrc -O ~/.zsh/oh-my-zshrc
wget --no-check-certificate https://github.com/gregburek/aws-scripts/raw/master/gregburek-env/zsh/zshrc -O ~/.zsh/zshrc
wget --no-check-certificate https://github.com/gregburek/aws-scripts/raw/master/gregburek-env/zsh/aliases -O ~/.zsh/aliases
git clone git://github.com/robbyrussell/oh-my-zsh.git ~/.oh-my-zsh
ln -s ~/.zsh/zshrc ~/.zshrc

# Setup git-flow
sudo bash < <(wget --no-check-certificate -q -O - https://github.com/nvie/gitflow/raw/develop/contrib/gitflow-installer.sh )
#sudo wget -O /usr/share/zsh/functions/Completion/Unix/_git http://zsh.git.sourceforge.net/git/gitweb.cgi?p=zsh/zsh;a=blob_plain;f=Completion/Unix/Command/_git;hb=HEAD

# Setup gitconfig
wget --no-check-certificate https://github.com/gregburek/aws-scripts/raw/master/gregburek-env/git-config -O ~/.gitconfig

# Setup python tools
sudo easy_install pip
sudo easy_install virtualenv
# echo 'export WORKON_HOME=$HOME/.virtualenvs' >> ~/.zprofile
# echo 'source /usr/local/bin/virtualenvwrapper.sh' >> ~/.zprofile

# Setup reminder 
echo 'echo "Remember to run ssh-keygen -t rsa -C \"your_email@youremail.com\""' >> ~/.zprofile


