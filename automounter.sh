#!/bin/bash

CONFIG_FILE="amsh.config"

# Verificam daca exista fisierul de configurare
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

background_check() {
    while true; do
        sleep 10  # Verifica la fiecare 5 secunde
        now=$(date +%s)
        
        for folder in "${!MNT_MAP[@]}"; do
            folder_name=$(basename "$folder")
            time_file="/tmp/last_$folder_name"

            if [[ -f "$time_file" ]]; then
                last_time=$(cat "$time_file")
                elapsed=$((now - last_time))

                # Pragul de inactivitate: 20 secunde (pentru demo)
                if [ "$elapsed" -ge 20 ]; then
                    # Verificam daca directorul este "busy"
                    if ! fuser -m "$folder" > /dev/null 2>&1; then
                        echo -e "\n[amsh] Inactivitate detectata. Demontare $folder..."
                        sudo umount -l "$folder"
                        rm "$time_file"
                    fi
                fi
            fi
        done
    done
}

echo "Configurarea este gata!"
for key in "${!MNT_MAP[@]}"; do
    echo "Device-ul "${MNT_MAP[$key]}" a fost memorat in folder-ul "$key""
done

# Curatare initiala pentru a evita erorile de tip "busy" sau loop-uri blocate
sudo losetup -D 2>/dev/null
# acum fiecarui device ii este asociat un folder in care este salvat 
# iar mai departe poate fi accesat de catre utilizator

echo "Pornire AutomounterShell (amsh)..."

# Pornim procesul de fundal si salvam PID-ul pentru curatare la exit
background_check &
MONITOR_PID=$!

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
        for path in "${!MNT_MAP[@]}"; do
            sudo umount -l "$path" 2>/dev/null
            folder_name=$(basename "$path")
            rm -f "/tmp/last_$folder_name"
        done
        kill $MONITOR_PID 2>/dev/null
        break 
    
    elif [[ "$cmd" == "cd" ]]; then
        TARGET_DIR=$(realpath -m "$arg1")
        MOUNT_DEVICE=""
        BASE_PATH=""

        # daca utilizatorul a tastat doar 'cd' fara argumente, mergi in directorul home
        if [[ -z "$TARGET_DIR" ]]; then
            cd ~
            continue
        fi

        for path in "${!MNT_MAP[@]}"; do
            if [[ "$TARGET_DIR" == "$path"* ]]; then
                MOUNT_DEVICE="${MNT_MAP[$path]}"
                BASE_PATH="$path"
                
                # Semnalizam activitatea catre procesul de fundal printr-un fisier
                folder_name=$(basename "$path")
                date +%s > "/tmp/last_$folder_name"
                break
            fi
        done

        if [[ -n "$MOUNT_DEVICE" ]]; then
            # am gasit un dispozitiv asociat cu acest director in MNT_MAP!
            echo "Mountpoint special detectat: $TARGET_DIR -> $MOUNT_DEVICE"

            # aici: verificam si montam
            # va trebui sa introduci parola de administrator cand rulezi amsh
            if ! mountpoint -q "$BASE_PATH"; then
                echo "Dispozitivul nu este montat. Se monteaza acum..."
                sudo mount -o loop "$MOUNT_DEVICE" "$BASE_PATH"
                if [[ $? -eq 0 ]]; then
                    echo "Montare reusita! Schimb directorul."
                    cd "$TARGET_DIR"
                else
                    echo "Eroare la montarea dispozitivului. Verifica permisiunile."
                fi
            else
                echo "Dispozitivul este deja montat."
                cd "$TARGET_DIR"
            fi

        else
            cd "$TARGET_DIR" 2>/dev/null || echo "bash: cd: $TARGET_DIR: No such file or directory"
        fi

    else
        eval "$command_line"
    fi
done

echo "Scriptul a fost terminat."