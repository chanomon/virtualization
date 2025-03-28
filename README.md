# virtualization
virtualization of SO
In his 1973 thesis, "Architectural Principles for Virtual Computer Systems," Robert P. Goldberg classified two types of hypervisor:
### Type-1, native or bare-metal hypervisors
These hypervisors run directly on the host's hardware to control the hardware and to manage guest operating systems. For this reason, they are sometimes called bare-metal hypervisors. The first hypervisors, which IBM developed in the 1960s, were native hypervisors. These included the test software SIMMON and the CP/CMS operating system, the predecessor of IBM's VM family of virtual machine operating systems. Examples of Type-1 hypervisor include Hyper-V, Xen and VMware ESXi.
![image](https://upload.wikimedia.org/wikipedia/commons/9/9e/Hyperviseur.svg)

### Type-2 or hosted hypervisors
These hypervisors run on a conventional operating system (OS) just as other computer programs do. A virtual machine monitor runs as a process on the host, such as VirtualBox. Type-2 hypervisors abstract guest operating systems from the host operating system, effectively creating an isolated system that can be interacted with by the host. Examples of Type-2 hypervisor include VirtualBox and VMware Workstation.
The distinction between these two types is not always clear. For instance, KVM and bhyve are kernel modules that effectively convert the host operating system to a type-1 hypervisor.
## Kernel Virtual Machine
Kernel-based Virtual Machines (KVM) are an open-source virtualization technology built into Linux®. With them, you can transform Linux into a hypervisor that allows a host machine to run multiple isolated virtual environments called virtual machines (VMs) or guests.

KVMs are part of Linux. Therefore, if you have a version of Linux 2.6.20 or later, you already have them available. They were first announced in 2006, and a year later they were incorporated into the mainline Linux kernel. Since they are part of the current Linux code, they immediately receive all the improvements, fixes, and new features of the system without requiring any additional engineering.
KVM requires a CPU with virtualization extensions:
- Intel® Virtualization Technology (Intel® VT)
    - CPU flag is vmx (Virtual Machine Extensions).
- AMD virtualization (AMD-V)
    - CPU flag is svm (Secure Virtual Machine).
Type in your terminal:
```console
egrep --count '^flags.*(vmx|svm)' /proc/cpuinfo
```
If output is 0, your system does not support the relevant virtualization extensions or disabled on BIOS. You can still use QEMU/KVM, but the emulator will fall back to software virtualization, which is much slower.
### Installing Virtualization Packages (Ubuntu)
```console
 apt-get install \
    bridge-utils \
    qemu-kvm \
    virt-manager
```
### (CentOS)
```console
 yum install \
    libvirt \
    qemu-kvm \
    virt-install \
    virt-install \
    virt-manager
```

### Enable libvirtd Service
The libvirtd service is a server side daemon and driver required to manage the virtualization capabilities of the KVM hypervisor.
Start libvirtd service and enable it on boot.
```systemctl start libvirtd```

```systemctl enable libvirtd```
### Verify KVM Kernel Modules
Verify that the KVM kernel modules are properly loaded.
```lsmod | egrep 'kvm_*(amd|intel)'```
If output contains kvm_intel or kvm_amd, KVM is properly configured.
### Append Groups to Manage KVM
Append current user to kvm and libvirt groups to create and manage virtual machines.
```usermod --append --groups=kvm,libvirt ${USER}```

```cat /etc/group | egrep "^(kvm|libvirt).*${USER}"```
Log out and log in again to apply this modification.
### Update QEMU Configuration
```console 
cp /etc/libvirt/qemu.conf /etc/libvirt/qemu.conf.original
sed --in-place \
    "s,\#user = \"root\",\#user = \"${USER}\",g" \
    /etc/libvirt/qemu.conf
sed --in-place \
    "s,\#group = \"root\",\#group = \"libvirt\",g" \
    /etc/libvirt/qemu.conf
diff --unified \
    /etc/libvirt/qemu.conf.original \
    /etc/libvirt/qemu.conf
systemctl restart libvirtd
```


### Installing  a virtual os

## This config worked for me to then display system with ```virt-viewer VMname ``` command
```
# Replace al the <fields>, make sure you don't leave any arrow <>
sudo virt-install \
  --name <name for the virtual machine> \
  --os-variant <for example ubuntu14.04> \
  --vcpus <numberofcpus> \
  --ram <in Mb, remember, 1Gb = 1024 Mb> \
  --disk path=/var/lib/libvirt/images/nameoftheVM.qcow2,size=30,format=qcow2 \ ## size is the number of Gb you want to give of space to your VM 
  --cdrom /path/to/your/osImage.iso \
  --network bridge=virbr0,model=virtio \
  --graphics vnc,listen=127.0.0.1,port=5902\
  --noreboot
```
### If after installing a VM you cannot see the console after ```virsh console VM```.....
You probably need to configure the installation on th VM, use ```virt-manager``` command to set up the configuration.
If you cannot access with ```virsh console nameofVM```, use ```virt-manager```and follow the next section.

```virsh console``` opens a connection to the guest's primary serial port. This will only show any output / accept input, if there is something in the guest OS attached to the other end of the serial port (ie a getty process). IOW, it hasn't hung, there just isn't anything in your guest using the serial port to respond to.

OS using systemd would normally automatically spawn a getty process, if there is no graphical console available (ie no VGA device). If you do have a graphical console configured, then try connecting to that instead. Typically you'd use VNC/SPICE clients to connect to a graphical console, such as ```virt-viewer vm1```


### To configure serial port for future ```virsh console``` connections:
On the VM, add an Upstart task as ```/etc/init/ttyS0.conf```, containing the following:
```
# ttyS0 - getty
#
# This service maintains a getty on ttyS0 from the point the system is
# started until it is shut down again.

start on stopped rc or RUNLEVEL=[2345]
stop on runlevel [!2345]

respawn
exec /sbin/getty -L 115200 ttyS0 vt102
```
Start it on the VM this way:
```
$ sudo start ttyS0
```
Maybe you should reboot the vm from the host with:

```
& virsh reboot nameofVM
```

After that you should be able to connect to the serial console from the host with:
```
virsh console nameofVM
```
Don't forget to press Enter once connected.
### Virtualization and set up for tonalli
For virtualization of tonalli system, execute ```sudo ./virt-install-2.sh``` make sure you and file have necesary permissions.
make necesary changes if you need

Then enter in to the virtual machine and execute "sudo ./setup.sh". Remember the virtual machin instalation, this script should be loaded in  ```source=/path/inside/host``` so you'll locate the file in ```target=/path/inside/guest``` inside the VM.


### Start virtual machine (domain)
```console
virsh console <domain>
```
### Gracefully shutdown a domain
```console
virsh shutdown
```
### help
```console
virsh --help
```

### Use next link for usefull commands
[sorry but I got tired of putting all of these usefull commands](https://www.basezap.com/20-virsh-commands-for-managing-vms/#:~:text=Virsh%20is%20a%20powerful%20command,KVM%2C%20Xen%2C%20and%20more.)

# Enabling File Sharing in a Virtual Machine

## 1. Edit the Virtual Machine Configuration

On the **host**, edit the VM configuration:

```bash
virsh edit your-vm-name
```

Find the `<devices>` section and add the following:

```xml
<filesystem type='mount' accessmode='passthrough'>
    <driver type='path'/>
    <source dir='/path/on/host'/>
    <target dir='shared'/> #this is the name of the target, not a path
</filesystem>
```

Save and exit the editor.

## 2. Restart the Virtual Machine

```bash
virsh shutdown your-vm-name
virsh start your-vm-name
```

## 3. Install Required Packages on the VM

Inside the **virtual machine (VM)**, install the necessary packages:

```bash
sudo apt-get update
sudo apt-get install virtiofs-utils
```

If the package is unavailable, try:

```bash
sudo apt-get install nfs-common
```

## 4. Mount the Shared Directory

Inside the **VM**, run the following command:

```bash
sudo mount -t 9p -o trans=virtio shared /home/your-user/shared-folder  #remember the name of your target (shared) in the xml you edited on the host
```

Check if the files from the **host** are accessible:

```bash
ls /home/your-user/shared-folder
```

If you see the files from the host, the shared folder is successfully mounted! 🚀

## 5. Automate Mounting on Startup

To mount the shared directory automatically on VM startup, add the following line to `/etc/fstab`:

```
shared /home/your-user/shared-folder 9p trans=virtio,version=9p2000.L,rw 0 0
```



## Troubleshooting

If you encounter errors, ensure:

1. The `<filesystem>` entry exists in `virsh edit your-vm-name`.
2. The VM was restarted after configuration changes.
3. The `9p` kernel module is loaded:

   ```bash
   lsmod | grep 9p
   ```

4. The host directory exists (`/path/on/host`).
5. The VM user has permission to access `/home/your-user/shared-folder`.

---

This guide helps you enable file sharing in a VM running Ubuntu 14.04 using `9pfs`. If you need further assistance, feel free to ask. 🚀



## References:

1 Goldberg, Robert P. (1973). Architectural Principles for Virtual Computer Systems (PDF) (Technical report). Harvard University. ESD-TR-73-105.
2 https://sheeeng.github.io/getting-started-with-kernel-based-virtual-machine-presentation
3 Graziano, Charles (2011). A performance analysis of Xen and KVM hypervisors for hosting the Xen Worlds Project (MS thesis). Iowa State University. doi:10.31274/etd-180810-2322. hdl:20.500.12876/26405. Retrieved October 16, 2022.
4 https://qemu.readthedocs.io/en/latest/system/devices/virtiofs.html
