#!/bin/bash

CONFIG_FILE="amsh.config"

if [[ ! -f "$CONFIG_FILE" ]]; then
    echo "Eroare! Fisierul $CONFIG_FILE nu exista!"
    echo "Ruleaza mai intai simulate.sh pentru a putea continua"
    exit 1
fi

# pana acum verificam daca exista fisierul amsh.config
# in caz contrar, avem nevoie de a "simula" device-urile hardware
# aceasta simulare (care este descris in simulate.sh) "citeste" deivce-urile hardware 
# si creeaza fisierul amsh.config

declare -A MNT_MAP

while read -r folder device; do

    if [[ -z "$folder" || "$folder" =~ ^# ]]; then
        continue
        exit 1
    fi

    MNT_MAP["$folder"]="$device"
    # if [[ -z "$folder" || -z "$device" ]]; then
    #     echo "Eroare! Folderul sau fisierul nu exista."
    #     exit 1
    # fi
done < "$CONFIG_FILE"

echo "Configurarea este gata!"

for key in "${!MNT_MAP[@]}"; do
    echo "Device-ul "${MNT_MAP[$key]}" a fost memorat in folder-ul "$key""
done

# acum fiecarui device ii este asociat un folder in care este salvat 
# iar mai departe poate fi accesat de catre utilizator

