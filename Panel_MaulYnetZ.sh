#!/bin/bash

# Panel v52 (Autodestrucción de Usuarios Temporales)
# Script limpio para ser gestionado por un instalador externo.

# --- COLORES ---
red="\e[1;31m"; green="\e[1;32m"; yellow="\e[1;33m"; nc="\e[0m"
white="\e[1;37m"; cyan="\e[1;36m"
electric_blue="\e[1;94m"

# --- COLORES CON FONDO ---
red_bg="\e[1;37;41m"
blue_bg="\e[1;37;44m"
gray_bg="\e[0;30;47m"
red_bg_bold="\e[1;37;41m"

# --- BARRA DE SEPARACIÓN ---
BARRA="${red}======================================================${nc}"
LINEA_GUIONES="${red}------------------------------------------------------${nc}"

# --- FUNCIÓN PARA CALCULAR CPU DE FORMA PRECISA ---
get_cpu_usage() {
    read -r cpu user nice system idle iowait irq softirq steal guest guest_nice < /proc/stat
    PREV_IDLE=$idle
    PREV_TOTAL=$((user + nice + system + idle + iowait + irq + softirq + steal))
    sleep 0.5
    read -r cpu user nice system idle iowait irq softirq steal guest guest_nice < /proc/stat
    IDLE=$idle
    TOTAL=$((user + nice + system + idle + iowait + irq + softirq + steal))
    DIFF_IDLE=$((IDLE - PREV_IDLE))
    DIFF_TOTAL=$((TOTAL - PREV_TOTAL))
    if [ "$DIFF_TOTAL" -eq 0 ]; then CPU_USAGE="0.0"; else CPU_USAGE=$(awk "BEGIN {printf \"%.1f\", 100 * (1 - ${DIFF_IDLE} / ${DIFF_TOTAL})}"); fi
    echo "${CPU_USAGE}%"
}

# --- FUNCIÓN DEL MENÚ PRINCIPAL ---
info() {
  SO=$(lsb_release -is 2>/dev/null); SO_VER=$(lsb_release -rs 2>/dev/null)
  S_O_COMPLETO="${SO:-$(uname -s)} ${SO_VER:-$(uname -r)}"
  IP=$(hostname -I 2>/dev/null | awk '{print $1}' || echo "N/A")
  RAM_TOTAL=$(free -h | awk '/^Mem:/ {print $2}'); RAM_USED=$(free -h | awk '/^Mem:/ {print $3}'); RAM_FREE=$(free -h | awk '/^Mem:/ {print $4}')
  RAM_PERC=$(free | awk '/^Mem:/ {printf "%.2f%%", $3/$2*100}')
  CPU_CORES=$(nproc 2>/dev/null || echo "N/A"); CPU_PERC=$(get_cpu_usage)
  FECHA=$(date +'%m/%d/%y'); HORA=$(date +'%H:%M:%S')
  HWID_USERS=$(awk -F: '$5 ~ /^hwid,/ {print $1}' /etc/passwd)
  TOTAL=$(echo "$HWID_USERS" | wc -l)
  EXP=0; LOK=0; HOY_EPOCH=$(date +%s)
  for user in $HWID_USERS; do
      exp_date=$(chage -l "$user" | grep 'Account expires' | cut -d: -f2 | xargs)
      if [[ "$exp_date" != "never" ]]; then
          exp_epoch=$(date -d "$exp_date" +%s)
          if [ "$exp_epoch" -lt "$HOY_EPOCH" ]; then EXP=$((EXP + 1)); fi
      fi
      pass_hash=$(getent shadow "$user" | cut -d: -f2)
      if [[ "${pass_hash:0:1}" == "!" || "${pass_hash:0:1}" == "*" ]]; then LOK=$((LOK + 1)); fi
  done
  ONLI="0"; BANNER_TEXT="${electric_blue}MaulYnetZ${nc}"
  echo -e "$BARRA"; echo -e "             ${red}====>>>> ${BANNER_TEXT} ${red}<<<<====${nc}"; echo -e "$BARRA"
  printf " ${green}%-24s${green}%-18s${green}%-15s${nc}\n" "SISTEMA" "MEMORIA" "PROCESADOR"
  printf " ${cyan}S.O:${nc}   ${white}%-17s${nc} ${cyan}RAM:${nc}    ${white}%-9s${nc} ${cyan}CPU:${nc}     ${white}%-4s${nc}\n" "$S_O_COMPLETO" "$RAM_TOTAL" "$CPU_CORES"
  printf " ${cyan}IP:${nc}    ${white}%-17s${nc} ${cyan}USADA:${nc}  ${white}%-9s${nc} ${cyan}EN USO:${nc} ${white}%-4s${nc}\n" "$IP" "$RAM_USED" "$CPU_PERC"
  printf " ${cyan}FECHA:${nc} ${white}%-17s${nc} ${cyan}LIBRE:${nc}  ${white}%-9s${nc}\n" "$FECHA" "$RAM_FREE"
  printf " ${cyan}HORA:${nc}  ${white}%-17s${nc} ${cyan}EN USO:${nc} ${white}%-9s${nc}\n" "$HORA" "$RAM_PERC"
  echo -e "$BARRA"; printf " ${green}ONLI:${white} %-9s${red}EXP:${white} %-11s${cyan}LOK:${white} %-10s${yellow}TOTAL:${white} %-4s${nc}\n" "$ONLI" "$EXP" "$LOK" "$TOTAL"; echo -e "$BARRA"
}

