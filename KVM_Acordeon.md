# KVM — Acordeón de comandos y plantillas

---

## 1. Ciclo de vida de VMs

### Estado y arranque

```bash
sudo virsh list --all                          # Lista todas las VMs con su estado
sudo virsh start <vm>                          # Arrancar una VM
sudo virsh shutdown <vm>                       # Apagado limpio (graceful)
sudo virsh destroy <vm>                        # Apagado forzado (kill)
sudo virsh reboot <vm>                         # Reiniciar VM
sudo virsh suspend <vm>                        # Pausar VM (guarda en RAM)
sudo virsh resume <vm>                         # Reanudar VM pausada
sudo virsh autostart <vm>                      # Arranque automático al boot
sudo virsh autostart --disable <vm>            # Deshabilitar arranque automático
```

### Consola y acceso

```bash
sudo virsh console <vm>                        # Conectar a consola serie (salir: Ctrl+])
sudo virsh domifaddr <vm>                      # Ver IP de la VM
```

### Información

```bash
sudo virsh dominfo <vm>                        # Info general: RAM, CPU, estado
sudo virsh vcpuinfo <vm>                       # Info de vCPUs y CPU pinning actual
sudo virsh domblklist <vm>                     # Lista discos de la VM
sudo virsh dumpxml <vm>                        # Muestra XML completo de la VM
sudo virsh edit <vm>                           # Editar XML de la VM en $EDITOR
```

### Creación y clonación

```bash
# Crear VM nueva desde ISO
sudo virt-install \
  --name <vm> --ram 2048 --vcpus 2 \
  --disk path=/var/lib/libvirt/images/<vm>.qcow2,size=20 \
  --os-variant ubuntu22.04 \
  --network network=default \
  --cdrom /path/to/iso

# Clonar VM (genera nuevo UUID y MAC)
sudo virt-clone \
  --original <vm-origen> \
  --name <vm-clon> \
  --auto-clone
```

---

## 2. CPU Pinning y NUMA

### Diagnóstico del host

```bash
lscpu | grep -E "NUMA|Socket|Core|Thread|CPU\(s\)"           # Topología CPU del host
cat /sys/devices/system/cpu/cpu*/topology/thread_siblings_list | sort -u  # Pares de threads por core
numactl --hardware                                             # Topología NUMA completa
```

### Aplicar pinning

```bash
sudo virsh vcpupin <vm> 0 4      # Fijar vCPU 0 al thread físico 4
sudo virsh vcpupin <vm> 1 6      # Fijar vCPU 1 al thread físico 6
```

### Plantilla XML — cputune

```xml
<cputune>
  <vcpupin vcpu='0' cpuset='4'/>
  <vcpupin vcpu='1' cpuset='6'/>
</cputune>
<cpu mode='host-passthrough' check='none' migratable='on'/>
```

### Plantilla XML — NUMA

```xml
<numatune>
  <memory mode='strict' nodeset='0'/>
</numatune>
```

---

## 3. Huge Pages

### Configuración en el host

```bash
cat /proc/meminfo | grep -i huge                               # Estado actual de huge pages
sudo sysctl -w vm.nr_hugepages=1200                            # Reservar 1200 páginas de 2MB = 2.4GB
echo 'vm.nr_hugepages=1200' | sudo tee /etc/sysctl.d/hugepages.conf  # Hacer permanente
```

**Fórmula:** `RAM de VM (MB) / 2 = páginas necesarias`
Ejemplo: 2048 MB / 2 = 1024 páginas

### Plantilla XML — VM

```xml
<memoryBacking>
  <hugepages/>
</memoryBacking>
```

> **Nota Oracle:** Desactivar Transparent Huge Pages (THP) en producción con Oracle DB. Las huge pages estáticas son las recomendadas.

---

## 4. Almacenamiento — LVM y qcow2

### LVM en el host

