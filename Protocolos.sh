#!/bin/bash

# ============================================================
# Panel de Control PRO (Integración: Script A + BadVPN/UDP-Custom)
# ============================================================
# Nota: Mantuve íntegro el menú, colores y lógica del Script A.
# Se agregaron BadVPN-UDP y UDP-Custom (tomadas de Script B) y sus
# animaciones como funciones separadas para no interferir con A.
# ============================================================

# --- Definición de Colores (igual que Script A, con agregado C_GRAY) ---
C_RED='\e[1;31m'
C_GREEN='\e[1;32m'
C_YELLOW='\e[1;33m' # Mantener el color amarillo estándar
C_BLUE='\e[1;34m'
C_MAGENTA='\e[1;35m'
C_CYAN='\e[1;36m'
C_WHITE='\e[1;37m'
C_RESET='\e[0m'
C_GRAY='\e[1;90m'   # añadido para elementos de estado (no altera paleta A)

# ---------------------------
# (A) --- Funciones del Script A (sin modificar) ---
# ---------------------------

function is_stunnel4_installed() {
    if dpkg-query -W -f='${Status}' stunnel4 2>/dev/null | grep -q "install ok installed"; then return 0; else return 1; fi
}
function get_stunnel_status() {
    if systemctl is-active --quiet stunnel4; then echo -e "${C_GREEN}ON${C_RESET}"; else echo -e "${C_RED}OFF${C_RESET}"; fi
}
function get_autostart_status() {
    if systemctl is-enabled --quiet stunnel4; then echo -e "${C_GREEN}ON${C_RESET}"; else echo -e "${C_RED}OFF${C_RESET}"; fi
}
function get_stunnel_ports() {
    if [ -f /etc/stunnel/stunnel.conf ]; then
        ports=$(grep "accept" /etc/stunnel/stunnel.conf | awk '{ print $3 }' | tr '\n' ',' | sed 's/,$//')
        echo -e "${C_CYAN}$ports${C_RESET}"
    else
        echo -e "${C_RED}N/A${C_RESET}"
    fi
}
function get_internal_port() {
    if [ -f /etc/stunnel/stunnel.conf ]; then
        grep -m 1 "connect" /etc/stunnel/stunnel.conf | awk '{ print $3 }'
    else
        echo "N/A"
    fi
}

function is_dropbear_installed() {
    if dpkg-query -W -f='${Status}' dropbear 2>/dev/null | grep -q "install ok installed"; then return 0; else return 1; fi
}
function get_dropbear_status() {
    if systemctl is-active --quiet dropbear; then echo -e "${C_GREEN}ON${C_RESET}"; else echo -e "${C_RED}OFF${C_RESET}"; fi
}
function get_dropbear_autostart_status() {
    if systemctl is-enabled --quiet dropbear; then echo -e "${C_GREEN}ON${C_RESET}"; else echo -e "${C_RED}OFF${C_RESET}"; fi
}
function get_dropbear_ports() {
    if [ -f /etc/default/dropbear ]; then
        ports=$(grep "DROPBEAR_PORT" /etc/default/dropbear | cut -d'=' -f2 | sed 's/"//g')
        echo -e "${C_CYAN}$ports${C_RESET}"
    else
        echo -e "${C_RED}N/A${C_RESET}"
    fi
}

function show_progress() {
    # Esta es la show_progress original del Script A (no la toqué)
    local duration=$1; local message=$2; echo -n -e "$message ["; for i in $(seq 1 $duration); do echo -n "#"; sleep 0.1; done; echo "]";
}

# --- DROPBEAR (funciones originales) ---
function install_dropbear() {
    clear
    echo -e "${C_YELLOW}==================================${C_RESET}"
    echo -e "   ${C_WHITE}Instalación de Dropbear${C_RESET}"
    echo -e "${C_YELLOW}==================================${C_RESET}"

    read -p "Ingrese el puerto para Dropbear (solo uno): " dropbear_port
    if [[ -z "$dropbear_port" ]]; then
        echo -e "${C_RED}No se ingresó un puerto. Cancelando.${C_RESET}"
        sleep 2
        return
    fi

    echo -e "\n${C_CYAN}Iniciando instalación...${C_RESET}"

    echo -e "${C_YELLOW}Deteniendo temporalmente OpenSSH y su socket...${C_RESET}"
    sudo systemctl stop ssh.socket
    sudo systemctl stop ssh.service

    show_progress 10 "Actualizando..."
    sudo apt-get update -y > /dev/null 2>&1

    show_progress 15 "Instalando Dropbear..."
    sudo apt-get install -y dropbear > /dev/null 2>&1

    sudo cp /lib/systemd/system/dropbear.service /etc/systemd/system/dropbear.service
    sudo sed -i 's|^ExecStart=.*|ExecStart=/usr/sbin/dropbear -F -p $DROPBEAR_PORT $DROPBEAR_EXTRA_ARGS|' /etc/systemd/system/dropbear.service
    sudo systemctl daemon-reload

    sudo tee /etc/default/dropbear > /dev/null <<EOF
NO_START=0
DROPBEAR_PORT="${dropbear_port}"
DROPBEAR_EXTRA_ARGS="-B"
DROPBEAR_BANNER=""
EOF

    show_progress 10 "Iniciando Dropbear..."
    sudo systemctl restart dropbear

    echo -e "${C_GREEN}Reactivando OpenSSH y su socket...${C_RESET}"
    sudo systemctl start ssh.socket
    sudo systemctl start ssh.service

    if ! systemctl is-active --quiet dropbear; then
        echo -e "\n${C_RED}ADVERTENCIA: El servicio Dropbear no pudo iniciarse.${C_RESET}"
        echo -e "${C_YELLOW}Ejecute 'journalctl -u dropbear.service' para ver los detalles del error.${C_RESET}"
        read -n 1 -s -r -p "Presione Enter para continuar..."
    else
        echo -e "\n${C_GREEN}Dropbear instalado y configurado.${C_RESET}"
        read -n 1 -s -r -p "Presione Enter para ir al menú de administración..."
        dropbear_admin_menu
    fi
}

