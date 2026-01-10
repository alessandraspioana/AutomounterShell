#!/bin/bash

CONFIG_FILE="amsh.config"
MOUNT_POINT="/media/amsh_usb" # Directorul unde va fi montat stick-ul, se realizeaza automat din terminal, aici vot fi informatiile din stick

echo "Pregatire configurare stick USB real"

# 1) Trebuie sa punem noi numele USB ului in ternimal!
# 2) Folosim comanda 'lsblk' in terminal pentru a gasi numele
# 3) Numele USB ului ar putea fi de ex: /dev/sdb1

echo "Conecteaza stick-ul USB acum si ruleaza 'lsblk' in alt terminal pentru a gasi numele partitiei."
read -p "Introdu numele complet al partitiei USB (ex: /dev/sdb1): " USB_DEVICE_PARTITION

if [[ -z "$USB_DEVICE_PARTITION" ]]; then
    echo "Eroare: Nu a fost introdus numele partitiei. Setup anulat."
    exit 1
fi

if mount | grep -q "$USB_DEVICE_PARTITION"; then
   echo "Dispozitivul $USB_DEVICE_PARTITION este deja montat in sistem. Se demonteaza pentru configurare..."
   sudo umount "$USB_DEVICE_PARITITON"
fi

# creez directorul pentru montare in cazul in care el nu exista deja 

if [[ ! -d "$MOUNT_POINT" ]]; then
   sudo mkdir -p "$MOUNT_POINT"
   sudo chmod 777 "$MOUNT_POINT" #oferim toate permisiunile pentru a nu avea erori
   echo "Directorul de montare "$MOUNT_POINT" a fost creat"
fi

## se testeaza daca se poate monta stick-ul
if ! sudo mount "$USB_DEVICE_PARTITION" "$MOUNT_POINT" >/dev/null 2>&1; then
   echo "Eroare: Partitia nu poate fi montata, sa se verifice daca este conectat stick-ul"
   exit 1
else 
   sudo umount "$MOUNT_POINT"
   echo "Verificare reusita"
fi

# Generarea fisierul de configurare amsh.config
# Aceasta sterge orice configuratie veche (simulata)
echo "$MOUNT_POINT $USB_DEVICE_PARTITION" > "$CONFIG_FILE"

echo "--- Setup Real USB Ready ---"
echo "Fisierul '$CONFIG_FILE' a fost actualizat pentru stick-ul USB real."
echo "Poti rula acum scriptul principal: ./automounter.sh"
echo "Cand rulezi amsh, foloseste comanda: cd $MOUNT_POINT"