```bash
sudo pvcreate /dev/sdX                                         # Crear Physical Volume
sudo vgcreate vg_nombre /dev/sdX                               # Crear Volume Group
sudo lvcreate -L 10G -n lv_nombre vg_nombre                   # Crear Logical Volume de 10GB
sudo mkfs.xfs /dev/vg_nombre/lv_nombre                        # Formatear con XFS (estándar Oracle)
sudo mount /dev/vg_nombre/lv_nombre /u01                       # Montar en /u01 (estándar Oracle)
sudo pvs && sudo vgs && sudo lvs                               # Estado de PV, VG y LV
```

### qcow2 — gestión de imágenes

```bash
sudo qemu-img info --force-share /var/lib/libvirt/images/<vm>.qcow2   # Info del disco
sudo qemu-img resize /var/lib/libvirt/images/<vm>.qcow2 20G           # Expandir a 20GB
sudo growpart /dev/sda 1                                               # Expandir partición (en guest)
sudo resize2fs /dev/sda1                                               # Expandir filesystem ext4
sudo xfs_growfs /mount/point                                           # Expandir filesystem XFS
```

### Pools de almacenamiento

```bash
sudo virsh pool-list --all                                     # Lista todos los pools
sudo virsh pool-dumpxml <pool>                                 # Ver XML del pool
sudo virsh vol-list <pool>                                     # Lista volúmenes del pool
sudo virsh vol-create-as <pool> <vol> 10G                      # Crear volumen en el pool

# Crear pool LVM
sudo virsh pool-define-as \
  --name lvm-pool --type logical \
  --source-name vg_nombre \
  --target /dev/vg_nombre
sudo virsh pool-start lvm-pool
sudo virsh pool-autostart lvm-pool
```

### Hot-plug de disco

```bash
sudo virsh attach-disk <vm> \
  /dev/vg_nombre/lv_nombre vdb \
  --driver qemu --subdriver raw \
  --targetbus virtio --live
```

### Benchmark de I/O

```bash
sudo dd if=/dev/zero of=/ruta/test.img bs=1M count=512 oflag=direct status=progress
```

---

## 5. Snapshots

```bash
sudo virsh snapshot-list <vm>                                  # Lista snapshots de la VM

# Crear snapshot en vivo
sudo virsh snapshot-create-as <vm> \
  --name "snap-nombre" \
  --description "descripción" \
  --atomic

sudo virsh snapshot-revert <vm> snap-nombre                    # Revertir al snapshot
sudo virsh snapshot-delete <vm> snap-nombre                    # Eliminar snapshot
```

> **Nota Oracle:** Antes de hacer snapshot con DB activa, ejecutar `ALTER DATABASE BEGIN BACKUP` para garantizar consistencia.

---

## 6. Redes — libvirt y bridge

### Gestión de redes

```bash
sudo virsh net-list --all                                      # Lista todas las redes
sudo virsh net-start default                                   # Iniciar red default (NAT)
sudo virsh net-destroy default                                 # Detener red
sudo virsh net-autostart default                               # Iniciar automáticamente al boot
sudo virsh net-dumpxml default                                 # Ver XML de la red
```

### Bridge físico con NetworkManager

```bash
sudo nmcli connection add type bridge ifname br0 con-name br0 bridge.stp no
sudo nmcli connection add type bridge-slave ifname enp4s0 con-name br0-slave master br0
sudo nmcli connection up br0-slave
sudo nmcli connection up br0
```

### Plantilla XML — red bridge en libvirt

```xml
<network>
  <name>bridge-fisico</name>
  <forward mode='bridge'/>
  <bridge name='br0'/>
</network>
```

### Plantilla XML — interfaz de VM

```xml
<!-- NAT (default) -->
<interface type='network'>
  <mac address='52:54:00:xx:xx:xx'/>
  <source network='default'/>
  <model type='virtio'/>
</interface>

<!-- Bridge físico -->
<interface type='network'>
  <mac address='52:54:00:xx:xx:xx'/>
  <source network='bridge-fisico'/>
  <model type='virtio'/>
</interface>
```

### Diagnóstico de red

```bash
bridge link show                                               # Interfaces unidas al bridge
sudo nft list ruleset | grep -A 10 libvirt                    # Reglas NAT de libvirt en nftables
sudo nmcli connection show                                     # Conexiones de NetworkManager
sudo nmcli connection delete virbr0                            # Eliminar conexión NM que interfiere con libvirt
```