function uninstall_dropbear() {
    clear; echo -e "${C_YELLOW}==================================${C_RESET}"; echo -e "  ${C_WHITE}Desinstalación de Dropbear${C_RESET}"; echo -e "${C_YELLOW}==================================${C_RESET}"
    read -p "¿Está seguro? (s/N): " confirm
    if [[ "$confirm" =~ ^[sS]$ ]]; then
        show_progress 10 "Deteniendo..."; sudo systemctl stop dropbear > /dev/null 2>&1
        show_progress 15 "Desinstalando..."; sudo apt-get purge --auto-remove -y dropbear > /dev/null 2>&1
        sudo rm -f /etc/systemd/system/dropbear.service
        sudo systemctl daemon-reload
        echo -e "\n${C_GREEN}Dropbear desinstalado.${C_RESET}"
    else echo "${C_YELLOW}Cancelado.${C_RESET}"; fi
    read -n 1 -s -r -p "Presione Enter para continuar..."
}

function redefine_dropbear_ports() {
    clear
    echo -e "${C_YELLOW}==================================${C_RESET}"
    echo -e "   ${C_WHITE}Redefinir Puerto de Dropbear${C_RESET}"
    echo -e "${C_YELLOW}==================================${C_RESET}"
    echo -e "Puerto actual: $(get_dropbear_ports)"
    read -p "Ingrese el NUEVO puerto (solo uno): " dropbear_port
    if [[ -z "$dropbear_port" ]]; then
        echo -e "${C_RED}No se ingresó un puerto. Cancelando.${C_RESET}"
        sleep 2
        return
    fi

    sudo tee /etc/default/dropbear > /dev/null <<EOF
NO_START=0
DROPBEAR_PORT="${dropbear_port}"
DROPBEAR_EXTRA_ARGS="-B"
DROPBEAR_BANNER=""
EOF

    show_progress 10 "Reiniciando servicio..."
    sudo systemctl restart dropbear >/dev/null 2>&1 || sudo systemctl restart dropbear
    echo -e "\n${C_GREEN}Puerto de Dropbear actualizado.${C_RESET}"
    sleep 2
}

function restart_dropbear() {
    clear
    echo -e "${C_YELLOW}==================================${C_RESET}"
    echo -e "     ${C_WHITE}Reiniciando Dropbear${C_RESET}"
    echo -e "${C_YELLOW}==================================${C_RESET}"
    show_progress 10 "Reiniciando servicio..."
    sudo systemctl restart dropbear
    if [ $? -eq 0 ]; then 
        echo -e "${C_GREEN}Servicio reiniciado con éxito.${C_RESET}"
    else 
        echo -e "${C_RED}Fallo al reiniciar el servicio.${C_RESET}"
    fi
    read -n 1 -s -r -p "Presione Enter para continuar..."
}

