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

# Cambiar la zona horaria del sistema usando una lista móvil de zonas comunes
cambiar_zona_horaria() {
  check_root || return
  clear
  current_tz=$(timedatectl show --property=Timezone --value 2>/dev/null || date +%Z)
  echo "${YELLOW}============================================================${NC}"
  center "${CYAN}              CAMBIAR ZONA HORARIA${NC}"
  echo "${YELLOW}============================================================${NC}"
  echo
  printf '%bZona actual:%b %b%s%b\n\n' "$CYAN" "$NC" "$WHITE" "$current_tz" "$NC"
  echo "Zonas comunes:"
  printf '  %b[1]%b America/New_York\n' "$WHITE" "$NC"
  printf '  %b[2]%b America/Chicago\n' "$WHITE" "$NC"
  printf '  %b[3]%b America/Los_Angeles\n' "$WHITE" "$NC"
  printf '  %b[4]%b America/Mexico_City\n' "$WHITE" "$NC"
  printf '  %b[5]%b America/Lima\n' "$WHITE" "$NC"
  printf '  %b[6]%b America/Bogota (Colombia)\n' "$WHITE" "$NC"
  printf '  %b[7]%b America/Caracas\n' "$WHITE" "$NC"
  printf '  %b[8]%b Europe/Madrid\n' "$WHITE" "$NC"
  printf '  %b[9]%b UTC\n' "$WHITE" "$NC"
  echo
  printf '%bNúmero de la zona (ENTER conserva %s):%b ' "$CYAN" "$current_tz" "$NC"; read -r tz_pick
  if [ -z "$tz_pick" ]; then
    echo "Zona horaria conservada: $current_tz"
    read -p "Presiona ENTER..."
    return
  fi
  case "$tz_pick" in
    1) new_tz="America/New_York";; 2) new_tz="America/Chicago";; 3) new_tz="America/Los_Angeles";;
    4) new_tz="America/Mexico_City";; 5) new_tz="America/Lima";; 6) new_tz="America/Bogota";;
    7) new_tz="America/Caracas";; 8) new_tz="Europe/Madrid";; 9) new_tz="UTC";;
    *) echo "Selección inválida."; read -p "Presiona ENTER..."; return;;
  esac
  if timedatectl set-timezone "$new_tz"; then
    echo "Zona horaria aplicada: $new_tz"
  else
    echo "No fue posible aplicar la zona horaria."
  fi
  read -p "Presiona ENTER..."
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
  echo "${YELLOW}------------------------------------------------------------${NC}"
  echo "   ${CYAN}[1]${NC} ${WHITE}Cambiar zona horaria${NC}"
  echo "   ${CYAN}[0]${NC} ${WHITE}Volver al menú${NC}"
  echo
  printf '%bSelecciona una opción (ENTER conserva la actual):%b ' "$CYAN" "$NC"; read -r tz_option
  [ "$tz_option" = "1" ] && cambiar_zona_horaria
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

cron_script_list() {
  mapfile -t CRON_SCRIPTS < <(find "$CRON_SCRIPT_DIR" -maxdepth 1 -type f -name '*.sh' -printf '%f\n' 2>/dev/null | sort)
}
cron_schedule_for() {
  local name="$1"
  crontab -l 2>/dev/null | awk -v tag="# Detalles-Systemas-panel:""$name" '$0 ~ tag {print $1" "$2" (todos los días)"; exit}'
}
cron_script_details() {
  local pick="$1" name path log schedule
  if ! [[ "$pick" =~ ^[0-9]+$ ]] || [ "$pick" -lt 1 ] || [ "$pick" -gt "${#CRON_SCRIPTS[@]}" ]; then
    echo "Selección inválida."
    return
  fi
  name="${CRON_SCRIPTS[$((pick-1))]}"
  path="$CRON_SCRIPT_DIR/$name"
  log="$CRON_SCRIPT_DIR/${name%.sh}.log"
  schedule=$(cron_schedule_for "${name%.sh}")
  clear
  echo "${YELLOW}============================================================${NC}"
  center "${CYAN}DETALLES COMPLETOS DEL SCRIPT${NC}"
  echo "${YELLOW}============================================================${NC}"
  echo
  printf '%bNombre:%b     %s\n' "$CYAN" "$NC" "$name"
  printf '%bRuta:%b       %s\n' "$CYAN" "$NC" "$path"
  printf '%bHorario:%b    %s\n' "$CYAN" "$NC" "${schedule:-No programado}"
  printf '%bPermisos:%b   %s\n' "$CYAN" "$NC" "$(stat -c '%A' "$path" 2>/dev/null || echo 'No disponible')"
  echo
  echo "${YELLOW}---------------- CONTENIDO COMPLETO ----------------${NC}"
  if [ -r "$path" ]; then
    cat "$path"
  else
    echo "No se puede leer el script."
  fi
  echo "${YELLOW}---------------- ÚLTIMA SALIDA ---------------------${NC}"
  if [ -s "$log" ]; then
    cat "$log"
  else
    echo "Sin ejecuciones registradas."
  fi
  echo "${YELLOW}------------------------------------------------------${NC}"
  read -p "Presiona ENTER para volver..."
}

