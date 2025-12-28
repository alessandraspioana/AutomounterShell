#!/bin/bash

CONFIG_FILE="amsh.config"

# Verificam daca exista fisierul de configurare
if [[ ! -f "$CONFIG_FILE" ]]; then
    echo "Eroare! Fisierul $CONFIG_FILE nu exista!"
    echo "Ruleaza mai intai simulate.sh pentru a putea continua"
    exit 1
fi

declare -A MNT_MAP

# Incarcam configurarea din fisier
while read -r folder device; do
    if [[ -z "$folder" || "$folder" =~ ^# ]]; then
        continue
    fi
    MNT_MAP["$folder"]="$device"
done < "$CONFIG_FILE"

# Functia "Ghost" care ruleaza in fundal
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
    echo "Device-ul ${MNT_MAP[$key]} a fost memorat in folder-ul $key"
done

# Curatare initiala pentru a evita erorile de tip "busy" sau loop-uri blocate
sudo losetup -D 2>/dev/null

echo "Pornire AutomounterShell (amsh)..."

# Pornim procesul de fundal si salvam PID-ul pentru curatare la exit
background_check &
MONITOR_PID=$!

while true; do
    read -p "amsh> " command_line
    command_line=$(echo "$command_line" | xargs)

    if [[ -z "$command_line" ]]; then
        continue
    fi

    read -r cmd arg1 <<< "$command_line"

    if [[ "$cmd" == "exit" ]]; then
        echo "Iesire din amsh. Se curata montarile..."
        for path in "${!MNT_MAP[@]}"; do
            sudo umount -l "$path" 2>/dev/null
            folder_name=$(basename "$path")
            rm -f "/tmp/last_$folder_name"
        done
        kill $MONITOR_PID 2>/dev/null
        break 

    elif [[ "$cmd" == "cd" ]]; then
        # Normalizam calea pentru a functiona si cu cai relative
        TARGET_DIR=$(realpath -m "$arg1")
        MOUNT_DEVICE=""
        BASE_PATH=""

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
            echo "Mountpoint special detectat: $TARGET_DIR -> $MOUNT_DEVICE"

            if ! mountpoint -q "$BASE_PATH"; then
                echo "Dispozitivul nu este montat. Se monteaza acum..."
                sudo mount -o loop "$MOUNT_DEVICE" "$BASE_PATH"
                if [[ $? -eq 0 ]]; then
                    echo "Montare reusita!"
                    cd "$TARGET_DIR"
                else
                    echo "Eroare la montare. Verifica permisiunile."
                fi
            else
                echo "Dispozitivul este deja montat."
                cd "$TARGET_DIR"
            fi
        else
            # Comanda cd normala
            cd "$TARGET_DIR" 2>/dev/null || echo "bash: cd: $TARGET_DIR: No such file or directory"
        fi

    else
        # Executam comenzi externe (ls, pwd, etc.)
        eval "$command_line"
    fi
done

echo "Scriptul a fost terminat."