function dropbear_admin_menu() {
    while true; do
        clear
        echo -e "${C_RED}=============================================${C_RESET}"
        echo -e "     ${C_WHITE}ADMINISTRADOR DROPBEAR By @Rufu99 V6${C_RESET}"
        echo -e "${C_RED}=============================================${C_RESET}"
        echo -e "${C_GREEN}[1] > ${C_WHITE}REDEFINIR PUERTOS"
        echo -e "${C_GREEN}[2] > ${C_WHITE}CONFIGURACION MANUAL (nano)"
        echo -e "${C_GREEN}[3] > ${C_WHITE}FIX DE INICIO CON EL SISTEMA [$(get_dropbear_autostart_status)]"
        echo -e "${C_RED}---------------------------------------------${C_RESET}"
        echo -e "${C_GREEN}[4] > ${C_WHITE}ESTADO DEL SERVICIO"
        echo -e "${C_GREEN}[5] > ${C_WHITE}REINICIAR SERVICIO"
        echo -e "${C_GREEN}[6] > ${C_WHITE}INICIAR/DETENER SERVICIO [$(get_dropbear_status)]"
        echo -e "${C_RED}---------------------------------------------${C_RESET}"
        echo -e "${C_GREEN}[0] > ${C_WHITE}VOLVER   ${C_GREEN}[7] > ${C_RED}DESINSTALAR DROPBEAR${C_RESET}"
        echo -e "${C_RED}=============================================${C_RESET}"
        echo -e -n "${C_YELLOW}Seleccione una opción: ${C_RESET}"
        read admin_opcion

        case $admin_opcion in
            1) redefine_dropbear_ports ;;
            2) sudo nano /etc/default/dropbear ;;
            3) 
                if systemctl is-enabled --quiet dropbear; then 
                    sudo systemctl disable dropbear > /dev/null 2>&1
                    echo -e "${C_YELLOW}Inicio automático desactivado.${C_RESET}"
                else 
                    sudo systemctl enable dropbear > /dev/null 2>&1
                    echo -e "${C_GREEN}Inicio automático activado.${C_RESET}"
                fi
                sleep 2 ;;
            4) clear; systemctl status dropbear --no-pager; read -n 1 -s -r -p "Presione Enter para continuar..." ;;
            5) restart_dropbear ;;
            6) 
                if systemctl is-active --quiet dropbear; then
                    sudo systemctl stop dropbear; echo -e "${C_YELLOW}Servicio Dropbear detenido.${C_RESET}"
                else
                    sudo systemctl start dropbear; sleep 1
                    if systemctl is-active --quiet dropbear; then echo -e "${C_GREEN}Servicio Dropbear iniciado.${C_RESET}"; else echo -e "${C_RED}Fallo al iniciar.${C_RESET}"; fi
                fi
                sleep 2 ;;
            7) uninstall_dropbear; return ;;
            0) break ;;
            *) echo -e "${C_RED}Opción inválida${C_RESET}"; sleep 1 ;;
        esac
    done
}

function dropbear_submenu() {
    while true; do
        clear
        if is_dropbear_installed; then
            dropbear_admin_menu
            break
        else
            echo -e "${C_YELLOW}==================================${C_RESET}"; echo -e "           ${C_WHITE}Submenú Dropbear${C_RESET}"; echo -e "${C_YELLOW}==================================${C_RESET}"
            echo -e "${C_WHITE}Dropbear no está instalado.${C_RESET}"; echo ""
            echo -e "${C_GREEN}1) Instalar Dropbear"
            echo -e "${C_GREEN}0) Volver"
            echo -e "${C_YELLOW}==================================${C_RESET}"
            read -p "${C_YELLOW}Seleccione una opción: ${C_RESET}" db_opcion
            case $db_opcion in
                1) install_dropbear;;
                0) break;;
                *) echo "${C_RED}Opción inválida${C_RESET}"; sleep 1;;
            esac
        fi
    done
}


# --- STUNNEL (funciones originales del Script A) ---
function install_stunnel4() {
    clear; echo -e "${C_YELLOW}==================================${C_RESET}"; echo -e "   ${C_WHITE}Instalación de S-Tunnel 4${C_RESET}"; echo -e "${C_YELLOW}==================================${C_RESET}"
    read -p "Ingrese el puerto S-Tunnel (predeterminado: 443): " stunnel_port; stunnel_port=${stunnel_port:-443}
    read -p "Ingrese el puerto de redireccionamiento interno (predeterminado: 22): " internal_port; internal_port=${internal_port:-22}
    echo -e "\n${C_CYAN}Iniciando instalación...${C_RESET}"; show_progress 10 "Actualizando..."; sudo apt-get update -y > /dev/null 2>&1
    show_progress 15 "Instalando stunnel4..."; sudo apt-get install stunnel4 -y > /dev/null 2>&1
    show_progress 10 "Configurando..."; sudo sed -i 's/ENABLED=0/ENABLED=1/g' /etc/default/stunnel4

    sudo mkdir -p /var/run/stunnel4
    sudo chown stunnel4:stunnel4 /var/run/stunnel4

    sudo openssl genrsa -out /etc/stunnel/stunnel.key 2048 > /dev/null 2>&1
    sudo openssl req -new -x509 -key /etc/stunnel/stunnel.key -out /etc/stunnel/stunnel.crt -days 3650 -nodes -subj "/C=US/ST=Denial/L=Springfield/O=Dis/CN=www.example.com" > /dev/null 2>&1
    sudo chmod 600 /etc/stunnel/stunnel.key

    echo "pid = /var/run/stunnel4/stunnel.pid
client = no

[ssh]
cert = /etc/stunnel/stunnel.crt
key = /etc/stunnel/stunnel.key
accept = $stunnel_port
connect = 127.0.0.1:$internal_port
" | sudo tee /etc/stunnel/stunnel.conf > /dev/null

    show_progress 10 "Reiniciando servicio..."; sudo systemctl restart stunnel4
    sudo systemctl enable stunnel4 > /dev/null 2>&1

    if ! systemctl is-active --quiet stunnel4; then 
        echo -e "\n${C_RED}ADVERTENCIA: El servicio stunnel4 no pudo iniciarse.${C_RESET}"
        read -n 1 -s -r -p "Presione Enter para continuar..."
    else 
        echo -e "\n${C_GREEN}S-Tunnel 4 instalado y configurado!${C_RESET}"
        read -n 1 -s -r -p "Presione Enter para ir al menú de administración..."
        stunnel4_admin_menu
    fi
}