---

## 7. VLANs y Bonding

### VLANs (802.1Q)

```bash
sudo modprobe 8021q                                            # Cargar módulo 802.1Q

# Crear interfaz VLAN 10
sudo ip link add link enp4s0 name enp4s0.10 type vlan id 10
sudo ip link set enp4s0.10 up
sudo ip addr add 10.0.10.1/24 dev enp4s0.10

sudo ip link delete enp4s0.10                                  # Eliminar interfaz VLAN
```

### Bonding

```bash
# Crear bond en modo active-backup
sudo ip link add bond0 type bond
sudo ip link set bond0 type bond mode active-backup
sudo ip link set bond0 type bond miimon 100                    # Monitor cada 100ms

# Agregar NIC como esclava
sudo ip link set enp2s0 down
sudo ip link set enp2s0 master bond0
sudo ip link set enp2s0 up

cat /proc/net/bonding/bond0                                    # Estado del bond y esclava activa
sudo ip link delete bond0                                      # Eliminar bond
```

**Modos de bonding:**

| Modo | Nombre | Uso |
|---|---|---|
| 0 | round-robin | Balancea paquetes entre NICs |
| 1 | active-backup | Una activa, otra en espera — máxima redundancia |
| 4 | 802.3ad (LACP) | Requiere switch compatible — estándar enterprise |

---

## 8. iSCSI y NFS

### iSCSI — Target (servidor)

```bash
sudo dnf install -y targetcli
sudo systemctl enable --now target
sudo targetcli

# Dentro de targetcli:
/backstores/fileio create disco /tmp/disco.img 10G
/iscsi create iqn.2026-05.com.empresa:storage1
/iscsi/iqn.2026-05.com.empresa:storage1/tpg1/luns create /backstores/fileio/disco
/iscsi/iqn.2026-05.com.empresa:storage1/tpg1/acls create iqn.2026-05.com.empresa:initiator1
/iscsi/iqn.2026-05.com.empresa:storage1/tpg1 set attribute authentication=0
saveconfig
exit
```

### iSCSI — Initiator (cliente)

```bash
sudo dnf install -y iscsi-initiator-utils
sudo systemctl enable --now iscsid

# Configurar IQN del initiator
echo "InitiatorName=iqn.2026-05.com.empresa:initiator1" | sudo tee /etc/iscsi/initiatorname.iscsi

sudo iscsiadm -m discovery -t sendtargets -p <IP-target>      # Descubrir targets
sudo iscsiadm -m node -T iqn.2026-05.com.empresa:storage1 -p <IP> --login   # Conectar
sudo iscsiadm -m node -T iqn.2026-05.com.empresa:storage1 -p <IP> --logout  # Desconectar
```

**Puerto estándar iSCSI:** TCP 3260

### NFS

```bash
# Servidor
sudo dnf install -y nfs-utils
sudo systemctl enable --now nfs-server
echo "/srv/nfs/compartido 192.168.1.0/24(rw,sync,no_subtree_check)" | sudo tee -a /etc/exports
sudo exportfs -ra
sudo exportfs -v

# Cliente
sudo mount -t nfs <IP-servidor>:/srv/nfs/compartido /mnt/nfs
```

---

## 9. Open vSwitch (OVS)

```bash
sudo dnf install -y openvswitch
sudo systemctl enable --now openvswitch

sudo ovs-vsctl show                                            # Estado completo de OVS
sudo ovs-vsctl add-br ovs-br0                                  # Crear bridge OVS
sudo ovs-vsctl del-br ovs-br0                                  # Eliminar bridge OVS

# Agregar puertos con VLAN
sudo ovs-vsctl add-port ovs-br0 vlan10 tag=10 -- set interface vlan10 type=internal
sudo ovs-vsctl add-port ovs-br0 vlan20 tag=20 -- set interface vlan20 type=internal

# Activar y asignar IP al puerto VLAN
sudo ip link set vlan10 up
sudo ip addr add 10.0.10.1/24 dev vlan10
```

