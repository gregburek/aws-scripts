################################################################
#
# Amazon EC2 PostGIS 1.5 on RAID10,f2 EBS Array Build Script
#
# Complete Rip off of:
# http://github.com/tokumine/ebs_raid_postgis/blob/master/build.sh
# http://alestic.com/2009/06/ec2-ebs-raid
# http://biodivertido.blogspot.com/2009/10/install-postgresql-84-and-postgis-140.html
#
# Additional glue by Simon Tokumine, 15/11/09
# Additions by Sophia Parafina, 10/08/10
#        added additional repos to sources.list
#        custom postgis, proj4, geos build
#        added packages for building postgis, proj4, geos
#        configured to build RAID10
#        customized for Canonical Ubuntu AMIs
#
# INSTALL ON ALESTIC UBUNTU AMI'S - http://alestic.com/
# I ORIGINALLY USED THE 32-bit AMI: ami-ccf615a5 (jaunty)
#
# NOTE, THIS IS ONLY FOR TESTING
################################################################

################################################################
#SETUP
#Please complete the parts that are in []'s (over writing the []'s)
#then just run the script on the server
################################################################

# change this to you keypair and cert
export EC2_PRIVATE_KEY=~[key.pem]
export EC2_CERT=~[cert.pem]
# change this to your instance
instanceid=[my-instance]
# change to the instance's availability zone
availability_zone=us-east-1d
# builds out RAID10, so size of RAID=volumes*size/2,
#   change this to your needs
volumes=[10]
size=[100]
# change to your mount point
mountpoint=[/mnt/vol1]
# change to a device
raid_array_location=[/dev/md0]
raid_level=10
raid_layout=f2
raid_chunk=256
# change to your password
postgres_password=[postgres]
# create a postgis template
db_name=template_postgis
################################################################

#####
# TODO
#
# UNMOUNT AND DETACH/DESTROY EBS & TERMINATE EC2
#
#####


################################################################
# CREATE EBS VOLUMES & RAID ARRAY
################################################################
sudo sh -c "echo ' ' >> /etc/apt/sources.list"
sudo sh -c "echo 'deb http://us.archive.ubuntu.com/ubuntu/ lucid multiverse' >> /etc/apt/sources.list"
sudo sh -c "echo 'deb-src http://us.archive.ubuntu.com/ubuntu/ lucid multiverse' >> /etc/apt/sources.list"
sudo sh -c "echo 'deb http://us.archive.ubuntu.com/ubuntu/ lucid-updates multiverse' >> /etc/apt/sources.list"
sudo sh -c "echo 'deb-src http://us.archive.ubuntu.com/ubuntu/ lucid-updates multiverse' >> /etc/apt/sources.list"
# this is specific for lucid only
sudo sh -c "echo 'deb http://archive.canonical.com/ lucid partner' >> /etc/apt/sources.list"
sudo apt-get update
sudo apt-get -y install ec2-api-tools
sudo apt-get -y install sun-java6-bin
export JAVA_HOME=/usr/lib/jvm/java-6-sun

devices=$(perl -e 'for$i("h".."k"){for$j("",1..15){print"/dev/sd$i$j\n"}}'|
head -$volumes)
devicearray=($devices)
volumeids=
i=1
while [ $i -le $volumes ]; do
   volumeid=$(ec2-create-volume -z $availability_zone --size $size | cut -f2)
   echo "$i: created $volumeid"
   device=${devicearray[$(($i-1))]}
   echo $volumeid
   ec2-attach-volume $volumeid -i $instanceid -d $device
   volumeids="$volumeids $volumeid"
   let i=i+1
done
echo "volumeids='$volumeids'"

sudo apt-get update &&
sudo apt-get install -y mdadm xfsprogs

devices=$(perl -e 'for$i("h".."k"){for$j("",1..15){print"/dev/sd$i$j\n"}}'|
head -$volumes)


#builds out RAID10
yes | sudo mdadm \
--create $raid_array_location \
--chunk=$raid_chunk \
--level=$raid_level \
--layout=$raid_layout \
--metadata=1.1 \
--raid-devices $volumes \
$devices