function uninstall_stunnel4() {
    clear; echo -e "${C_YELLOW}==================================${C_RESET}"; echo -e "  ${C_WHITE}Desinstalación de S-Tunnel 4${C_RESET}"; echo -e "${C_YELLOW}==================================${C_RESET}"
    read -p "¿Está seguro? (s/N): " confirm
    if [[ "$confirm" =~ ^[sS]$ ]]; then
        show_progress 10 "Deteniendo..."; sudo systemctl stop stunnel4 > /dev/null 2>&1
        show_progress 15 "Desinstalando..."; sudo apt-get purge --auto-remove -y stunnel4 > /dev/null 2>&1
        show_progress 10 "Limpiando..."; sudo rm -rf /etc/stunnel /etc/default/stunnel4 /var/run/stunnel4
        echo -e "\n${C_GREEN}S-Tunnel 4 desinstalado.${C_RESET}"
    else echo "${C_YELLOW}Cancelado.${C_RESET}"; fi
    read -n 1 -s -r -p "Presione Enter para continuar..."
}

function add_ssl_port() {
    clear; echo -e "${C_YELLOW}==================================${C_RESET}"; echo -e "     ${C_WHITE}Agregar Puertos SSL${C_RESET}"; echo -e "${C_YELLOW}==================================${C_RESET}"
    read -p "Ingrese el nuevo puerto SSL a agregar: " new_port
    if [[ -z "$new_port" ]]; then echo "${C_RED}Puerto no puede estar vacío.${C_RESET}"; elif grep -q "accept = $new_port" /etc/stunnel/stunnel.conf; then echo "${C_YELLOW}El puerto $new_port ya está configurado.${C_RESET}"; else
        read -p "Ingrese el puerto de redireccionamiento interno para $new_port (predeterminado: $(get_internal_port)): " internal_redirect_port
        internal_redirect_port=${internal_redirect_port:-$(get_internal_port)}
        if [[ -z "$internal_redirect_port" ]]; then
            echo -e "${C_RED}El puerto de redireccionamiento interno no puede estar vacío. Cancelando.${C_RESET}"
            sleep 2
            return
        fi
        echo -e "\n[ssh-${new_port}]\ncert = /etc/stunnel/stunnel.crt\nkey = /etc/stunnel/stunnel.key\naccept = ${new_port}\nconnect = 127.0.0.1:${internal_redirect_port}\n" | sudo tee -a /etc/stunnel/stunnel.conf > /dev/null
        show_progress 5 "Reiniciando..."; sudo systemctl restart stunnel4
        if [ $? -eq 0 ]; then echo "${C_GREEN}Puerto $new_port agregado.${C_RESET}"; else echo -e "${C_RED}Fallo al reiniciar.${C_RESET}"; fi
    fi
    read -n 1 -s -r -p "Presione cualquier tecla para continuar..."
}

function remove_ssl_port() {
    clear; echo -e "${C_YELLOW}==================================${C_RESET}"; echo -e "     ${C_WHITE}Quitar Puertos SSL${C_RESET}"; echo -e "${C_YELLOW}==================================${C_RESET}"
    read -p "Ingrese el puerto SSL a quitar: " port_to_remove
    if [[ -z "$port_to_remove" ]]; then echo "${C_RED}Puerto no puede estar vacío.${C_RESET}"; elif ! grep -q "accept = $port_to_remove" /etc/stunnel/stunnel.conf; then echo "${C_YELLOW}El puerto $port_to_remove no está configurado.${C_RESET}"; else
        line_num_start=$(grep -n "accept = $port_to_remove" /etc/stunnel/stunnel.conf | head -n 1 | cut -d: -f1)
        if [ "$line_num_start" -le 7 ]; then
             echo -e "${C_RED}Error: No se puede quitar el puerto principal desde este menú.${C_RESET}"
             echo "Para cambiarlo, edite el archivo manualmente (Opción 4)."
        else
            sudo sed -i "$((line_num_start-4)),$((line_num_start+1))d" /etc/stunnel/stunnel.conf
            show_progress 5 "Reiniciando..."; sudo systemctl restart stunnel4
            if [ $? -eq 0 ]; then echo "${C_GREEN}Puerto $port_to_remove quitado.${C_RESET}"; else echo -e "${C_RED}Fallo al reiniciar.${C_RESET}"; fi
        fi
    fi
    read -n 1 -s -r -p "Presione cualquier tecla para continuar..."
}

