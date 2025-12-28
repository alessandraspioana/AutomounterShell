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

echo "Pornire AutomounterShell (amsh)..."

while true; do
    # afiseaza prompt-ul personalizat "amsh>"
    read -p "amsh> " command_line

    # elimina spatiile albe de la inceput/sfarsit
    command_line=$(echo "$command_line" | xargs)

    # daca linia de comanda este goala, continua bucla (afiseaza prompt-ul din nou)
    if [[ -z "$command_line" ]]; then
        continue
    fi

    # extrage prima parte a comenzii (numele comenzii) si argumentele
    read -r cmd arg1 <<< "$command_line"

    if [[ "$cmd" == "exit" ]]; then
        echo "Iesire din amsh."
        break 
    
    elif [[ "$cmd" == "cd" ]]; then
        TARGET_DIR="$arg1"

        # daca utilizatorul a tastat doar 'cd' fara argumente, mergi in directorul home
        if [[ -z "$TARGET_DIR" ]]; then
            cd ~
            continue
        fi

        MOUNT_DEVICE=${MNT_MAP["$TARGET_DIR"]}

        if [[ -n "$MOUNT_DEVICE" ]]; then
            # am gasit un dispozitiv asociat cu acest director in MNT_MAP!
            echo "Mountpoint special detectat: $TARGET_DIR -> $MOUNT_DEVICE"

            # aici: verificam si montam
            # va trebui sa introduci parola de administrator cand rulezi amsh
            if ! mountpoint -q "$TARGET_DIR"; then
                echo "Dispozitivul nu este montat. Se monteaza acum..."
                sudo mount "$MOUNT_DEVICE" "$TARGET_DIR"
                if [[ $? -eq 0 ]]; then
                    echo "Montare reusita! Schimb directorul."
                    cd "$TARGET_DIR"
                else
                    echo "Eroare la montarea dispozitivului. Verifica permisiunile."
                fi
            else
                echo "Dispozitivul este deja montat. Schimb directorul."
                cd "$TARGET_DIR"
            fi

        else
            echo "Comanda 'cd' normala catre: $TARGET_DIR"
            cd "$TARGET_DIR"
        fi

    else
        $command_line
    fi
done

echo "Scriptul a fost terminat."