cron_logs_resumidos() {
  clear
  echo "${YELLOW}============================================================${NC}"
  center "${CYAN}              TAREAS PROGRAMADAS${NC}"
  echo "${YELLOW}============================================================${NC}"
  echo
  cron_script_list
  if [ "${#CRON_SCRIPTS[@]}" -eq 0 ]; then
    echo "No hay tareas creadas por este panel."
  else
    for i in "${!CRON_SCRIPTS[@]}"; do
      name="${CRON_SCRIPTS[$i]%.sh}"
      log="$CRON_SCRIPT_DIR/$name.log"
      schedule=$(cron_schedule_for "$name")
      last=$(tail -n 1 "$log" 2>/dev/null || true)
      printf '%b[%d] %b%s%b\n' "$CYAN" "$((i+1))" "$WHITE" "${CRON_SCRIPTS[$i]}" "$NC"
      printf '    %bHorario:%b   %s\n' "$CYAN" "$NC" "${schedule:-No programado}"
      printf '    %bEstado:%b   %s\n' "$CYAN" "$NC" "$( [ -s "$log" ] && printf 'Con salida registrada' || printf 'Pendiente de ejecución' )"
      printf '    %bÚltimo:%b   %s\n' "$CYAN" "$NC" "${last:-Sin ejecución todavía}"
      printf '    %bRuta:%b     %s\n' "$CYAN" "$NC" "$CRON_SCRIPT_DIR/${CRON_SCRIPTS[$i]}"
      printf '%b------------------------------------------------------------%b\n' "$YELLOW" "$NC"
    done
  fi
  echo
  read -p "Número para ver ruta y contenido completo (ENTER para volver): " detail_pick
  [ -n "$detail_pick" ] && cron_script_details "$detail_pick"
}

cron_estado() {
  clear
  echo "${YELLOW}============================================================${NC}"
  center "${CYAN}              ESTADO DEL SERVICIO CRON${NC}"
  echo "${YELLOW}============================================================${NC}"
  echo
  service_status=$(systemctl --no-pager --plain is-active cron 2>/dev/null || true)
  service_enabled=$(systemctl --no-pager --plain is-enabled cron 2>/dev/null || true)
  script_count=$(find "$CRON_SCRIPT_DIR" -maxdepth 1 -type f -name '*.sh' 2>/dev/null | wc -l)
  job_count=$(crontab -l 2>/dev/null | grep -c '# Detalles-Systemas-panel:' || true)
  printf '%bServicio:%b          %b%s%b\n' "$CYAN" "$NC" "$WHITE" "${service_status:-No disponible}" "$NC"
  printf '%bInicio automático:%b %b%s%b\n' "$CYAN" "$NC" "$WHITE" "${service_enabled:-No disponible}" "$NC"
  printf '%bScripts del panel:%b  %b%s%b\n' "$CYAN" "$NC" "$WHITE" "$script_count" "$NC"
  printf '%bTareas programadas:%b %b%s%b\n' "$CYAN" "$NC" "$WHITE" "$job_count" "$NC"
  echo
  if [ "$service_status" = "active" ]; then
    echo "Cron está funcionando y ejecutará las tareas según su horario."
  else
    echo "Cron no aparece activo en este momento."
  fi
  echo
  read -p "Presiona ENTER para volver..."
}