function edit_redirect_port() {
    clear; echo -e "${C_YELLOW}==================================${C_RESET}"; echo -e "  ${C_WHITE}Editar Puerto de Redirección${C_RESET}"; echo -e "${C_YELLOW}==================================${C_RESET}"
    current_internal_port=$(get_internal_port)
    read -p "Ingrese el nuevo puerto de redireccionamiento interno (actual: $current_internal_port): " new_redir_port
    if [[ -z "$new_redir_port" ]]; then echo "${C_RED}Puerto no puede estar vacío.${C_RESET}"; else
        sudo sed -i "s/connect = 127.0.0.1:$current_internal_port/connect = 127.0.0.1:$new_redir_port/g" /etc/stunnel/stunnel.conf
        show_progress 5 "Reiniciando..."; sudo systemctl restart stunnel4
        if [ $? -eq 0 ]; then echo "${C_GREEN}Puerto de redirección actualizado a $new_redir_port.${C_RESET}"; else echo -e "${C_RED}Fallo al reiniciar.${C_RESET}"; fi
    fi
    read -n 1 -s -r -p "Presione cualquier tecla para continuar..."
}

function restart_stunnel() {
    clear; echo -e "${C_YELLOW}==================================${C_RESET}"; echo -e "     ${C_WHITE}Reiniciando Servicio${C_RESET}"; echo -e "${C_YELLOW}==================================${C_RESET}"
    show_progress 10 "Reiniciando S-Tunnel 4..."
    sudo systemctl restart stunnel4
    if [ $? -eq 0 ]; then echo "${C_GREEN}Servicio reiniciado con éxito.${C_RESET}"; else echo -e "${C_RED}Fallo al reiniciar el servicio.${C_RESET}"; fi
    read -n 1 -s -r -p "Presione cualquier tecla para continuar..."
}

function stunnel4_admin_menu() {
    while true; do
        clear
        echo -e "${C_YELLOW}==================================${C_RESET}"
        echo -e "  ${C_WHITE}Stunnel-manager by: MaulYnetZ V8${C_RESET}"
        echo -e "${C_YELLOW}==================================${C_RESET}"
        echo -e "${C_WHITE}PUERTOS: $(get_stunnel_ports)"
        echo -e "${C_YELLOW}==================================${C_RESET}"
        echo -e "${C_GREEN}[1] > ${C_WHITE}AGREGAR PUERTOS SSL"
        echo -e "${C_GREEN}[2] > ${C_WHITE}QUITAR PUERTOS SSL"
        echo -e "${C_YELLOW}----------------------------------${C_RESET}"
        echo -e "${C_GREEN}[3] > ${C_WHITE}EDITAR PUERTO DE REDIRECCION"
        echo -e "${C_GREEN}[4] > ${C_WHITE}EDITAR MANUAL (NANO)"
        echo -e "${C_YELLOW}----------------------------------${C_RESET}"
        echo -e "${C_GREEN}[5] > ${C_WHITE}INICIO CON EL SISTEMA [$(get_autostart_status)]"
        echo -e "${C_GREEN}[6] > ${C_WHITE}INICIAR/PARAR SERVICIO SSL [$(get_stunnel_status)]"
        echo -e "${C_GREEN}[7] > ${C_WHITE}REINICIAR SERVICIO SSL"
        echo -e "${C_YELLOW}----------------------------------${C_RESET}"
        echo -e "${C_RED}[8] > DESINSTALAR STUNNEL4"
        echo -e "${C_YELLOW}==================================${C_RESET}"
        echo -e "${C_GREEN}[0] > ${C_WHITE}VOLVER"
        echo -e "${C_YELLOW}==================================${C_RESET}"
        echo -e -n "${C_YELLOW}Seleccione una opción: ${C_RESET}"
        read admin_opcion

        case $admin_opcion in
            1) add_ssl_port ;;
            2) remove_ssl_port ;;
            3) edit_redirect_port ;;
            4) sudo nano /etc/stunnel/stunnel.conf ;;
            5) if systemctl is-enabled --quiet stunnel4; then sudo systemctl disable stunnel4 > /dev/null 2>&1; echo -e "${C_YELLOW}Inicio automático desactivado.${C_RESET}"; else sudo systemctl enable stunnel4 > /dev/null 2>&1; echo -e "${C_GREEN}Inicio automático activado.${C_RESET}"; fi; sleep 2 ;;
            6) 
                if systemctl is-active --quiet stunnel4; then
                    sudo systemctl stop stunnel4; echo -e "${C_YELLOW}Servicio SSL detenido.${C_RESET}"
                else
                    sudo systemctl start stunnel4; sleep 1
                    if systemctl is-active --quiet stunnel4; then echo -e "${C_GREEN}Servicio SSL iniciado.${C_RESET}"; else echo -e "${C_RED}Fallo al iniciar.${C_RESET}"; fi
                fi
                sleep 2 ;;
            7) restart_stunnel ;;
            8) uninstall_stunnel4; return;;
            0) break ;;
            *) echo "${C_RED}Opción inválida${C_RESET}"; sleep 1;;
        esac
    done
}