**OVS vs Bridge Linux:**

| | Bridge Linux | Open vSwitch |
|---|---|---|
| VLANs | Interfaces separadas | Puertos con tag interno |
| QoS | Limitado | Nativo |
| Tunneling (VXLAN) | No | Sí |
| OpenFlow/SDN | No | Sí |
| Uso | Entornos simples | Enterprise / OpenStack |

---

## 10. Firewalld y nftables

### Firewalld

```bash
sudo firewall-cmd --state                                      # Estado del servicio
sudo firewall-cmd --get-active-zones                           # Zonas activas e interfaces
sudo firewall-cmd --zone=libvirt --list-all                    # Configuración de zona libvirt

# Agregar rich rule (bloqueo de puerto)
sudo firewall-cmd --zone=libvirt \
  --add-rich-rule='rule family="ipv4" source address="192.168.122.0/24" port port="8080" protocol="tcp" reject' \
  --permanent
sudo firewall-cmd --reload

# Abrir puerto 16509 (libvirt API remota — necesario para live migration)
sudo firewall-cmd --add-port=16509/tcp --permanent
sudo firewall-cmd --reload
```

**Zonas relevantes en KVM:**

| Zona | Interfaz | Función |
|---|---|---|
| libvirt | virbr0 | NAT y servicios para VMs (DHCP, DNS) |
| FedoraWorkstation | enp4s0, br0 | Interfaz física del host |
| trusted | 192.168.122.0/24 | Red de VMs con acceso al host |

### nftables

```bash
sudo nft list ruleset                                          # Ver todas las reglas activas
sudo nft list ruleset | grep -A 20 libvirt                    # Ver reglas NAT de libvirt
sudo nft list tables                                           # Lista todas las tablas
```

---

## 11. Performance y diagnóstico

### Monitoreo de VMs

```bash
sudo virt-top                                                  # Monitor en tiempo real (CPU, RAM, I/O)
sudo virsh domstats <vm>                                       # Estadísticas detalladas de la VM
```

### CPU steal time (dentro del guest)

```bash
top    # Columna %st = steal time. Mayor al 5% sostenido = host sobrecargado
```

### I/O scheduler

```bash
cat /sys/block/<disco>/queue/scheduler                         # Ver scheduler actual
echo none | sudo tee /sys/block/nvme0n1/queue/scheduler        # Para NVMe (sin overhead)
echo mq-deadline | sudo tee /sys/block/sda/queue/scheduler     # Para HDD/SSD SATA
```

### Herramientas de diagnóstico

```bash
sudo turbostat --interval 1                                    # Frecuencia y temperatura por CPU core
numactl --hardware                                             # Topología NUMA y latencias
lsmod | grep kvm                                               # Verificar módulos KVM cargados
ps aux | grep qemu | grep -v grep                              # Proceso QEMU con todos sus parámetros
```

### KSM — Kernel Same-page Merging

```bash
cat /sys/kernel/mm/ksm/run                                     # Estado (0=off, 1=on)
echo 0 | sudo tee /sys/kernel/mm/ksm/run                       # Desactivar (recomendado para Oracle)
```

---

## 12. Live Migration *(Tier 3)*

### Prerequisitos en ambos hosts

```
1. Almacenamiento compartido (NFS o iSCSI) accesible por ambos hosts
2. Puerto 16509/tcp abierto entre hosts (libvirt API)
3. Puertos 49152-49215/tcp abiertos (transferencia de memoria)
4. SSH sin contraseña entre hosts (clave pública)
5. Misma versión de libvirt recomendada
6. CPUs compatibles (host destino >= capacidades host origen)
```

### Configurar libvirt para migración remota

```bash
# Abrir puertos necesarios en ambos hosts
sudo firewall-cmd --add-port=16509/tcp --permanent
sudo firewall-cmd --add-port=49152-49215/tcp --permanent
sudo firewall-cmd --reload
```

### Ejecutar migración