cron_ejecuciones_fecha() {
  clear
  echo "${YELLOW}============================================================${NC}"
  center "${CYAN}          EJECUCIONES DE TAREAS POR FECHA${NC}"
  echo "${YELLOW}============================================================${NC}"
  echo
  cron_script_list
  if [ "${#CRON_SCRIPTS[@]}" -eq 0 ]; then
    echo "No hay scripts creados por el panel."
    read -p "Presiona ENTER para volver..."
    return
  fi
  echo "Seleccione el script cuyos logs desea consultar:"
  for i in "${!CRON_SCRIPTS[@]}"; do
    printf '  %b[%d]%b %b%s%b\n' "$WHITE" "$((i+1))" "$NC" "$YELLOW" "${CRON_SCRIPTS[$i]}" "$NC"
  done
  echo
  printf '%bNúmero del script:%b ' "$CYAN" "$NC"; read -r pick
  if ! [[ "$pick" =~ ^[0-9]+$ ]] || [ "$pick" -lt 1 ] || [ "$pick" -gt "${#CRON_SCRIPTS[@]}" ]; then
    echo "Selección inválida."; read -p "Presiona ENTER..."; return
  fi
  name="${CRON_SCRIPTS[$((pick-1))]%.sh}"
  log="$CRON_SCRIPT_DIR/$name.log"
  printf '%bFecha (AAAA-MM-DD) o ENTER para ver todas las ejecuciones:%b ' "$CYAN" "$NC"; read -r fecha
  clear
  echo "${YELLOW}============================================================${NC}"
  center "${CYAN}              LOGS DE $name${NC}"
  echo "${YELLOW}============================================================${NC}"
  echo
  if [ -n "$fecha" ]; then
    matches=$(grep -F "[$fecha" "$log" 2>/dev/null || true)
  else
    matches=$(cat "$log" 2>/dev/null || true)
  fi
  if [ -n "$matches" ]; then
    printf '%s\n' "$matches"
  else
    echo "Sin ejecuciones registradas para esa fecha."
  fi
  echo
  read -p "Presiona ENTER para volver..."
}

