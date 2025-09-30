#!/bin/bash

# Colores para una mejor visualización en la terminal
YELLOW=$(tput setaf 3; tput bold) # Amarillo
CYAN=$(tput setaf 6; tput bold)   # Cian
WHITE=$(tput setaf 7; tput bold)  # Blanco
NC=$(tput sgr0)                   # Restablecer color

# Función para centrar texto en la terminal
center() {
  C=$(($(tput cols)/2-${#1}/2))
  printf "%${C}s%s\n" "" "$1"
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
  passwd root
  echo "Usuario root habilitado."
  sleep 2
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
  echo "   ${CYAN}[0]${NC} ${WHITE}Salir${NC}"
  echo

  read -p " Selecciona una opción: " opcion

  case $opcion in
    1) reiniciar_vps ;;
    2) refrescar_memoria ;;
    3) habilitar_root ;;
    4) detalles ;;
    0) source /root/MaulYnetZ/Panel_MaulYnetZ.sh
return ;;
    *) echo "Opción inválida"; sleep 2 ;;
  esac
done