function ssl_submenu() {
    while true; do
        clear
        if is_stunnel4_installed; then
            stunnel4_admin_menu
            break
        else
            echo -e "${C_YELLOW}==================================${C_RESET}"; echo -e "           ${C_WHITE}Submenú SSL${C_RESET}"; echo -e "${C_YELLOW}==================================${C_RESET}"
            echo -e "${C_WHITE}S-Tunnel 4 no está instalado.${C_RESET}"; echo ""
            echo -e "${C_GREEN}1) Instalar S-Tunnel 4"
            echo -e "${C_GREEN}0) Volver"
            echo -e "${C_YELLOW}==================================${C_RESET}"
        echo -e -n "${C_YELLOW}Seleccione una opción: ${C_RESET}"
        read admin_opcion

        case $admin_opcion in
                1) install_stunnel4;;
                0) break;;
                *) echo "${C_RED}Opción inválida${C_RESET}"; sleep 1;;
            esac
        fi
    done
}

# ---------------------------
# (B) --- Añadidas: Animaciones + BadVPN + UDP-Custom (tomadas de Script B)
# ---------------------------

# -- Animaciones (NO sobrescriben la show_progress original de A) --
show_progress_anim() {
    local message="$1"
    shift
    local steps_array=("$@")

    clear
    echo -e "${C_RED}======================================${C_RESET}"
    echo -e "${C_YELLOW}           ${message}           ${C_RESET}"
    echo -e "${C_RED}======================================${C_RESET}"
    echo -e "\n${C_YELLOW}Por favor, aguarda un momento${C_RESET}\n"

    for step in "${steps_array[@]}"; do
        printf "${C_WHITE}%s" "$step"
        local padding_length=$(( 38 - ${#step} ))
        for (( i=0; i<padding_length; i++ )); do printf " "; done
        sleep 1.5
        echo -e "${C_GREEN}OK${C_RESET}"
    done
}

show_service_action_progress_anim() {
    local action_message="$1"
    shift
    local service_action_steps=("$@")

    echo -e "\n${C_YELLOW}           ${action_message}           ${C_RESET}"
    echo -e "\n${C_YELLOW}Por favor, aguarda un momento${C_RESET}\n"

    for step in "${service_action_steps[@]}"; do
        printf "${C_WHITE}%s" "$step"
        local padding_length=$(( 38 - ${#step} ))
        for (( i=0; i<padding_length; i++ )); do printf " "; done
        sleep 1
        echo -e "${C_GREEN}OK${C_RESET}"
    done
}

# --- BADVPN-UDP (copiado de Script B, sin alterar la lógica; usa animaciones nuevas) ---
function is_badvpn_installed() { if [ -f /bin/badvpn-udpgw ] && [ -f /bin/badvpn ]; then return 0; else return 1; fi; }

function get_badvpn_status() {
    if pgrep -x "badvpn-udpgw" > /dev/null; then 
        echo -e "${C_GREEN}ON${C_RESET}"
    else 
        echo -e "${C_RED}OFF${C_RESET}"
    fi
}

function install_badvpn() {
    clear
    echo -e "${C_MAGENTA}======================================${C_RESET}"
    echo -e "    ${C_WHITE}Instalador Automático de BadVPN${C_RESET}"
    echo -e "${C_MAGENTA}======================================${C_RESET}\n"

    local steps=(
        "Actualizando repositorios.........."
        "Instalando dependencias............."
        "Descargando script instalador......"
        "Ejecutando instalador..............."
        "Limpiando archivos temporales......."
    )
    show_progress_anim "INSTALADOR BadVPN-UDP" "${steps[@]}"

    sudo apt-get update -y >/dev/null 2>&1
    sudo apt-get install -y wget screen >/dev/null 2>&2 || true
    wget -q -O /tmp/easyinstall https://raw.githubusercontent.com/powermx/badvpn/master/easyinstall
    sudo bash /tmp/easyinstall >/dev/null 2>&1 || true
    rm -f /tmp/easyinstall >/dev/null 2>&1 || true

    if is_badvpn_installed; then
        sudo /bin/badvpn start >/dev/null 2>&1 || true
    else
        echo -e "\n${C_RED}La instalación de BadVPN falló.${C_RESET}"
        read -n 1 -s -r -p "Presione Enter para continuar..."
    fi
}

function badvpn_admin_menu() {
    while true; do
        clear; local status=$(get_badvpn_status)
        echo -e "${C_BLUE}======================================${C_RESET}"
        echo -e "${C_YELLOW}    ADMINISTRADOR DE BADVPN-UDP    ${C_RESET}"
        echo -e "${C_BLUE}======================================${C_RESET}"
        echo -e "${C_GRAY}Estado Actual: $status${C_RESET}\n"
        echo -e "${C_CYAN}[1]${C_WHITE} Iniciar Servicio${C_RESET}"
        echo -e "${C_CYAN}[2]${C_WHITE} Detener Servicio${C_RESET}"
        echo -e "${C_CYAN}[3]${C_WHITE} Reiniciar Servicio${C_RESET}"
        echo -e "${C_RED}[4]${C_WHITE} Desinstalar BadVPN${C_RESET}"
        echo -e "${C_YELLOW}[0]${C_WHITE} Volver al Menú Principal${C_RESET}\n"
        echo -e -n "${C_YELLOW}Seleccione una opción: ${C_RESET}"
        read opt
        case $opt in
            1) show_service_action_progress_anim "INICIANDO SERVICIO" "Iniciando BadVPN......"; sudo /bin/badvpn start >/dev/null 2>&1 || true;;
            2) show_service_action_progress_anim "DETENIENDO SERVICIO" "Deteniendo BadVPN....."; killall badvpn-udpgw >/dev/null 2>&1 || true;;
            3) show_service_action_progress_anim "REINICIANDO SERVICIO" "Reiniciando BadVPN...."; killall badvpn-udpgw >/dev/null 2>&1 || sudo screen -dms bad badvpn-udpgw --listen-addr 127.0.0.1:7300 --max-clients 1000 --max-connections-for-client 1000 --client-socket-sndbuf 0 --udp-mtu 9000 >/dev/null 2>&1 || true;;
            4) 
                show_service_action_progress_anim "DESINSTALANDO BADVPN" \
                    "Deteniendo BadVPN......" \
                    "Removiendo binarios BadVPN......" \
                    "Limpiando archivos temporales......"
                killall badvpn-udpgw >/dev/null 2>&1 || true
                sudo rm -f /bin/badvpn /bin/badvpn-udpgw >/dev/null 2>&1 || true
                sleep 2
                return
                ;;
            0) break ;;
            *) echo -e "${C_RED}Opción inválida.${C_RESET}"; sleep 1 ;;
        esac
    done
}

