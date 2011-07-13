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
wget --no-check-certificate -q -O - https://github.com/gregburek/janus/raw/master/bootstrap.sh | sh
#curl https://github.com/posterous/vim/raw/master/vimrc.local > ~/.vimrc.local

# Setup Oh My zsh! shell
mkdir ~/.zsh
wget --no-check-certificate https://github.com/gregburek/aws-scripts/raw/master/dev.gregburek.com/zsh/oh-my-zshrc -O ~/.zsh/oh-my-zshrc
wget --no-check-certificate https://github.com/gregburek/aws-scripts/raw/master/dev.gregburek.com/zsh/zshrc -O ~/.zsh/zshrc
wget --no-check-certificate https://github.com/gregburek/aws-scripts/raw/master/dev.gregburek.com/zsh/aliases -O ~/.zsh/aliases
git clone git://github.com/robbyrussell/oh-my-zsh.git ~/.oh-my-zsh
ln -s ~/.zsh/zshrc ~/.zshrc

# Setup screen to run at login and screen to use ^O as the command key
wget --no-check-certificate https://github.com/gregburek/aws-scripts/raw/master/dev.gregburek.com/zprofile -O ~/.zprofile

# Setup git-flow
wget --no-check-certificate -q -O - https://github.com/nvie/gitflow/raw/develop/contrib/gitflow-installer.sh | sudo sh
sudo wget -O /usr/share/zsh/functions/Completion/Unix/_git http://zsh.git.sourceforge.net/git/gitweb.cgi?p=zsh/zsh;a=blob_plain;f=Completion/Unix/Command/_git;hb=HEAD

# Setup gitconfig
wget --no-check-certificate https://github.com/gregburek/aws-scripts/raw/master/dev.gregburek.com/git-config -O ~/.gitconfig

# Setup python tools
sudo easy_install virtualenv

# echo 'export WORKON_HOME=$HOME/.virtualenvs' >> ~/.zprofile
# echo 'source /usr/local/bin/virtualenvwrapper.sh' >> ~/.zprofile

# Setup reminder 
echo 'echo "Remember to run ssh-keygen -t rsa -C \"your_email@youremail.com\""' >> ~/.zprofile

# Start setup server functions

mkdir /opt/run/
mkdir /opt/log/
mkdir /opt/log/nginx/
mkdir /opt/lock/
mkdir /opt/apps/
mkdir /opt/source/
mkdir /opt/conf/
mkdir /opt/conf/nginx/

cd /opt/apps
virtualenv --no-site-packages soapnotes-env
cd /opt/apps/soapnotes-env
git clone git://github.com/gregburek/soapnotes.git site
source bin/activate
pip install django south distribute nose

cd /opt/source/
wget http://projects.unbit.it/downloads/uwsgi-0.9.8.1.tar.gz
tar -xzf uwsgi-*.tar.gz
cd uwsgi-*
make
sudo mv uwsgi /usr/local/lib/
sudo ln -s /usr/local/lib/uwsgi /usr/local/bin/uwsgi
sudo ln -s /opt/apps/soapnotes-env/site/conf/upstart-uwsgi.conf /etc/init/uwsgi.conf

cd /opt/source/
wget http://nginx.org/download/nginx-1.0.4.tar.gz
tar -xzf nginx-*.tar.gz
cd nginx-*
touch /opt/run/nginx.pid
touch /opt/lock/nginx.lock
touch /opt/log/nginx/error.log
sudo mkdir /var/tmp/nginx
./configure --conf-path=/opt/conf/nginx/nginx.conf \
--http-log-path=/opt/log/nginx/access.log \
--error-log-path=/opt/log/nginx/error.log \
--pid-path=/opt/run/nginx.pid \
--lock-path=/opt/lock/nginx.lock \
--sbin-path=/usr/sbin \
--user=www-data \
--group=www-data \
--with-http_stub_status_module \
--with-ipv6 \
--with-http_ssl_module \
--with-http_realip_module \
--with-sha1-asm \
--with-sha1=/usr/lib \
--http-fastcgi-temp-path=/var/tmp/nginx/fcgi/ \
--http-proxy-temp-path=/var/tmp/nginx/proxy/ \
--http-client-body-temp-path=/var/tmp/nginx/client/ \
--with-http_geoip_module \
--with-http_gzip_static_module \
--with-http_sub_module \
--with-http_addition_module \
--with-file-aio \
--without-mail_smtp_module

make 
sudo make install

sudo ln -s /opt/apps/soapnotes-env/site/conf/upstart-nginx.conf /etc/init/nginx.conf

sudo mkdir /opt/conf/nginx/{sites-available,sites-enabled}
sudo ln -s /opt/apps/soapnotes-env/site/conf/soapnotes_nginx.conf /opt/conf/nginx/sites-available/soapnotes_nginx.conf
sudo ln -s /opt/conf/nginx/sites-available/soapnotes_nginx.conf /opt/conf/nginx/sites-enabled/soapnotes_nginx.conf

sudo rm -f /opt/conf/nginx/nginx.conf
sudo ln -s /opt/apps/soapnotes-env/site/conf/nginx.conf /opt/conf/nginx/nginx.conf

sudo chmod 755 /opt

sudo initctl reload-configuration
sudo start uwsgi
sudo start nginx

