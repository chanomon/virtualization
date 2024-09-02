#! /bin/bash 
sudo virt-install \
  --name tonalli2 \
  --os-variant ubuntu14.04 \
  --vcpus 2 \
  --ram 2048 \
  --disk path=/var/lib/libvirt/images/tonalli2.qcow2,size=10,format=qcow2 \
  --cdrom /home/elizandro/MEGA/MEGAsync/code/kvm/ubuntu-14.04.6-server-amd64.iso \
  --network bridge=virbr0,model=virtio \
  --graphics vnc,listen=127.0.0.1,port=5903\
  --filesystem source=/home/elizandro/TONALLI/files4KVtonalli,target=mount_point,accessmode=mapped\
  --serial pty \
  --console pty,target_type=serial \
  --noreboot
  #--autoconsole
  #--extra-args='console=ttyS0,115200n8 serial'
# --user ehuipe --pass polloshermanos \
#  --addpkg gcc-4.8.4 --addpkg gcc-4.8.4 --adpkg gfortran-4.8.3\
#  --addpkg g++-4.8.4 --addpkg make --addpkg emacs --addpkg openssh\
#  --cloud-init user-data=/home/elizandro/MEGA/MEGAsync/code/kvm/cloud-init-config.yaml\
#  --extra-args='console=ttyS0,115200n8 serial'\