# virtualization
virtualization of SO
In his 1973 thesis, "Architectural Principles for Virtual Computer Systems," Robert P. Goldberg classified two types of hypervisor:[1]
### Type-1, native or bare-metal hypervisors
These hypervisors run directly on the host's hardware to control the hardware and to manage guest operating systems. For this reason, they are sometimes called bare-metal hypervisors. The first hypervisors, which IBM developed in the 1960s, were native hypervisors.[5] These included the test software SIMMON and the CP/CMS operating system, the predecessor of IBM's VM family of virtual machine operating systems. Examples of Type-1 hypervisor include Hyper-V, Xen and VMware ESXi.
![image](https://upload.wikimedia.org/wikipedia/commons/9/9e/Hyperviseur.svg)

### Type-2 or hosted hypervisors
These hypervisors run on a conventional operating system (OS) just as other computer programs do. A virtual machine monitor runs as a process on the host, such as VirtualBox. Type-2 hypervisors abstract guest operating systems from the host operating system, effectively creating an isolated system that can be interacted with by the host. Examples of Type-2 hypervisor include VirtualBox and VMware Workstation.
The distinction between these two types is not always clear. For instance, KVM and bhyve are kernel modules[6] that effectively convert the host operating system to a type-1 hypervisor.[7]
## Kernel Virtual Machine
Kernel-based Virtual Machines (KVM) are an open-source virtualization technology built into Linux®. With them, you can transform Linux into a hypervisor that allows a host machine to run multiple isolated virtual environments called virtual machines (VMs) or guests.

KVMs are part of Linux. Therefore, if you have a version of Linux 2.6.20 or later, you already have them available. They were first announced in 2006, and a year later they were incorporated into the mainline Linux kernel. Since they are part of the current Linux code, they immediately receive all the improvements, fixes, and new features of the system without requiring any additional engineering.
KVM requires a CPU with virtualization extensions:
- Intel® Virtualization Technology (Intel® VT)
    - CPU flag is vmx (Virtual Machine Extensions).
- AMD virtualization (AMD-V)
    - CPU flag is svm (Secure Virtual Machine).
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
### Installing  a virtual os
# virt-install \ 
```console
  --name nameofvirtualmachine \ 
  --memory 2048 \ # The amount of memory (RAM) to allocate to the guest, in MiB. 
  --vcpus 2 \ #Number if virtual CPUs
  --disk size=8 \ # In Gb
  --cdrom /path/to/OS.iso \ 
  --os-variant rhel7 
```
### If after installing a VM you cannot see the console after ```virsh console VM```.....


```virsh console``` opens a connection to the guest's primary serial port. This will only show any output / accept input, if there is something in the guest OS attached to the other end of the serial port (ie a getty process). IOW, it hasn't hung, there just isn't anything in your guest using the serial port to respond to.

OS using systemd would normally automatically spawn a getty process, if there is no graphical console available (ie no VGA device). If you do have a graphical console configured, then try connecting to that instead. Typically you'd use VNC/SPICE clients to connect to a graphical console, such as ```virt-viewer vm1```


### Start virtual machine (domain)
```console
virsh console
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

## References:

1 Goldberg, Robert P. (1973). Architectural Principles for Virtual Computer Systems (PDF) (Technical report). Harvard University. ESD-TR-73-105.
7 Graziano, Charles (2011). A performance analysis of Xen and KVM hypervisors for hosting the Xen Worlds Project (MS thesis). Iowa State University. doi:10.31274/etd-180810-2322. hdl:20.500.12876/26405. Retrieved October 16, 2022.
