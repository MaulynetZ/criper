#!/bin/bash

# Colores para una mejor visualización en la terminal
YELLOW=$(tput setaf 3; tput bold) # Amarillo
CYAN=$(tput setaf 6; tput bold)   # Cian
WHITE=$(tput setaf 7; tput bold)  # Blanco
BLUE=$(tput setaf 4; tput bold)   # Azul
NC=$(tput sgr0)                   # Restablecer color

# Variables para backup
BACKUP_DIR="/var/backups/users"
TEMP_DIR="/tmp/user_backup_temp"

# Función para centrar texto en la terminal
center() {
  C=$(($(tput cols)/2-${#1}/2))
  printf "%${C}s%s\n" "" "$1"
}

# Función para verificar si el usuario es root
check_root() {
    if [[ $EUID -ne 0 ]]; then
        echo "${BLUE}Este script debe ejecutarse como root.${NC}" >&2
        sleep 2
        return 1
    fi
    return 0
}

# Función para crear un backup
create_backup() {
    check_root || return
    clear
    center "${CYAN}--- INICIANDO PROCESO DE BACKUP ---${NC}"
    echo

    mkdir -p "$BACKUP_DIR"
    mkdir -p "$TEMP_DIR"

    # Eliminar backups anteriores
    echo "${WHITE}Eliminando backups anteriores en $BACKUP_DIR...${NC}"
    rm -f "$BACKUP_DIR"/users_backup_*.tar.gz

    # Filtrar usuarios con 'hwid' en el primer subcampo del GECOS de /etc/passwd
    FILTERED_PASSWD_PATH="$TEMP_DIR"/passwd_hwid_filtered
    FILTERED_SHADOW_PATH="$TEMP_DIR"/shadow_hwid_filtered
    
    > "$FILTERED_PASSWD_PATH"
    > "$FILTERED_SHADOW_PATH"

    echo "${WHITE}Filtrando usuarios con 'hwid' en el primer subcampo del GECOS...${NC}"
    while IFS=: read -r user_name _ uid gid gecos_field home_dir shell_path; do
        # Dividir el campo GECOS por coma y verificar el primer subcampo
        FIRST_GECOS_SUBFIELD=$(echo "$gecos_field" | cut -d',' -f1)
        if [[ "$FIRST_GECOS_SUBFIELD" =~ "hwid" ]]; then
            echo "$user_name:x:$uid:$gid:$gecos_field:$home_dir:$shell_path" >> "$FILTERED_PASSWD_PATH"
            grep "^$user_name:" /etc/shadow >> "$FILTERED_SHADOW_PATH"
        fi
    done < /etc/passwd

    if [[ ! -s "$FILTERED_PASSWD_PATH" ]]; then
        echo "${BLUE}No se encontraron usuarios con 'hwid' en el primer subcampo del GECOS. No se creará backup.${NC}" >&2
        rm -rf "$TEMP_DIR"
        sleep 2
        return
    fi

    TIMESTAMP=$(date +%Y%m%d_%H%M%S)
    BACKUP_FILE="$BACKUP_DIR"/users_backup_"$TIMESTAMP".tar.gz
    echo "${WHITE}Creando backup: $BACKUP_FILE${NC}"
    tar -czf "$BACKUP_FILE" -C "$TEMP_DIR" "$(basename "$FILTERED_PASSWD_PATH")" "$(basename "$FILTERED_SHADOW_PATH")"

    rm -rf "$TEMP_DIR"

    if [[ -f "$BACKUP_FILE" ]]; then
        center "${CYAN}Backup creado exitosamente: $BACKUP_FILE${NC}"
    else
        center "${BLUE}Error al crear el backup.${NC}" >&2
    fi
    echo
    read -p "${WHITE}Presiona ENTER para continuar...${NC}"
}

# Función para restaurar un backup
restore_backup() {
    check_root || return
    clear
    center "${CYAN}--- INICIANDO PROCESO DE RESTAURACIÓN ---${NC}"
    echo

    mkdir -p "$TEMP_DIR"

    LATEST_BACKUP=$(ls -t "$BACKUP_DIR"/users_backup_*.tar.gz 2>/dev/null | head -n 1)

    if [[ -z "$LATEST_BACKUP" ]]; then
        echo "${BLUE}No se encontraron archivos de backup en $BACKUP_DIR.${NC}" >&2
        rm -rf "$TEMP_DIR"
        sleep 2
        return
    fi

    echo "${WHITE}Restaurando desde el backup: $LATEST_BACKUP${NC}"

    # Descomprimir el backup en el directorio temporal
    tar -xzf "$LATEST_BACKUP" -C "$TEMP_DIR"

    # Extraer los contenidos de passwd y shadow del backup
    BACKUP_PASSWD_CONTENT="$(cat "$TEMP_DIR"/passwd_hwid_filtered)"
    BACKUP_SHADOW_CONTENT="$(cat "$TEMP_DIR"/shadow_hwid_filtered)"

    # Crear archivos temporales para las nuevas versiones de passwd y shadow
    NEW_PASSWD="$TEMP_DIR"/new_passwd
    NEW_SHADOW="$TEMP_DIR"/new_shadow

    # Inicializar NEW_PASSWD y NEW_SHADOW con el contenido actual de /etc/passwd y /etc/shadow
    cp /etc/passwd "$NEW_PASSWD"
    cp /etc/shadow "$NEW_SHADOW"

    echo "${WHITE}Actualizando /etc/passwd y /etc/shadow con usuarios 'hwid' del backup...${NC}"

    # Procesar /etc/passwd
    echo "$BACKUP_PASSWD_CONTENT" | while IFS=: read -r user_name _ uid gid gecos_field home_dir shell_path; do
        if grep -q "^$user_name:" "$NEW_PASSWD"; then
            # Si el usuario ya existe, reemplazar su línea
            sed -i "/^$user_name:/c\\$user_name:x:$uid:$gid:$gecos_field:$home_dir:$shell_path" "$NEW_PASSWD"
        else
            # Si el usuario no existe, añadirlo
            echo "$user_name:x:$uid:$gid:$gecos_field:$home_dir:$shell_path" >> "$NEW_PASSWD"
        fi
    done

    # Procesar /etc/shadow
    echo "$BACKUP_SHADOW_CONTENT" | while IFS=: read -r user_name rest_of_line; do
        if grep -q "^$user_name:" "$NEW_SHADOW"; then
            # Si el usuario ya existe, reemplazar su línea
            sed -i "/^$user_name:/c\\$user_name:$rest_of_line" "$NEW_SHADOW"
        else
            # Si el usuario no existe, añadirlo
            echo "$user_name:$rest_of_line" >> "$NEW_SHADOW"
        fi
    done

    # Reemplazar los archivos originales con los nuevos fusionados
    cp "$NEW_PASSWD" /etc/passwd
    cp "$NEW_SHADOW" /etc/shadow

    # Actualizar permisos
    chmod 644 /etc/passwd
    chown root:root /etc/passwd
    chmod 640 /etc/shadow
    chown root:shadow /etc/shadow

    rm -rf "$TEMP_DIR"

    center "${CYAN}Restauración completada exitosamente desde $LATEST_BACKUP.${NC}"
    echo
    read -p "${WHITE}Presiona ENTER para continuar...${NC}"
}

# Función principal para mostrar los detalles del sistema (MEJORADA)
detalles() {
  clear # Limpiar la pantalla de la terminal

  # Recopilación de información del sistema
  CORES=$(nproc) # Número de núcleos del procesador
  CPU_USAGE=$(top -bn1 | awk '/Cpu/ {print 100 - $8"%"}') # Uso actual de la CPU
  MEM_TOTAL=$(free -h | awk '/^Mem:/ {print $2}') # Memoria RAM total
  MEM_USED=$(free -h | awk '/^Mem:/ {print $3}')  # Memoria RAM usada
  MEM_FREE=$(free -h | awk '/^Mem:/ {print $4}')  # Memoria RAM libre
  DISK_TOTAL=$(df -h --total | awk '/^total/ {print $2}') # Espacio total en disco
  DISK_USED=$(df -h --total | awk '/^total/ {print $3}')  # Espacio usado en disco
  DISK_FREE=$(df -h --total | awk '/^total/ {print $4}')  # Espacio libre en disco
  UPTIME=$(uptime -p) # Tiempo de actividad del sistema
   TZ_INFO=$(timedatectl | awk -F': ' '/Time zone/ {print $2}') # Zona horaria
s


  DATE_NOW=$(date +"%d-%m-%Y") # Fecha actual
  TIME_NOW=$(date +"%H:%M:%S") # Hora actual

  # Presentación de la información
  echo
  echo "${YELLOW}============================================================${NC}"
  center "${YELLOW}       ████████████  ESTADO DEL VPS  ████████████${NC}"
  echo "${YELLOW}============================================================${NC}"
  echo

  # Presentación de la información en dos columnas
  echo "${YELLOW}------------------------------------------------------------${NC}"
  center "${CYAN}          📊 RESUMEN DEL SISTEMA${NC}"
  echo "${YELLOW}------------------------------------------------------------${NC}"
  echo

  # Primera columna: Procesador y Memoria RAM
    printf "  ${CYAN}%-25s ${CYAN}%-25s${NC}\n" "🖥️  PROCESADOR" "   💾 MEMORIA RAM"
  printf "  ${WHITE}%-25s ${WHITE}%-25s${NC}\n" "Núcleos: $CORES" "Total: $MEM_TOTAL"
  printf "  ${WHITE}%-25s ${WHITE}%-25s${NC}\n" "Uso: $CPU_USAGE" "Usada: $MEM_USED"
  printf "  ${WHITE}%-25s ${WHITE}%-25s${NC}\n" "" "Libre: $MEM_FREE"
  echo

  # Segunda columna: Disco Duro, Zona Horaria y Fecha/Hora
    printf "  ${CYAN}%-25s ${CYAN}%-25s${NC}\n" "💽 DISCO DURO" "🌍 ZONA HORARIA / 🗓️ FECHA Y HORA"
  printf "  ${WHITE}%-25s ${WHITE}%-25s${NC}\n" "Total: $DISK_TOTAL" "Zona: $TZ_INFO"
  printf "  ${WHITE}%-25s ${WHITE}%-25s${NC}\n" "Usado: $DISK_USED" "Fecha: $DATE_NOW"
  printf "  ${WHITE}%-25s ${WHITE}%-25s${NC}\n" "Libre: $DISK_FREE" "Hora: $TIME_NOW"
  echo

  read -p " Presiona ENTER para volver al menú..."
}

# Funciones auxiliares (del script original)
refrescar_memoria() {
  sync; echo 3 > /proc/sys/vm/drop_caches
  echo "Memoria RAM liberada."
  sleep 2
}

habilitar_root() {
  clear
  echo
  echo "${YELLOW}============================================================${NC}"
  center "${CYAN}   ⚙️  HABILITAR USUARIO ROOT  ⚙️   ${NC}"
  echo "${YELLOW}============================================================${NC}"
  echo

  echo "${WHITE}Estableciendo la contraseña para el usuario root...${NC}"
  passwd root
  echo "${CYAN}Contraseña de root establecida exitosamente.${NC}"
  sleep 2

  echo "${WHITE}Configurando SSH para permitir el inicio de sesión de root...${NC}"
  # Editar el archivo de configuración SSH para permitir el inicio de sesión de root
  if grep -q "^PermitRootLogin" /etc/ssh/sshd_config;
  then
    sed -i 's/^PermitRootLogin.*/PermitRootLogin yes/' /etc/ssh/sshd_config
  else
    echo "PermitRootLogin yes" >> /etc/ssh/sshd_config
  fi
  echo "${CYAN}Configuración SSH actualizada: PermitRootLogin yes.${NC}"
  sleep 2

  echo "${WHITE}Reiniciando el servicio SSH para aplicar los cambios...${NC}"
  systemctl restart sshd || service ssh restart
  echo "${CYAN}Servicio SSH reiniciado. El usuario root ahora puede iniciar sesión vía SSH.${NC}"
  sleep 3

  read -p " Presiona ENTER para volver al menú..."
}

reiniciar_vps() {
  echo "Reiniciando VPS..."
  sleep 2
  reboot
}

# Menú principal (del script original)
while true; do
  clear
  echo
  echo "${YELLOW}============================================================${NC}"
  center "${CYAN}   ██████████  MENÚ DE ADMINISTRACIÓN VPS  ██████████${NC}"
  echo "${YELLOW}============================================================${NC}"
  echo
  echo "   ${CYAN}[1]${NC} ${WHITE}Reiniciar VPS${NC}"
  echo "   ${CYAN}[2]${NC} ${WHITE}Refrescar memoria RAM${NC}"
  echo "   ${CYAN}[3]${NC} ${WHITE}Habilitar usuario ROOT${NC}"
  echo "   ${CYAN}[4]${NC} ${WHITE}Mostrar detalles del sistema${NC}"
  echo "   ${CYAN}[5]${NC} ${WHITE}Hacer Backup de Usuarios (solo 'hwid')${NC}"
  echo "   ${CYAN}[6]${NC} ${WHITE}Restaurar Último Backup de Usuarios (solo 'hwid')${NC}"
  echo "   ${CYAN}[0]${NC} ${WHITE}Salir${NC}"
  echo

  read -p " Selecciona una opción: " opcion

  case $opcion in
    1) reiniciar_vps ;;
    2) refrescar_memoria ;;
    3) habilitar_root ;;
    4) detalles ;;
    5) create_backup ;;
    6) restore_backup ;;
    0) break;;
    *) echo "Opción inválida"; sleep 2 ;;
  esac
done