cron_admin() {
  check_root || return
  CRON_SCRIPT_DIR="/usr/local/sbin/detalles-cron"
  mkdir -p "$CRON_SCRIPT_DIR"
  while true; do
    clear
    echo "${YELLOW}============================================================${NC}"
    center "${CYAN}        ADMINISTRADOR DE TAREAS CRON${NC}"
    echo "${YELLOW}============================================================${NC}"
    echo
    echo "   ${CYAN}[1]${NC} ${WHITE}Ver scripts, rutas, horarios y última salida${NC}"
    echo "   ${CYAN}[2]${NC} ${WHITE}Crear script .sh y programarlo${NC}"
    echo "   ${CYAN}[3]${NC} ${WHITE}Ejecutar ahora / probar un script${NC}"
    echo "   ${CYAN}[4]${NC} ${WHITE}Editar hora de una tarea${NC}"
    echo "   ${CYAN}[5]${NC} ${WHITE}Ver estado de cron${NC}"
    echo "   ${CYAN}[6]${NC} ${WHITE}Ver ejecuciones por fecha y hora${NC}"
    echo "   ${CYAN}[7]${NC} ${WHITE}Eliminar un script y su tarea${NC}"
    echo "   ${CYAN}[0]${NC} ${WHITE}Volver${NC}"
    echo
    read -p " Selecciona una opción: " co
    case "$co" in
      1) cron_logs_resumidos;;
      2)
        clear; echo "${YELLOW}CREAR SCRIPT .SH Y PROGRAMARLO${NC}"; echo
        printf '%bNombre del script%b (ejemplo: backup-diario): ' "$CYAN" "$NC"; read -r script_name
        script_name=$(printf '%s' "$script_name" | tr -cs 'A-Za-z0-9_-' '-'); script_name=${script_name#-}; script_name=${script_name%-}
        if [ -z "$script_name" ]; then echo "Nombre inválido."; read -p "Presiona ENTER..."; continue; fi
        script_path="$CRON_SCRIPT_DIR/${script_name}.sh"; log_path="$CRON_SCRIPT_DIR/${script_name}.log"
        echo; printf '%bPegue el código completo. Termine escribiendo exactamente FIN.%b\n\n' "$CYAN" "$NC"
        code=""; while IFS= read -r line; do [ "$line" = "FIN" ] && break; code+="$line"$'\n'; done
        if [ -z "$code" ]; then echo "No se recibió código."; read -p "Presiona ENTER..."; continue; fi
        printf '%s' "$code" > "$script_path"; chmod 0755 "$script_path"
        printf '%bHora (0-23):%b ' "$CYAN" "$NC"; read -r ch; printf '%bMinuto (0-59):%b ' "$CYAN" "$NC"; read -r cm
        if ! [[ "$ch" =~ ^([0-9]|1[0-9]|2[0-3])$ && "$cm" =~ ^([0-9]|[1-5][0-9])$ ]]; then rm -f "$script_path"; echo "Hora o minuto inválido; no se creó la tarea."; read -p "Presiona ENTER..."; continue; fi
        (crontab -l 2>/dev/null | grep -v "# Detalles-Systemas-panel:$script_name" || true; printf '%s %s * * * { printf \"[%%s]\" \"$(date +\"%%Y-%%m-%%d %%H:%%M:%%S\")\"; %s; } >> %s 2>&1 # Detalles-Systemas-panel:%s\n' "$cm" "$ch" "$script_path" "$log_path" "$script_name") | crontab -
        echo; echo "Tarea creada para $(printf '%02d:%02d' "$ch" "$cm")."; echo "Script: $script_path"; echo "Log:    $log_path"; read -p "Presiona ENTER...";;
      3)
        clear; echo "${YELLOW}EJECUTAR AHORA / PROBAR SCRIPT${NC}"; echo
        cron_script_list
        if [ "${#CRON_SCRIPTS[@]}" -eq 0 ]; then echo "No hay scripts creados por el panel."; read -p "Presiona ENTER..."; continue; fi
        for i in "${!CRON_SCRIPTS[@]}"; do printf '  %b[%d]%b %b%s%b\n' "$WHITE" "$((i+1))" "$NC" "$YELLOW" "${CRON_SCRIPTS[$i]}" "$NC"; done
        echo; printf '%bSeleccione el número del script:%b ' "$CYAN" "$NC"; read -r pick
        if ! [[ "$pick" =~ ^[0-9]+$ ]] || [ "$pick" -lt 1 ] || [ "$pick" -gt "${#CRON_SCRIPTS[@]}" ]; then echo "Selección inválida."; read -p "Presiona ENTER..."; continue; fi
        selected="${CRON_SCRIPTS[$((pick-1))]}"; selected_path="$CRON_SCRIPT_DIR/$selected"; selected_log="$CRON_SCRIPT_DIR/${selected%.sh}.log"
        echo; echo "${YELLOW}============================================================${NC}"; echo "${CYAN}              RESULTADO DE LA PRUEBA${NC}"; echo "${YELLOW}============================================================${NC}"; echo; echo "Tarea: $selected"; echo
        printf "[%s] " "$(date "+%Y-%m-%d %H:%M:%S")" | tee -a "$selected_log"; bash "$selected_path" 2>&1 | tee -a "$selected_log"; rc=${PIPESTATUS[0]}
        echo; echo "${YELLOW}------------------------------------------------------------${NC}"; if [ "$rc" -eq 0 ]; then echo "Ejecución terminada correctamente."; else echo "La ejecución terminó con errores."; fi; echo "${YELLOW}------------------------------------------------------------${NC}"; read -p "Presiona ENTER...";;
      4)
        clear; echo "${YELLOW}EDITAR HORA DE UNA TAREA${NC}"; echo
        cron_script_list
        if [ "${#CRON_SCRIPTS[@]}" -eq 0 ]; then echo "No hay scripts creados por el panel."; read -p "Presiona ENTER..."; continue; fi
        for i in "${!CRON_SCRIPTS[@]}"; do printf '  %b[%d]%b %b%s%b\n' "$WHITE" "$((i+1))" "$NC" "$YELLOW" "${CRON_SCRIPTS[$i]}" "$NC"; done
        printf '%bSeleccione el número de la tarea:%b ' "$CYAN" "$NC"; read -r pick; if ! [[ "$pick" =~ ^[0-9]+$ ]] || [ "$pick" -lt 1 ] || [ "$pick" -gt "${#CRON_SCRIPTS[@]}" ]; then echo "Selección inválida."; read -p "Presiona ENTER..."; continue; fi
        name="${CRON_SCRIPTS[$((pick-1))]%.sh}"; path="$CRON_SCRIPT_DIR/$name.sh"; printf '%bNueva hora (0-23):%b ' "$CYAN" "$NC"; read -r nh; printf '%bNuevo minuto (0-59):%b ' "$CYAN" "$NC"; read -r nm
        if ! [[ "$nh" =~ ^([0-9]|1[0-9]|2[0-3])$ && "$nm" =~ ^([0-9]|[1-5][0-9])$ ]]; then echo "Hora o minuto inválido."; read -p "Presiona ENTER..."; continue; fi
        log="$CRON_SCRIPT_DIR/$name.log"; (crontab -l 2>/dev/null | grep -v "# Detalles-Systemas-panel:$name" || true; printf '%s %s * * * { printf \"[%%s]\" \"$(date +\"%%Y-%%m-%%d %%H:%%M:%%S\")\"; %s; } >> %s 2>&1 # Detalles-Systemas-panel:%s\n' "$nm" "$nh" "$path" "$log" "$name") | crontab -; echo "Horario actualizado: $(printf '%02d:%02d' "$nh" "$nm")"; echo "Script conservado: $path"; read -p "Presiona ENTER...";;
      5) cron_estado;;
      6) cron_ejecuciones_fecha;;
      7)
        clear; echo "${YELLOW}ELIMINAR SCRIPT Y TAREA${NC}"; echo
        cron_script_list
        if [ "${#CRON_SCRIPTS[@]}" -eq 0 ]; then echo "No hay scripts creados por el panel."; read -p "Presiona ENTER..."; continue; fi
        for i in "${!CRON_SCRIPTS[@]}"; do printf '  %b[%d]%b %b%s%b\n' "$WHITE" "$((i+1))" "$NC" "$YELLOW" "${CRON_SCRIPTS[$i]}" "$NC"; done
        printf '%bSeleccione el número del script:%b ' "$CYAN" "$NC"; read -r dpick; if ! [[ "$dpick" =~ ^[0-9]+$ ]] || [ "$dpick" -lt 1 ] || [ "$dpick" -gt "${#CRON_SCRIPTS[@]}" ]; then echo "Selección inválida."; read -p "Presiona ENTER..."; continue; fi
        dfile="${CRON_SCRIPTS[$((dpick-1))]}"; dname="${dfile%.sh}"; dpath="$CRON_SCRIPT_DIR/$dfile"; read -p "Escriba S o Sí para eliminar, N o No para cancelar: " ok
        if [[ "$ok" =~ ^[SsYy][IiíÍ]?$ ]]; then rm -f "$dpath" "$CRON_SCRIPT_DIR/$dname.log"; (crontab -l 2>/dev/null | grep -v "# Detalles-Systemas-panel:$dname" || true) | crontab -; echo "Script, log y tarea eliminados."; else echo "Operación cancelada."; fi; read -p "Presiona ENTER...";;
      0) return;; *) echo "Opción inválida"; sleep 1;;
    esac
  done
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
  echo "   ${CYAN}[7]${NC} ${WHITE}Administrar tareas Cron${NC}"
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
    7) cron_admin ;;
    0) break;;
    *) echo "Opción inválida"; sleep 2 ;;
  esac
done