# --- FUNCIÓN DEL SUBMENÚ DE CUENTAS ---
submenu_cuentas() {
    while true; do
        clear
        echo -e "$BARRA"; echo -e "      ${white}ADMINISTRACION DE USUARIOS HWID V10${nc}"; echo -e "$BARRA"
        echo -e " ${green}[1] >${white} NUEVO USUARIO HWID ✍️${nc}"
        echo -e " ${green}[2] >${cyan} CREAR USUARIO HWID TEMPORAL ✍️${nc}"
        echo -e " ${green}[3] >${red} REMOVER USUARIO 🗑️${nc}"
        echo -e " ${green}[4] >${cyan} ACTUALIZAR USUARIO ♻️${nc}"
        echo -e " ${green}[5] >${yellow} BLOQUEAR/DESBLOQUEAR USUARIO 🔓${nc}"
        echo -e "$LINEA_GUIONES"
        echo -e " ${green}[6] >${cyan} DETALLES DE TODOS USUARIOS 🚺${nc}"
        echo -e " ${green}[7] >${white} MONITOR DE USUARIOS CONECTADOS${nc}"
        echo -e " ${green}[8] >${yellow} 🔒 LIMITADOR-DE-CUENTAS${nc}"
        echo -e "$LINEA_GUIONES"
        echo -e " ${green}[9] >${white} ELIMINAR USUARIOS VENCIDOS${nc}"; echo -e " ${green}[10] >${red} ⚠️ ELIMINAR TODOS LOS USUARIOS${nc}"
        echo -e "$LINEA_GUIONES"
        echo -e " ${green}[11] >${white} ACTUALIZAR COPIA DE USUARIOS${nc}"; echo -e " ${green}[12] >${white} RESTAURAR COPIA DE USUARIOS${nc}"; echo -e " ${green}[13] >${white} DESACTIVAR CONTRASEÑA ALFANUMERICA${nc}"
        echo -e "$LINEA_GUIONES"; echo -e " ${green}[14] >${white} CONFIGURACION DEL ADMINISTRADOR HWID${nc}"; echo -e " ${green}[15] >${white} CAMBIAR A MODO SSH/TOKEN${nc}"
        echo -e "$LINEA_GUIONES"; echo -e " ${green}[0] >${red_bg_bold} VOLVER ${nc}"; echo -e "$BARRA"
        echo -ne "\n${white}SELECCIONE UNA OPCION:${nc} "; read -r sub_opt

        case "$sub_opt" in
            0) break ;;
            1)
               # --- FUNCIONALIDAD DE CREAR USUARIO (NORMAL) ---
               clear; echo -e "$BARRA\n            ${white}CREANDO NUEVO USUARIO HWID${nc}\n$BARRA"
               read -p "  Ingrese el HWID del usuario: " HWID_VAR; read -p "  Ingrese el número de TELÉFONO: " TELEFONO_VAR; read -p "  Ingrese los MESES de duración: " MESES_VAR
               if ! [[ "$MESES_VAR" =~ ^[0-9]+$ ]]; then echo -e "\n${red}Error: Meses debe ser un número.${nc}"; read -p "ENTER..."; continue; fi
               NOMBRE_CONST="MaulYnetZ"; echo -e "\n${yellow}Creando usuario...${nc}"; sleep 1
               HWID="$HWID_VAR"; NOMBRE="$NOMBRE_CONST"; TELEFONO="$TELEFONO_VAR"; MESES=$MESES_VAR; FECHA_EXP=$(date +%Y-%m-%d); for ((i=1;i<=MESES;i++)); do ANIO=$(date -d "$FECHA_EXP" +%Y); MES=$(date -d "$FECHA_EXP" +%m); DIAS_MES=$(date -d "$ANIO-$MES-01 +1 month -1 day" +%d); FECHA_EXP=$(date -d "$FECHA_EXP +$DIAS_MES days" +%Y-%m-%d); done; useradd -M -s /bin/false -c "hwid,$NOMBRE,$TELEFONO" "$HWID" && echo "$HWID:$HWID" | chpasswd && chage -E "$FECHA_EXP" "$HWID" && echo -e "\n${green}✔ Usuario creado:${nc}\n  Usuario: $HWID\n  Contraseña: $HWID\n  Expira: $FECHA_EXP" || echo -e "\n${red}❌ Error al crear.${nc}"
               read -p "Presione ENTER para volver..."
               ;;
            2)
               # --- CENTRO DE CONTROL DE USUARIOS TEMPORALES (CON AUTODESTRUCCIÓN) ---
               clear; echo -e "$BARRA\n        ${cyan}CENTRO DE CONTROL DE USUARIOS TEMPORALES${nc}\n$BARRA"
               echo -e "  ${white}--- Usuarios Temporales Actuales ---${nc}"
               TEMP_USERS=$(awk -F: '$5 ~ /^temporal,/ {print $1}' /etc/passwd)
               if [ -z "$TEMP_USERS" ]; then echo -e "  ${yellow}No hay usuarios temporales registrados.${nc}"; else
                   for user in $TEMP_USERS; do
                       gecos=$(getent passwd "$user" | cut -d: -f5); nombre=$(echo "$gecos" | cut -d, -f2)
                       pass_hash=$(getent shadow "$user" | cut -d: -f2)
                       if [[ "${pass_hash:0:1}" == "!" || "${pass_hash:0:1}" == "*" ]]; then lock_status="${red}[BLOQUEADO]${nc}"; else lock_status="${green}[ACTIVO]${nc}"; fi
                       
                       echo -e "${yellow}==================================================${nc}"
                       echo -e "${green}Usuario:${nc}   ${white}$user${nc}"; echo -e "${green}Nombre:${nc}    ${white}$nombre${nc}"
                       echo -e "${green}Estado:${nc}    $lock_status"
                   done
               fi
               echo -e "$BARRA"
               echo -e "  ${white}--- Crear Nuevo Usuario Temporal con Autodestrucción ---${nc}"
               if ! command -v at &> /dev/null; then
                   echo -e "\n${red}Error: El comando 'at' no está instalado.${nc}"; echo -e "${yellow}Por favor, instálalo con 'sudo apt-get install at' y asegúrate de que el servicio 'atd' esté activo.${nc}"; read -p "Presione ENTER para volver..."; continue
               fi
               read -p "  Ingrese el HWID del nuevo usuario: " HWID_VAR
               if [[ -z "$HWID_VAR" ]]; then echo -e "\n${yellow}Creación cancelada.${nc}"; sleep 2; continue; fi
               read -p "  Ingrese la duración en MINUTOS: " MINUTOS_VAR
               if ! [[ "$MINUTOS_VAR" =~ ^[0-9]+$ ]] || [ "$MINUTOS_VAR" -eq 0 ]; then echo -e "\n${red}Error: La duración debe ser un número de minutos mayor que cero.${nc}"; read -p "Presione ENTER..."; continue; fi
               
               NOMBRE_CONST="MaulYnetZ"; echo -e "\n${yellow}Creando usuario y programando su autodestrucción...${nc}"; sleep 1
               
               HWID="$HWID_VAR"; NOMBRE="$NOMBRE_CONST"; TELEFONO=""
               
               if useradd -M -s /bin/false -c "temporal,$NOMBRE,$TELEFONO" "$HWID" && echo "$HWID:$HWID" | chpasswd; then
                   MINUTOS_ELIMINACION=$((MINUTOS_VAR + 1))
                   
                   # Tarea 1: La bomba de bloqueo
                   echo "pkill -KILL -u '$HWID'; passwd -l '$HWID'" | at now + "$MINUTOS_VAR" minutes 2>/dev/null
                   
                   # Tarea 2: La bomba de eliminación
                   echo "userdel -r '$HWID'" | at now + "$MINUTOS_ELIMINACION" minutes 2>/dev/null
                   
                   echo -e "\n${green}✔ Usuario temporal creado:${nc}\n  Usuario: $HWID"
                   echo -e "  ${red}Será desconectado y bloqueado en: $MINUTOS_VAR minutos.${nc}"
                   echo -e "  ${red}Será eliminado completamente en: $MINUTOS_ELIMINACION minutos.${nc}"
               else echo -e "\n${red}❌ Error al crear el usuario.${nc}"; fi
               read -p "Presione ENTER para volver..."
               ;;
            3)
               # --- FUNCIONALIDAD DE ELIMINAR USUARIO ---
               clear; echo -e "$BARRA\n              ${red}REMOVER USUARIO DEL SISTEMA${nc}\n$BARRA"
               mapfile -t user_list < <(grep -E '^[^:]+:[^:]*:[^:]*:[^:]*:hwid,' /etc/passwd | cut -d: -f1)
               if [ ${#user_list[@]} -eq 0 ]; then echo -e "\n  ${yellow}No se encontraron usuarios 'hwid' para eliminar.${nc}\n"; read -p "Presione ENTER..."; continue; fi
               echo -e "  ${cyan}Usuarios 'hwid' encontrados:${nc}"; i=1
               for user in "${user_list[@]}"; do echo -e "    ${green}[$i]${nc} - ${white}$user${nc}"; i=$((i+1)); done
               echo -e "$BARRA"; read -p "  Ingrese el HWID o el NÚMERO de línea a eliminar: " selection
               HWID_DEL=""
               if [[ "$selection" =~ ^[0-9]+$ ]] && [ "$selection" -ge 1 ] && [ "$selection" -le ${#user_list[@]} ]; then HWID_DEL="${user_list[$((selection-1))]}"; elif [[ -n "$selection" ]]; then HWID_DEL="$selection"; else echo -e "\n${yellow}Operación cancelada.${nc}"; sleep 2; continue; fi
               echo ""; echo -ne "  ¿Está seguro de que desea eliminar al usuario '${yellow}${HWID_DEL}${nc}'? (s/n): "; read -r confirm
               if [[ "$confirm" != "s" && "$confirm" != "S" ]]; then echo -e "\n${yellow}Operación cancelada.${nc}"; sleep 2; continue; fi
               echo -e "\n${yellow}Eliminando al usuario '$HWID_DEL'...${nc}"; sleep 1
               HWID="$HWID_DEL"
               if id "$HWID" &>/dev/null; then
                   pkill -KILL -u "$HWID" 2>/dev/null || true; crontab -r -u "$HWID" 2>/dev/null || true
                   if (userdel -r "$HWID" 2>/dev/null || userdel "$HWID" 2>/dev/null || deluser --remove-home "$HWID" 2>/dev/null || deluser "$HWID" 2>/dev/null); then echo -e "\n${green}✅ El usuario '$HWID' fue eliminado.${nc}"; else echo -e "\n${red}⚠️ Error al eliminar con 'userdel'.${nc}"; fi
               else echo -e "\n${red}❌ El usuario '$HWID' no existe.${nc}"; fi
               read -p "Presione ENTER para volver..."
               ;;
            4)
               # --- FUNCIONALIDAD DE ACTUALIZAR USUARIO ---
               clear; echo -e "$BARRA\n            ${cyan}ACTUALIZAR HWID DE UN USUARIO${nc}\n$BARRA"
               mapfile -t user_list < <(grep -E '^[^:]+:[^:]*:[^:]*:[^:]*:hwid,' /etc/passwd | cut -d: -f1)
               if [ ${#user_list[@]} -eq 0 ]; then echo -e "\n  ${yellow}No se encontraron usuarios 'hwid'.${nc}\n"; read -p "ENTER..."; continue; fi
               echo -e "  ${cyan}Usuarios 'hwid' actuales:${nc}"; i=1
               for user in "${user_list[@]}"; do echo -e "    ${green}[$i]${nc} - ${white}$user${nc}"; i=$((i+1)); done
               echo -e "$BARRA"; read -p "  Seleccione el usuario a modificar (Nº o HWID viejo): " selection
               OLD_HWID=""
               if [[ "$selection" =~ ^[0-9]+$ ]] && [ "$selection" -ge 1 ] && [ "$selection" -le ${#user_list[@]} ]; then OLD_HWID="${user_list[$((selection-1))]}"; elif [[ -n "$selection" ]]; then OLD_HWID="$selection"; else echo -e "\n${yellow}Cancelado.${nc}"; sleep 2; continue; fi
               if ! id "$OLD_HWID" &>/dev/null; then echo -e "\n${red}❌ El usuario '$OLD_HWID' no existe.${nc}"; read -p "ENTER..."; continue; fi
               echo ""; read -p "  Ingrese el NUEVO HWID para este usuario: " NEW_HWID
               if [[ -z "$NEW_HWID" ]]; then echo -e "\n${red}El nuevo HWID no puede estar vacío.${nc}"; read -p "ENTER..."; continue; fi
               if id "$NEW_HWID" &>/dev/null; then echo -e "\n${red}❌ El nuevo HWID '$NEW_HWID' ya existe en el sistema.${nc}"; read -p "ENTER..."; continue; fi
               echo -e "\n${yellow}Actualizando usuario, por favor espere...${nc}"; sleep 1
               usermod -l "$NEW_HWID" "$OLD_HWID" &>/dev/null; usermod -p "$(openssl passwd -6 "$NEW_HWID")" "$NEW_HWID" &>/dev/null
               if id "$NEW_HWID" &>/dev/null && ! id "$OLD_HWID" &>/dev/null; then
                   echo -e "\n${green}✅ Usuario actualizado con éxito:${nc}\n  HWID Anterior: ${red}$OLD_HWID${nc}\n  HWID Nuevo:    ${green}$NEW_HWID${nc}"
               else echo -e "\n${red}⚠️ Hubo un error inesperado durante la actualización.${nc}"; fi
               read -p "Presione ENTER para volver..."
               ;;
            5)
               # --- FUNCIONALIDAD DE BLOQUEAR/DESBLOQUEAR ---
               clear; echo -e "$BARRA\n         ${yellow}BLOQUEAR O DESBLOQUEAR UN USUARIO${nc}\n$BARRA"
               mapfile -t user_list < <(grep -E '^[^:]+:[^:]*:[^:]*:[^:]*:hwid,' /etc/passwd | cut -d: -f1)
               if [ ${#user_list[@]} -eq 0 ]; then echo -e "\n  ${yellow}No se encontraron usuarios 'hwid'.${nc}\n"; read -p "ENTER..."; continue; fi
               echo -e "  ${cyan}Usuarios 'hwid' encontrados:${nc}"; i=1
               for user in "${user_list[@]}"; do
                   pass_hash=$(getent shadow "$user" | cut -d: -f2)
                   if [[ "${pass_hash:0:1}" == "!" || "${pass_hash:0:1}" == "*" ]]; then status="${red}[BLOQUEADO]${nc}"; else status="${green}[ACTIVO]${nc}"; fi
                   echo -e "    ${green}[$i]${nc} - ${white}$user${nc} $status"
                   i=$((i+1))
               done
               echo -e "$BARRA"; read -p "  Ingrese el HWID o el NÚMERO de línea a gestionar: " selection
               HWID_MOD=""
               if [[ "$selection" =~ ^[0-9]+$ ]] && [ "$selection" -ge 1 ] && [ "$selection" -le ${#user_list[@]} ]; then HWID_MOD="${user_list[$((selection-1))]}"; elif [[ -n "$selection" ]]; then HWID_MOD="$selection"; else echo -e "\n${yellow}Cancelado.${nc}"; sleep 2; continue; fi
               if ! id "$HWID_MOD" &>/dev/null; then echo -e "\n${red}❌ El usuario '$HWID_MOD' no existe.${nc}"; read -p "ENTER..."; continue; fi
               pass_hash=$(getent shadow "$HWID_MOD" | cut -d: -f2)
               if [[ "${pass_hash:0:1}" == "!" || "${pass_hash:0:1}" == "*" ]]; then
                   passwd -u "$HWID_MOD" &>/dev/null; echo -e "\n${green}✅ Usuario '$HWID_MOD' ha sido DESBLOQUEADO.${nc}"
               else
                   passwd -l "$HWID_MOD" &>/dev/null; pkill -KILL -u "$HWID_MOD" 2>/dev/null; echo -e "\n${red}🔒 Usuario '$HWID_MOD' ha sido BLOQUEADO.${nc}"
               fi
               read -p "Presione ENTER para volver..."
               ;;
            6)
               # --- FUNCIONALIDAD DE LISTAR USUARIOS (HWID) ---
               clear; echo -e "$BARRA\n          ${white}DETALLES DE TODOS LOS USUARIOS HWID${nc}\n$BARRA"
               HOY_EPOCH=$(date +%s)
               HWID_USERS=$(awk -F: '$5 ~ /^hwid,/ {print $1}' /etc/passwd)
               if [ -z "$HWID_USERS" ]; then echo -e "\n  ${yellow}No se encontraron usuarios de tipo 'hwid'.${nc}\n"; else
                   for user in $HWID_USERS; do
                       gecos=$(getent passwd "$user" | cut -d: -f5); nombre=$(echo "$gecos" | cut -d, -f2); telefono=$(echo "$gecos" | cut -d, -f3)
                       pass_hash=$(getent shadow "$user" | cut -d: -f2)
                       if [[ "${pass_hash:0:1}" == "!" || "${pass_hash:0:1}" == "*" ]]; then lock_status="${red}[BLOQUEADO]${nc}"; else lock_status="${green}[ACTIVO]${nc}"; fi
                       exp_date_str=$(chage -l "$user" | grep 'Account expires' | cut -d: -f2 | xargs)
                       exp_status=""
                       if [[ "$exp_date_str" == "never" ]]; then exp_status="${green}[VIGENTE]${nc}"; else
                           exp_epoch=$(date -d "$exp_date_str" +%s)
                           if [ "$exp_epoch" -lt "$HOY_EPOCH" ]; then
                               dias_exp=$(( (HOY_EPOCH - exp_epoch) / 86400 )); exp_status="${red}[EXPIRADO] (-${dias_exp}d)${nc}"
                           else exp_status="${green}[VIGENTE]${nc}"; fi
                       fi
                       echo -e "${yellow}==================================================${nc}"
                       echo -e "${green}Usuario:${nc}   ${white}$user${nc}"; echo -e "${green}Nombre:${nc}    ${white}$nombre${nc}"
                       if [[ -n "$telefono" ]]; then echo -e "${green}Teléfono:${nc}  ${white}$telefono${nc}"; else echo -e "${green}Teléfono:${nc}  ${red}sin teléfono${nc}"; fi
                       echo -e "${green}Expira:${nc}    ${white}$exp_date_str${nc}"; echo -e "${green}Estado:${nc}    $lock_status | $exp_status"
                   done
               fi
               echo -e "${yellow}==================================================${nc}"; read -p "Presione ENTER para volver al menú..."
               ;;
            *) echo -e "\n${red}Opción inválida${nc}"; sleep 1 ;;
        esac
    done
}

# --- BUCLE PRINCIPAL DEL MENÚ ---
while true; do
  clear; info
  echo -e " ${green}[1] >${white} ADMINISTRAR CUENTAS (SSH/DROPBEAR)${nc}"; echo -e "$LINEA_GUIONES"
  echo -e " ${green}[2] >${gray_bg} PREPARACION DEL SISTEMA ${nc}"; echo -e "$LINEA_GUIONES"
  echo -e " ${green}[3] >${white} DETALLES DEL SISTEMA ${nc}"
  echo -e "$LINEA_GUIONES"
  echo -e " ${green}0)${gray_bg} SALIR DEL VPS ${nc}   ${green}4)${red_bg} SALIR DEL SCRIPT ${nc}   ${green}5)${blue_bg} REBOOT VPS ${nc}"
  echo -e "$BARRA"; echo -ne "\n${yellow}Seleccione una Opcion:${nc} "; read -r opt

  case "$opt" in
    1) submenu_cuentas ;;
    2)
       # Esta es la opción que llamará al segundo script.
       # Por ahora, es un marcador de posición.
       echo -e "\n${green}>>> Abriendo Gestión de Protocolos...${nc}"
       source /root/MaulYnetZ/Protocolos.sh ;;
    3)
       # Opción para mostrar detalles del sistema
       echo -e "\n${green}>>> Mostrando detalles del sistema...${nc}"
       source /root/MaulYnetZ/Detalles_Systemas.sh ;;

    4) echo -e "\n${yellow}Saliendo...${nc}"; sleep 1; break ;;
    0) echo -e "\n${yellow}Saliendo...${nc}"; sleep 1; exit 0 ;;
    5) echo -e "\n${yellow}Reiniciando VPS...${nc}"; sleep 1; reboot ;;
    *) echo -e "\n${red}Opción inválida.${nc}"; sleep 2 ;;
  esac
done
