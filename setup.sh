#!/bin/bash


apt-get update
apt-get upgrade -y

apt-get install -y gcc-4.8 gfortran-4.8 g++-4.8 make emacs openssh-server build-essential software-properties-common
sudo ln -s /usr/bin/gfortran-4.8 /usr/local/bin/gfortran
wget https://github.com/ofiwg/libfabric/releases/download/v1.15.0/libfabric-1.15.0.tar.bz2
tar xjf libfabric-1.15.0.tar.bz2
cd libfabric-1.15.0
./configure
make
make install
cd /
rm -rf libfabric-1.15.0

wget https://www.mpich.org/static/downloads/3.4/mpich-3.4.tar.gz
tar xfz mpich-3.4.tar.gz
cd mpich-3.4
CC=gcc FC=gfortran-4.8 ./configure --with-device=ch4:ofi
make
make install
cd /
rm -rf mpich-3.4

echo "/usr/local/lib" > /etc/ld.so.conf.d/libfabric.conf
ldconfig