```bash
# Live migration básica
sudo virsh migrate --live <vm> qemu+tcp://<IP-destino>/system

# Live migration completa (mueve definición también)
sudo virsh migrate --live --persistent --undefinesource <vm> \
  qemu+tcp://<IP-destino>/system

# Configurar tiempo máximo de pausa (500ms)
sudo virsh migrate-setmaxdowntime <vm> 500
```

---

## 13. Alta Disponibilidad *(Tier 3)*

### Conceptos clave

| Concepto | Descripción |
|---|---|
| Fencing | Matar un nodo del cluster para evitar split-brain |
| Quorum | Mínimo de nodos para tomar decisiones (mínimo 3 recomendado) |
| VIP | IP virtual que migra al nodo activo automáticamente |
| Split-brain | Dos nodos creen ser el primario — requiere fencing para resolverlo |

### Pacemaker + Corosync

```bash
# Instalación
sudo dnf install -y pacemaker corosync pcs fence-agents
sudo systemctl enable --now pcsd
sudo passwd hacluster

# Configuración del cluster
sudo pcs host auth <host1> <host2> -u hacluster
sudo pcs cluster setup mi-cluster <host1> <host2>
sudo pcs cluster start --all
sudo pcs cluster enable --all

# Estado
sudo pcs status
```

---

## 14. Plantilla XML completa — VM optimizada para Oracle DB

```xml
<domain type='kvm'>
  <name>oracle-db</name>
  <memory unit='KiB'>8388608</memory>       <!-- 8GB -->
  <currentMemory unit='KiB'>8388608</currentMemory>
  <memoryBacking>
    <hugepages/>                             <!-- Huge pages activadas -->
  </memoryBacking>
  <vcpu placement='static'>4</vcpu>
  <cputune>
    <vcpupin vcpu='0' cpuset='2'/>          <!-- Cada vCPU en su propio core físico -->
    <vcpupin vcpu='1' cpuset='4'/>
    <vcpupin vcpu='2' cpuset='6'/>
    <vcpupin vcpu='3' cpuset='8'/>
  </cputune>
  <cpu mode='host-passthrough' check='none' migratable='on'/>
  <os>
    <type arch='x86_64' machine='pc-q35-8.0'>hvm</type>
    <boot dev='hd'/>
  </os>
  <devices>
    <disk type='file' device='disk'>
      <driver name='qemu' type='qcow2' cache='none'/>  <!-- cache=none para I/O directo -->
      <source file='/var/lib/libvirt/images/oracle-db.qcow2'/>
      <target dev='sda' bus='scsi'/>
    </disk>
    <controller type='scsi' model='virtio-scsi'/>      <!-- VirtIO-SCSI para rendimiento -->
    <interface type='network'>
      <source network='default'/>
      <model type='virtio'/>
    </interface>
    <memballoon model='none'/>                          <!-- Balloon desactivado para Oracle -->
  </devices>
</domain>
```

---

## Referencia rápida — puertos importantes

| Puerto | Protocolo | Uso |
|---|---|---|
| 16509 | TCP | libvirt API remota (live migration, virt-manager remoto) |
| 49152-49215 | TCP | Transferencia de memoria en live migration |
| 3260 | TCP | iSCSI |
| 2049 | TCP/UDP | NFS |
| 22 | TCP | SSH |

---

## Referencia rápida — archivos de configuración

| Archivo | Descripción |
|---|---|
| `/etc/libvirt/libvirtd.conf` | Configuración del demonio libvirt |
| `/etc/libvirt/qemu/<vm>.xml` | Definición XML de cada VM |
| `/var/lib/libvirt/images/` | Ubicación por defecto de discos qcow2 |
| `/etc/iscsi/initiatorname.iscsi` | IQN del initiator iSCSI |
| `/etc/exports` | Exports NFS del servidor |
| `/etc/sysctl.d/hugepages.conf` | Configuración permanente de huge pages |
| `/proc/net/bonding/bond0` | Estado en tiempo real del bond |
| `/proc/meminfo` | Estado de memoria y huge pages |
| `/sys/block/<disco>/queue/scheduler` | I/O scheduler del disco |
