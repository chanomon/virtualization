#! /bin/bash 

sudo virt-install \
  --name tonalli \
  --os-variant ubuntu14.04 \
  --vcpus 3 \
  --ram 2048 \
  --disk path=/var/lib/libvirt/images/tonalli.qcow2,size=30,format=qcow2 \
  --cdrom /home/elizandro/MEGA/MEGAsync/code/kvm/ubuntu-14.04.6-server-amd64.iso \
  --network bridge=virbr0,model=virtio \
  --graphics vnc,listen=127.0.0.1,port=5903\
  --noreboot
  #--autoconsole
  #--extra-args='console=ttyS0,115200n8 serial'
