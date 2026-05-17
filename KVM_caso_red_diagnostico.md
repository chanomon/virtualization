# Diagnóstico y resolución de red en VM KVM

## El problema

Al crear una VM con `virt-install`, la VM puede quedar conectada a un **bridge físico** (`br0`) en lugar de la red NAT de libvirt (`default`). Esto causa que la interfaz de red del guest no obtendrá IP automáticamente.

### Síntomas

```bash
# Dentro del guest
ip addr show
# ens3: sin inet — sin IP asignada

# Desde el host
sudo virsh domifaddr ubuntutest
# Tabla vacía — sin IP
```

---

## Causa raíz

### Causa 1 — VM conectada a bridge físico

```xml
<interface type='bridge'>
  <source bridge='br0'/>       <!-- bridge físico, sin DHCP propio -->
  <model type='e1000'/>
</interface>
```

`br0` es un bridge físico que depende del DHCP del router. A diferencia de `virbr0` (red NAT de libvirt), no tiene servidor DHCP integrado.

### Causa 2 — Ubuntu 18.04 sin cloud-init

Ubuntu 18.04 instalado sin cloud-init no tiene configuración de red predefinida. La interfaz arranca pero no solicita IP automáticamente.

### Diferencia entre bridge físico y NAT

| | NAT (default/virbr0) | Bridge físico (br0) |
|---|---|---|
| DHCP | Integrado en libvirt (dnsmasq) | Depende del router |
| IP asignada | Siempre (192.168.122.x) | Solo si el router responde |
| Acceso externo | A través del host (NAT) | Directo desde la red |
| Complejidad | Simple | Requiere router cooperativo |

---

## Diagnóstico paso a paso

```bash
# 1. Verificar estado del bridge en el host
bridge link show
# vnet4: master br0 state forwarding — VM conectada pero sin IP

# 2. Verificar IP de la VM desde el host
sudo virsh domifaddr ubuntutest
# Tabla vacía — sin IP asignada

# 3. Ver configuración de red de la VM
sudo virsh dumpxml ubuntutest | grep -A5 "interface type"
# Confirma que usa bridge='br0' en lugar de network='default'
```

---

## Solución

### Paso 1 — Cambiar de bridge físico a NAT en caliente

```bash
# Desconectar interfaz del bridge físico
sudo virsh detach-interface ubuntutest bridge \
  --mac 52:54:00:9c:af:24 \
  --live

# Conectar a la red NAT de libvirt
sudo virsh attach-interface ubuntutest network default \
  --model virtio \
  --live
```

### Paso 2 — Levantar la nueva interfaz dentro del guest

```bash
# Ver interfaces disponibles (la nueva será ens8 o similar)
ip link show

# Levantar la interfaz
sudo ip link set ens8 up

# Solicitar IP por DHCP
sudo dhclient ens8

# Verificar que obtuvo IP
ip addr show ens8
```

---

## Cómo evitarlo en el futuro

### Opción 1 — Especificar NAT explícitamente en virt-install

```bash
sudo virt-install \
  --name mi-vm \
  --ram 2048 \
  --vcpus 2 \
  --disk path=/var/lib/libvirt/images/mi-vm.qcow2,size=20 \
  --os-variant ubuntu18.04 \
  --network network=default,model=virtio \    # <-- NAT explícito
  --cdrom /path/to/ubuntu.iso
```

### Opción 2 — Configurar red automática en el guest con netplan

```bash
# Dentro del guest — crear configuración netplan
sudo tee /etc/netplan/01-netcfg.yaml << 'EOF'
network:
  version: 2
  ethernets:
    ens3:
      dhcp4: yes
EOF

sudo chmod 600 /etc/netplan/01-netcfg.yaml
sudo netplan apply
```

### Opción 3 — Usar cloud image con cloud-init (recomendado)

```bash
# Descargar cloud image preinstalada
wget -P /var/lib/libvirt/images/ \
  https://cloud-images.ubuntu.com/bionic/current/bionic-server-cloudimg-amd64.img

# Crear configuración cloud-init
cat > /tmp/user-data.yaml << 'EOF'
#cloud-config
users:
  - name: ubuntu
    sudo: ALL=(ALL) NOPASSWD:ALL
    shell: /bin/bash
password: ubuntu123
chpasswd:
  expire: false
ssh_pwauth: true
EOF

# Crear ISO de cloud-init
cloud-localds /tmp/cloud-init.iso /tmp/user-data.yaml

# Instalar VM con red configurada automáticamente
sudo virt-install \
  --name ubuntu-cloud \
  --ram 2048 \
  --vcpus 2 \
  --disk /var/lib/libvirt/images/bionic-server-cloudimg-amd64.img \
  --disk /tmp/cloud-init.iso,device=cdrom \
  --os-variant ubuntu18.04 \
  --network network=default,model=virtio \
  --import \
  --noautoconsole
```

---

## Comandos de referencia rápida

```bash
# Ver a qué red está conectada una VM
sudo virsh dumpxml <vm> | grep -A5 "interface type"

# Ver IP de la VM desde el host
sudo virsh domifaddr <vm>

# Ver interfaces conectadas al bridge
bridge link show

# Cambiar interfaz de bridge a NAT en caliente
sudo virsh detach-interface <vm> bridge --mac <MAC> --live
sudo virsh attach-interface <vm> network default --model virtio --live

# Solicitar IP manualmente dentro del guest
sudo dhclient <interfaz>
```