echo DEVICE $devices | sudo tee /etc/mdadm.conf
sudo mdadm --detail --scan | sudo tee -a /etc/mdadm.conf

sudo mkfs.xfs $raid_array_location

echo "$raid_array_location $mountpoint xfs noatime 0 0" | sudo tee -a /etc/fstab
sudo mkdir $mountpoint
sudo mount $mountpoint

################################################################
# INSTALL POSTGRES, POSTGIS & SETUP DATABASE ON RAID VOLUME
################################################################
#echo " " >> /etc/apt/sources.list
#echo "deb http://ppa.launchpad.net/pitti/postgresql/ubuntu jaunty main" >> /etc/apt/sources.list
#echo "deb-src http://ppa.launchpad.net/pitti/postgresql/ubuntu jaunty main" >> /etc/apt/sources.list
#sudo apt-key adv --keyserver keyserver.ubuntu.com --recv-keys 8683D8A2
#sudo apt-get update
sudo apt-get install libxml2-dev

sudo apt-get -y install postgresql-8.4 postgresql-server-dev-8.4 postgresql-contrib-8.4 libpq-dev
sudo /etc/init.d/postgresql-8.4 stop

sudo mkdir $mountpoint/data
sudo chmod -R 700 $mountpoint/data
sudo chown -R postgres.postgres $mountpoint/data
sudo -u postgres /usr/lib/postgresql/8.4/bin/initdb -D $mountpoint/data
sudo sed -i.bak -e 's/port = 5433/port = 5432/' /etc/postgresql/8.4/main/postgresql.conf
sudo sed -i.bak -e "s@\/var\/lib\/postgresql\/8.4\/main@$mountpoint\/data@" /etc/postgresql/8.4/main/postgresql.conf
sudo sed -i.bak -e 's/ssl = true/#ssl = true/' /etc/postgresql/8.4/main/postgresql.conf
sudo /etc/init.d/postgresql-8.4 start
cd /tmp
sudo apt-get -y install bzip2
sudo apt-get -y install g++
sudo apt-get -y install checkinstall

# install geos
wget http://download.osgeo.org/geos/geos-3.2.2.tar.bz2
bunzip2 geos-3.2.2.tar.bz2
tar xvf geos-3.2.2.tar
cd geos-3.2.2
./configure
make && sudo checkinstall --pkgname geos --pkgversion 3.2.2-src --default

# install proj
cd ../
wget http://download.osgeo.org/proj/proj-4.7.0.tar.gz
tar xvfz proj-4.7.0.tar.gz
cd proj-4.7.0
./configure
make && sudo checkinstall --pkgname proj4 --pkgversion 4.70-src --default
cd ../

# install postgis as a package for easier removal if needed
wget http://postgis.refractions.net/download/postgis-1.5.2.tar.gz
tar xvfz postgis-1.5.2.tar.gz
cd postgis-1.5.2
./configure
make && sudo checkinstall --pkgname postgis --pkgversion 1.5.2-src --default # remove with dpkg -r postgis
sudo /sbin/ldconfig

# config template_postgis
sudo -u postgres psql -c"ALTER user postgres WITH PASSWORD '$postgres_password'"
sudo -u postgres createdb $db_name
sudo -u postgres createlang -d$db_name plpgsql
sudo -u postgres psql -d$db_name -f /usr/share/postgresql/8.4/contrib/postgis-1.5/postgis.sql
sudo -u postgres psql -d$db_name -f /usr/share/postgresql/8.4/contrib/postgis-1.5/spatial_ref_sys.sql
sudo -u postgres psql -d$db_name -c"select postgis_lib_version();"

# osm
# install osm2pgsql
cd /tmp
sudo apt-get -y install subversion
sudo apt-get -y install autoconf
sudo apt-get -y install libbz2-dev
svn export http://svn.openstreetmap.org/applications/utils/export/osm2pgsql/
cd osm2pgsql
./autogen.sh
./configure
sed -i 's/-g -O2/-O2 -march=native -fomit-frame-pointer/' Makefile
make
sudo make install

# create osm database
# sudo -u postgres createdb -T template_postgis osm