function badvpn_submenu() {
    while true; do
        clear
        if is_badvpn_installed; then
            badvpn_admin_menu; break
        else
            echo -e "${C_WHITE}BadVPN no está instalado.${C_RESET}\n"
            echo -e "${C_GREEN}[1] Instalar BadVPN${C_RESET}"
            echo -e "${C_YELLOW}[0] Volver${C_RESET}\n"
            echo -e -n "${C_YELLOW}Opción: ${C_RESET}"; read opt
            case $opt in 1) install_badvpn;; 0) break;; *) echo -e "${C_RED}Inválido.${C_RESET}"; sleep 1;; esac
        fi
    done
}

# --- UDP-CUSTOM (copiado de Script B, sin alterar lógica; usa animaciones nuevas) ---
SERVICE="udpcustom"
BINARY="/root/udp/udp-custom"
CONFIG="/root/udp/config.json"

function get_udpcustom_status() {
    if systemctl is-active --quiet $SERVICE 2>/dev/null; then
        echo -e "${C_GREEN}ON${C_RESET}"
    else
        echo -e "${C_RED}OFF${C_RESET}"
    fi
}

function install_udpcustom() {
    clear
    echo -e "${C_MAGENTA}======================================${C_RESET}"
    echo -e "   ${C_WHITE}Instalador Automático de UDP-Custom${C_RESET}"
    echo -e "${C_MAGENTA}======================================${C_RESET}\n"

    local install_steps=(
        "Descargando binario UDP-Custom...."
        "chmod +x udp-custom..............."
        "Creando config.json..............."
        "Instalando servicio..............."
        "systemctl daemon-reload..........."
        "systemctl start udpcustom........."
        "systemctl enable udpcustom........"
    )
    show_progress_anim "INSTALADOR UDP-CUSTOM" "${install_steps[@]}"

    sudo mkdir -p /root/udp >/dev/null 2>&1
    cd /root/udp >/dev/null 2>&1 || true
    sudo wget -q -O $BINARY https://raw.githubusercontent.com/MaulynetZ/Udp-binario/main/udp-custom >/dev/null 2>&1 || true
    sudo chmod +x $BINARY >/dev/null 2>&1 || true

    # Crear config.json solo si no existe
    if [[ ! -f $CONFIG ]]; then
        cat > $CONFIG <<EOF
{
  "listen": ":36712",
  "stream_buffer": 209715200,
  "receive_buffer": 209715200,
  "auth": { "mode": "password" }
}
EOF
    fi

    sudo tee /etc/systemd/system/$SERVICE.service > /dev/null <<EOF
[Unit]
Description=UDP-Custom Service
After=network.target

[Service]
ExecStart=$BINARY -c $CONFIG
Restart=always
User=root
LimitNOFILE=65535

[Install]
WantedBy=multi-user.target
EOF

    sudo systemctl daemon-reload >/dev/null 2>&1 || true
    sudo systemctl enable $SERVICE >/dev/null 2>&1 || true
    sudo systemctl start $SERVICE >/dev/null 2>&1 || true
}

function uninstall_udpcustom() {
    local uninstall_steps=(
        "systemctl stop udpcustom.........."
        "systemctl disable udpcustom......."
        "Removiendo servicio..............."
        "systemctl daemon-reload..........."
        "Removiendo binario udp-custom....."
    )
    show_progress_anim "DESINSTALADOR UDP-CUSTOM" "${uninstall_steps[@]}"

    sudo systemctl stop $SERVICE >/dev/null 2>&1 || true
    sudo systemctl disable $SERVICE >/dev/null 2>&1 || true
    sudo rm -f /etc/systemd/system/$SERVICE.service >/dev/null 2>&1 || true
    sudo systemctl daemon-reload >/dev/null 2>&1 || true
    sudo rm -f $BINARY >/dev/null 2>&1 || true
}

