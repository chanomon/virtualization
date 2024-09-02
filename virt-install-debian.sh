sudo virt-install     --name Debian10 \
     --os-variant debian10\
     --description 'Debian 10'\
     --vcpus 2 --ram 2048\
     --location     https://ftp.debian.org/debian/dists/stable/main/installer-amd64\
     --network bridge=virbr0\
     --graphics vnc,listen=127.0.0.1,port=5901\
     --noreboot\
     --noautoconsole\
     --extra-args 'console=ttyS0,115200n8 serial'
