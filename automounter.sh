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
declare -A LAST_USED # se retine timestamp ul ultimei utilizari pt fiecare mountpoint
TTL=15 # time to live e max de 5 minute

while read -r folder device; do

    if [[ -z "$folder" || "$folder" =~ ^# ]]; then
        continue
    fi

    MNT_MAP[$(realpath -m "$folder")]="$device"

done < "$CONFIG_FILE"

echo "Configurarea este gata!"

for key in "${!MNT_MAP[@]}"; do
    echo "Device-ul "${MNT_MAP[$key]}" a fost memorat in folder-ul "$key""
done

# acum fiecarui device ii este asociat un folder in care este salvat 
# iar mai departe poate fi accesat de catre utilizator

echo "Pornire AutomounterShell (amsh)..."

#functie care verifica daca ttl a expirat 
#si care verifica mountpoint urile si le demonteaza
cleanup_mounts(){ 
    now=$(date +%s) #timp curent 
    for mp in "${!LAST_USED[@]}";do #parcurgem toate mountpoint urile
        if mountpoint -q "$mp"; then # verificam daca mountpoint ul este montat
            last=${LAST_USED[$mp]} #retinem timpul ultimei utilizari
            if (( now - last > TTL )); then 
                if [[ "$PWD" == "$mp"* ]]; then
                    LAST_USED["$mp"]=$now
                else
                    echo "TTL expirat pt $mp -> umount"
                    sudo umount "$mp" #demontam automat
                    unset LAST_USED["$mp"] #stergere intrare din last_used
                fi
            fi
        fi
    done }

while true; do
    cleanup_mounts #verificam existenta mountpoint urilor carora le a expirat ttl ul
    # afiseaza prompt-ul personalizat "amsh>"
    read -p "amsh:${PWD##/}> " command_line # ${PWD##/} arata si directorul curent

    # elimina spatiile albe de la inceput/sfarsit
    command_line=$(echo "$command_line" | xargs)

    # daca linia de comanda este goala, continua bucla (afiseaza prompt-ul din nou)
    if [[ -z "$command_line" ]]; then
        continue
    fi

    # extrage prima parte a comenzii (numele comenzii) si argumentele
    read -r cmd arg1 <<< "$command_line"

    if [[ "$cmd" == "exit" ]]; then
        echo "Iesire din amsh. Se demonteaza automat resursele active..."
        for mp in "${!LAST_USED[@]}"; do
            if mountpoint -q "$mp"; then 
                sudo umount "$mp" 
            fi 
        done
        exit 0
    
    elif [[ "$cmd" == "cd" ]]; then

        # daca utilizatorul a tastat doar 'cd' fara argumente, mergi in directorul home
        if [[ -z "$arg1" ]]; then
            TARGET_DIR="$HOME"
            cd ~
            continue
        fi
        
        TARGET_DIR=$(realpath -m "$arg1")
        MOUNT_DEVICE=${MNT_MAP["$TARGET_DIR"]}

        if [[ -n "$MOUNT_DEVICE" ]]; then
            # am gasit un dispozitiv asociat cu acest director in MNT_MAP!
            echo "Mountpoint special detectat: $TARGET_DIR -> $MOUNT_DEVICE"

            # aici: verificam si montam
            # va trebui sa introduci parola de administrator cand rulezi amsh
            if ! mountpoint -q "$TARGET_DIR"; then
                echo "Dispozitivul nu este montat. Se monteaza acum..."
                echo "S-a montat $MOUNT_DEVICE in $TARGET_DIR "
                sudo mount "$MOUNT_DEVICE" "$TARGET_DIR"
            else
                echo "Dispozitivul este deja montat. Schimb directorul."
            fi

            if [[ $? -eq 0 ]]; then
                cd "$TARGET_DIR" || echo "Eroare la montarea dispozitivului. Verifica permisiunile."
                echo "Montare reusita! Schimb directorul."
                LAST_USED["$TARGET_DIR"]=$(date +%s) #salvam timpul ultimei utilizari
            fi
        else
            echo "Comanda 'cd' normala catre: $TARGET_DIR"
            cd "$TARGET_DIR"
        fi
    else
        eval "$command_line"

        for mp in "{!MNT_MAP[@]}"; do
            if [[ "$command_line" == *"$mp"* ]]; then
                if mountpoint -q "$mp"; then 
                    LAST_USED["$mp"]=$(date + %s)
                fi
            fi
        done
    fi
done

echo "Scriptul a fost terminat."

 