function udpcustom_admin_menu() {
    while true; do
        clear; local status=$(get_udpcustom_status)
        echo -e "${C_BLUE}======================================${C_RESET}"
        echo -e "${C_YELLOW}    ADMINISTRADOR DE UDP-CUSTOM    ${C_RESET}"
        echo -e "${C_BLUE}======================================${C_RESET}"
        echo -e "${C_GRAY}Estado Actual: $status${C_RESET}\n"
        echo -e "${C_CYAN}[1]${C_WHITE} Iniciar Servicio${C_RESET}"
        echo -e "${C_CYAN}[2]${C_WHITE} Detener Servicio${C_RESET}"
        echo -e "${C_CYAN}[3]${C_WHITE} Reiniciar Servicio${C_RESET}"
        echo -e "${C_RED}[4]${C_WHITE} Desinstalar UDP-Custom${C_RESET}"
        echo -e "${C_YELLOW}[0]${C_WHITE} Volver al Menú Principal${C_RESET}\n"
        echo -e -n "${C_YELLOW}Opción: ${C_RESET}"; read opt
        case $opt in
            1) show_service_action_progress_anim "INICIANDO SERVICIO" "Iniciando udpcustom......"; sudo systemctl start $SERVICE >/dev/null 2>&1 || true ;;
            2) show_service_action_progress_anim "DETENIENDO SERVICIO" "Deteniendo udpcustom....."; sudo systemctl stop $SERVICE >/dev/null 2>&1 || true ;;
            3) show_service_action_progress_anim "REINICIANDO SERVICIO" "Reiniciando udpcustom...."; sudo systemctl restart $SERVICE >/dev/null 2>&1 || true ;;
            4) uninstall_udpcustom; return ;;
            0) break ;;
            *) echo -e "${C_RED}Inválido.${C_RESET}"; sleep 1 ;;
        esac
    done
}

function udpcustom_submenu() {
    while true; do
        clear
        if sudo systemctl list-unit-files 2>/dev/null | grep -q "$SERVICE.service"; then
            udpcustom_admin_menu; break
        else
            echo -e "${C_WHITE}UDP-Custom no está instalado.${C_RESET}\n"
            echo -e "${C_GREEN}[1] Instalar UDP-Custom${C_RESET}"
            echo -e "${C_YELLOW}[0] Volver${C_RESET}\n"
            echo -e -n "${C_YELLOW}Opción: ${C_RESET}"; read opt
            case $opt in 1) install_udpcustom;; 0) break;; *) echo -e "${C_RED}Inválido.${C_RESET}"; sleep 1;; esac
        fi
    done
}

# ---------------------------
# (A) --- Menú Principal ORIGINAL del Script A (con enlaces a 3/4 añadidos)
# ---------------------------

function main_menu() {
    while true; do
        clear
        echo -e "${C_BLUE}==================================================${C_RESET}"
        echo -e "${C_WHITE}         PANEL DE CONTROL DE PROTOCOLOS UDP${C_RESET}"
        echo -e "${C_GRAY}         SCRIPT BY: MaulYnetZ | Versión: 1.0${C_RESET}"
        echo -e "${C_BLUE}==================================================${C_RESET}"
        echo -e "${C_CYAN}[1] ${C_WHITE}Dropbear ............................... [$(if is_dropbear_installed; then get_dropbear_status; else echo -e "${C_RED}OFF${C_RESET}"; fi)]${C_RESET}"
        echo -e "${C_CYAN}[2] ${C_WHITE}SSL (Stunnel) .......................... [$(if is_stunnel4_installed; then get_stunnel_status; else echo -e "${C_RED}OFF${C_RESET}"; fi)]${C_RESET}"
        echo -e "${C_CYAN}[3] ${C_WHITE}BadVPN-UDP ............................. [$(get_badvpn_status)]${C_RESET}"
        echo -e "${C_CYAN}[4] ${C_WHITE}UDP-Custom ............................. [$(get_udpcustom_status)]${C_RESET}"
        echo -e "${C_BLUE}==================================================${C_RESET}"
        echo -e "${C_CYAN}[0] ${C_WHITE}Salir del Panel${C_RESET}"
        echo -e "${C_BLUE}==================================================${C_RESET}"
        echo -e -n "${C_YELLOW}Seleccione una opción: ${C_RESET}"
        read opcion

        case $opcion in
            1) dropbear_submenu;;
            2) ssl_submenu;;
            3) badvpn_submenu;;
            4) udpcustom_submenu;;
            0)
              bash /root/MaulYnetZ/Panel_MaulYnetZ.sh
                      exit 0;;
            *) echo -e "${C_RED}Opción inválida${C_RESET}"; sleep 1;;
        esac
    done
}

# Punto de entrada
main_menu