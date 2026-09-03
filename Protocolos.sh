#!/bin/bash

# ============================================================
# Panel de Control PRO (Integración: Script A + BadVPN/UDP-Custom)
# ============================================================
# Nota: Mantuve íntegro el menú, colores y lógica del Script A.
# Se agregaron BadVPN-UDP y UDP-Custom (tomadas de Script B) y sus
# animaciones como funciones separadas para no interferir con A.
# ============================================================

# --- Definición de Colores (igual que Script A, con agregado C_GRAY) ---
C_RED=$'\033[1;31m'
C_GREEN=$'\033[1;32m'
C_YELLOW=$'\033[1;33m' # Mantener el color amarillo estándar
C_BLUE=$'\033[1;34m'
C_MAGENTA=$'\033[1;35m'
C_CYAN=$'\033[1;36m'
C_WHITE=$'\033[1;37m'
C_RESET=$'\033[0m'
C_GRAY=$'\033[1;90m'   # añadido para elementos de estado (no altera paleta A)

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

# ================================================================
# HYSTERIA 1 + API — módulo para Protocolos.sh
# Insertar antes de function main_menu() y añadir opción 5 al menú.
# No copia secretos ni certificados del servidor original.
# ================================================================
HYSTERIA_BIN="/usr/local/bin/hysteria"
HYSTERIA_DIR="/etc/hysteria"
HYSTERIA_CONFIG="$HYSTERIA_DIR/config.json"
HYSTERIA_AUTH="$HYSTERIA_DIR/auth.sh"
HYSTERIA_SERVICE="hysteria.service"
HYSTERIA_API_SERVICE="mastervpn-api.service"
HYSTERIA_URL="https://github.com/apernet/hysteria/releases/download/v1.3.5/hysteria-linux-amd64"
HYSTERIA_SHA256="41dc8bc3fff6fc1f031666eb294f10b481b80b66229d7c6aca88398d0fba839d"

function is_hysteria_installed() {
    [ -x "$HYSTERIA_BIN" ] && [ -f "$HYSTERIA_CONFIG" ]
}

function get_hysteria_status() {
    if systemctl is-active --quiet "$HYSTERIA_SERVICE"; then echo -e "${C_GREEN}ON${C_RESET}"; else echo -e "${C_RED}OFF${C_RESET}"; fi
}

function hysteria_nat_backup() {
    local dir="/root/hysteria-nat-backup-$(date +%Y%m%d-%H%M%S)"
    sudo install -d -m 0700 "$dir"
    sudo iptables-save > "$dir/iptables.v4" 2>/dev/null || true
    sudo ip6tables-save > "$dir/iptables.v6" 2>/dev/null || true
    sudo nft list ruleset > "$dir/nft.rules" 2>/dev/null || true
    echo "$dir"
}

function hysteria_nat_clear_managed() {
    while sudo iptables -t nat -C PREROUTING -p udp --dport 1:65535 -j REDIRECT --to-ports 36712 2>/dev/null; do sudo iptables -t nat -D PREROUTING -p udp --dport 1:65535 -j REDIRECT --to-ports 36712; done
    while sudo iptables -t nat -C PREROUTING -i ens3 -p udp --dport 1:65535 -j DNAT --to-destination :36712 2>/dev/null; do sudo iptables -t nat -D PREROUTING -i ens3 -p udp --dport 1:65535 -j DNAT --to-destination :36712; done
    while sudo ip6tables -t nat -C PREROUTING -p udp --dport 1:65535 -j REDIRECT --to-ports 36712 2>/dev/null; do sudo ip6tables -t nat -D PREROUTING -p udp --dport 1:65535 -j REDIRECT --to-ports 36712; done
    while sudo ip6tables -t nat -C PREROUTING -i ens3 -p udp --dport 1:65535 -j DNAT --to-destination :36712 2>/dev/null; do sudo ip6tables -t nat -D PREROUTING -i ens3 -p udp --dport 1:65535 -j DNAT --to-destination :36712; done
}

function hysteria_nat_persist() {
    sudo install -d -m 0755 /etc/iptables
    sudo iptables-save | sudo tee /etc/iptables/rules.v4 >/dev/null
    sudo ip6tables-save | sudo tee /etc/iptables/rules.v6 >/dev/null 2>&1 || true
    if command -v netfilter-persistent >/dev/null 2>&1; then sudo netfilter-persistent save >/dev/null 2>&1 || true; fi
}

function hysteria_configure_nat() {
    clear
    echo -e "${C_WHITE}Modo de redirección Hysteria${C_RESET}"
    echo "1) Hysteria independiente: UDP 1:65535 -> puerto Hysteria"
    echo "2) Convivir con UDP-Custom: 1:19999 -> 36712, 20000:50000 -> puerto Hysteria, 50001:65535 -> 36712"
    read -r -p "Seleccione [1/2]: " mode
    local backup
    backup=$(hysteria_nat_backup)
    hysteria_nat_clear_managed
    if [ "$mode" = "1" ]; then
        sudo iptables -t nat -A PREROUTING -p udp --dport 1:65535 -j REDIRECT --to-ports "$HY_PORT"
        sudo ip6tables -t nat -A PREROUTING -p udp --dport 1:65535 -j REDIRECT --to-ports "$HY_PORT" 2>/dev/null || true
    elif [ "$mode" = "2" ]; then
        sudo iptables -t nat -A PREROUTING -p udp --dport 1:19999 -j REDIRECT --to-ports 36712
        sudo iptables -t nat -A PREROUTING -p udp --dport 20000:50000 -j REDIRECT --to-ports "$HY_PORT"
        sudo iptables -t nat -A PREROUTING -p udp --dport 50001:65535 -j REDIRECT --to-ports 36712
        sudo ip6tables -t nat -A PREROUTING -p udp --dport 1:19999 -j REDIRECT --to-ports 36712 2>/dev/null || true
        sudo ip6tables -t nat -A PREROUTING -p udp --dport 20000:50000 -j REDIRECT --to-ports "$HY_PORT" 2>/dev/null || true
        sudo ip6tables -t nat -A PREROUTING -p udp --dport 50001:65535 -j REDIRECT --to-ports 36712 2>/dev/null || true
    else
        echo "Modo inválido; no se modificaron reglas."; return 1
    fi
    hysteria_nat_persist
    echo -e "${C_GREEN}NAT aplicado y persistente. Backup: $backup${C_RESET}"
}

function install_hysteria() {
    clear
    echo -e "${C_YELLOW}==================================${C_RESET}"
    echo -e "${C_WHITE}   Instalador Hysteria 1 + API${C_RESET}"
    echo -e "${C_YELLOW}==================================${C_RESET}"
    read -r -p "Puerto UDP de Hysteria [20000]: " HY_PORT
    HY_PORT="${HY_PORT:-20000}"
    read -r -p "Obfs [MaulynetZ]: " HY_OBFS
    HY_OBFS="${HY_OBFS:-MaulynetZ}"
    read -r -p "Subida Mbps [60]: " HY_UP
    HY_UP="${HY_UP:-60}"
    read -r -p "Bajada Mbps [75]: " HY_DOWN
    HY_DOWN="${HY_DOWN:-75}"
    read -r -p "Instalar también API local en :8989? [S/n]: " HY_API_CHOICE
    HY_API_CHOICE="${HY_API_CHOICE:-S}"

    if ! [[ "$HY_PORT" =~ ^[0-9]+$ ]] || [ "$HY_PORT" -lt 1 ] || [ "$HY_PORT" -gt 65535 ]; then echo "Puerto inválido"; return 1; fi
    if ! [[ "$HY_UP" =~ ^[0-9]+$ ]] || ! [[ "$HY_DOWN" =~ ^[0-9]+$ ]]; then echo "Velocidad inválida"; return 1; fi

    sudo apt-get update -y || return 1
    sudo apt-get install -y ca-certificates curl openssl python3 || return 1
    sudo install -d -m 0755 "$HYSTERIA_DIR"
    local tmp
    tmp=$(mktemp)
    if ! curl -fL --retry 3 --proto '=https' --tlsv1.2 "$HYSTERIA_URL" -o "$tmp"; then rm -f "$tmp"; return 1; fi
    if ! printf '%s  %s\n' "$HYSTERIA_SHA256" "$tmp" | sha256sum -c -; then echo "Hash no coincide; abortando"; rm -f "$tmp"; return 1; fi
    sudo install -m 0755 "$tmp" "$HYSTERIA_BIN"
    rm -f "$tmp"

    if [ ! -s "$HYSTERIA_DIR/server.key" ] || [ ! -s "$HYSTERIA_DIR/server.crt" ]; then
        sudo openssl req -x509 -newkey rsa:2048 -nodes -days 3650 \
          -keyout "$HYSTERIA_DIR/server.key" -out "$HYSTERIA_DIR/server.crt" \
          -subj '/C=US/ST=NY/L=NY/O=VPN/CN=hysteria' >/dev/null 2>&1
        sudo chmod 0600 "$HYSTERIA_DIR/server.key"
        sudo chmod 0644 "$HYSTERIA_DIR/server.crt"
    fi

    sudo tee "$HYSTERIA_AUTH" >/dev/null <<'AUTH'
#!/usr/bin/env bash
LOGFILE="/tmp/hysteria_auth_debug.log"
echo "==== $(date '+%Y-%m-%d %H:%M:%S') ====" >> "$LOGFILE"
echo "RAW ARG1=[$1] ARG2=[$2]" >> "$LOGFILE"
USER="$(echo "$2" | cut -d':' -f1 | tr -d '[:space:]')"
echo "EXTRACTED USER=[$USER]" >> "$LOGFILE"
if ! id "$USER" >/dev/null 2>&1; then echo "USER NOT FOUND" >> "$LOGFILE"; exit 1; fi
SHADOW_LINE="$(grep "^$USER:" /etc/shadow 2>/dev/null || true)"
if echo "$SHADOW_LINE" | cut -d: -f2 | grep -qE '^(!|\*)'; then echo "USER IS LOCKED" >> "$LOGFILE"; exit 1; fi
echo "USER EXISTS AND NOT LOCKED" >> "$LOGFILE"
exit 0
AUTH
    sudo chmod 0755 "$HYSTERIA_AUTH"

    sudo tee "$HYSTERIA_CONFIG" >/dev/null <<JSON
{
  "listen": ":$HY_PORT",
  "cert": "$HYSTERIA_DIR/server.crt",
  "key": "$HYSTERIA_DIR/server.key",
  "auth": {
    "mode": "external",
    "config": { "cmd": "$HYSTERIA_AUTH" }
  },
  "obfs": "$HY_OBFS",
  "up_mbps": $HY_UP,
  "down_mbps": $HY_DOWN
}
JSON
    sudo chmod 0644 "$HYSTERIA_CONFIG"

    sudo tee "/etc/systemd/system/$HYSTERIA_SERVICE" >/dev/null <<UNIT
[Unit]
Description=Hysteria V1 Server
After=network.target

[Service]
Type=simple
User=root
ExecStart=$HYSTERIA_BIN -config $HYSTERIA_CONFIG server
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
UNIT

    if [[ "$HY_API_CHOICE" =~ ^[SsYy]$ ]]; then
        sudo tee /root/servidor_api.py >/dev/null <<'PY'
import http.server, socketserver, json, subprocess, re
from datetime import datetime
class MyHandler(http.server.BaseHTTPRequestHandler):
    def do_POST(self):
        try:
            n = int(self.headers['Content-Length'])
            data = self.rfile.read(n).decode('utf-8')
            m = re.search(r'[a-f0-9]{32}', data)
            if not m:
                self.send_response(400); self.end_headers(); return
            user = m.group(0)
            res = subprocess.getoutput(f"chage -l {user} 2>/dev/null | grep 'Account expires' | cut -d ':' -f 2").strip()
            if 'never' in res.lower() or not res: expiry = '2099/12/31'
            else:
                try: expiry = datetime.strptime(res, '%b %d, %Y').strftime('%Y/%m/%d')
                except Exception: expiry = '2026/12/31'
            gecos = subprocess.getoutput(f'getent passwd {user} | cut -d: -f5').strip()
            fields = gecos.split(',')
            wifi = len(fields) >= 4 and fields[3].lower() == 'wifi'
            body = json.dumps({'expiry': expiry, 'wifi': wifi}).encode()
            self.send_response(200); self.send_header('Content-type', 'application/json'); self.end_headers(); self.wfile.write(body)
        except Exception:
            self.send_response(500); self.end_headers()
    def log_message(self, format, *args): return
socketserver.TCPServer.allow_reuse_address = True
with socketserver.TCPServer(('', 8989), MyHandler) as httpd: httpd.serve_forever()
PY
        sudo chmod 0755 /root/servidor_api.py
        sudo tee "/etc/systemd/system/$HYSTERIA_API_SERVICE" >/dev/null <<UNIT
[Unit]
Description=MasterVPN API Service (Python)
After=network.target

[Service]
Type=simple
ExecStart=/usr/bin/python3 /root/servidor_api.py
Restart=always
RestartSec=5
User=root
WorkingDirectory=/root

[Install]
WantedBy=multi-user.target
UNIT
    fi

    sudo systemctl daemon-reload
    sudo systemctl enable --now "$HYSTERIA_SERVICE"
    if [[ "$HY_API_CHOICE" =~ ^[SsYy]$ ]]; then sudo systemctl enable --now "$HYSTERIA_API_SERVICE"; fi
    hysteria_configure_nat
    echo -e "${C_GREEN}Hysteria instalado en UDP :$HY_PORT${C_RESET}"
    [[ "$HY_API_CHOICE" =~ ^[SsYy]$ ]] && echo -e "${C_GREEN}API instalada en TCP :8989${C_RESET}"
    read -r -p "Presiona ENTER para continuar..."
}

function hysteria_metrics_enabled() {
    command -v jq >/dev/null 2>&1 && jq -e '.prometheus_listen != null and .prometheus_listen != "" and .prometheus_listen != "null"' "$HYSTERIA_CONFIG" >/dev/null 2>&1
}
function hysteria_metrics_readable() {
    clear
    echo -e "${C_YELLOW}==================================${C_RESET}"
    echo -e "${C_WHITE}       USUARIOS CONECTADOS${C_RESET}"
    echo -e "${C_YELLOW}==================================${C_RESET}"
    echo
    if ! hysteria_metrics_enabled; then
        echo -e "${C_YELLOW}Métricas desactivadas.${C_RESET}"
        echo "Entre en la opción 8 y escriba ACTIVAR."
        read -r -p "ENTER..."
        return
    fi
    data=$(curl -fsS --max-time 4 http://127.0.0.1:8080/metrics 2>/dev/null || true)
    if [ -z "$data" ]; then
        echo -e "${C_RED}El endpoint de métricas no responde.${C_RESET}"
        read -r -p "ENTER..."
        return
    fi
    rows=$(printf '%s\n' "$data" | awk '/^hysteria_active_conn\{/ {x=$0; sub(/^.*auth="/,"",x); sub(/".*$/, "", x); if (($NF+0)>0) print x "\t" $NF}')
    if [ -z "$rows" ]; then
        echo -e "${C_YELLOW}Usuarios conectados: 0${C_RESET}"
        echo
        echo "No hay usuarios conectados ahora mismo."
        read -r -p "ENTER..."
        return
    fi
    user_count=$(printf '%s\n' "$rows" | grep -c .)
    connection_count=$(printf '%s\n' "$rows" | awk -F '\t' '{sum += $2} END {print sum+0}')
    echo -e "${C_CYAN}Usuarios conectados: ${C_WHITE}${user_count}${C_RESET}"
    echo -e "${C_CYAN}Conexiones activas:  ${C_WHITE}${connection_count}${C_RESET}"
    echo
    while IFS=$'\t' read -r encoded count; do
        [ -n "$encoded" ] || continue
        payload=$(printf '%s' "$encoded" | base64 -d 2>/dev/null || true)
        [ -n "$payload" ] || payload="$encoded"
        hwid="${payload%%:*}"
        label="${payload#*:}"
        [ "$label" = "$payload" ] && label="-"
        expiry="sin dato"
        wifi="sin dato"
        if [[ "$hwid" =~ ^[a-fA-F0-9]{32}$ ]]; then
            response=$(curl -fsS --max-time 3 -X POST http://127.0.0.1:8989/ -H 'Content-Type: application/json' --data "{\"user\":\"$hwid\"}" 2>/dev/null || true)
            value=$(printf '%s' "$response" | sed -n 's/.*"expiry"[[:space:]]*:[[:space:]]*"\([^\"]*\)".*/\1/p')
            [ -n "$value" ] && expiry="$value"
            value=$(printf '%s' "$response" | sed -n 's/.*"wifi"[[:space:]]*:[[:space:]]*\(true\|false\).*/\1/p')
            [ -n "$value" ] && wifi="$value"
        fi
        echo -e "${C_YELLOW}----------------------------------${C_RESET}"
        printf '%-14s %s\n' "Usuario:" "$label"
        printf '%-14s %s\n' "HWID:" "$hwid"
        printf '%-14s ' "Estado:"
        echo -e "${C_CYAN}CONECTADO${C_RESET}"
        printf '%-14s %s\n' "Conexiones:" "$count"
        printf '%-14s %s\n' "Vencimiento:" "$expiry"
        printf '%-14s %s\n' "WiFi:" "$wifi"
    done <<< "$rows"
    echo -e "${C_YELLOW}----------------------------------${C_RESET}"
    read -r -p "ENTER..."
}
function hysteria_metrics_all() {
    clear
    echo -e "${C_YELLOW}==================================${C_RESET}"
    echo -e "${C_WHITE}       RESUMEN DE MÉTRICAS${C_RESET}"
    echo -e "${C_YELLOW}==================================${C_RESET}"
    echo
    if ! hysteria_metrics_enabled; then echo -e "${C_YELLOW}Métricas desactivadas. Use opción 8.${C_RESET}"; read -r -p "ENTER..."; return; fi
    data=$(curl -fsS --max-time 5 http://127.0.0.1:8080/metrics 2>/dev/null || true)
    if [ -z "$data" ]; then echo -e "${C_RED}El endpoint no responde.${C_RESET}"; read -r -p "ENTER..."; return; fi
    echo -e "${C_WHITE}CONEXIONES ACTIVAS${C_RESET}"; echo
    printf '%s\n' "$data" | awk '/^hysteria_active_conn\{/ {x=$0; sub(/^.*auth="/,"",x); sub(/".*$/, "", x); if (($NF+0)>0) print x "\t" $NF}' | while IFS=$'\t' read -r auth value; do
        decoded=$(printf '%s' "$auth" | base64 -d 2>/dev/null || true); [ -n "$decoded" ] && auth="$decoded"; hwid="${auth%%:*}"; label="${auth#*:}"; [ "$label" = "$auth" ] && label="-"
        echo -e "${C_YELLOW}----------------------------------${C_RESET}"; printf '%-12s %s\n' 'Usuario:' "$label"; printf '%-12s %s\n' 'HWID:' "$hwid"; printf '%-12s ' 'Estado:'; echo -e "${C_CYAN}CONECTADO${C_RESET}"; printf '%-12s %s\n' 'Conexiones:' "$value"
    done
    echo -e "${C_YELLOW}----------------------------------${C_RESET}"; echo; echo -e "${C_WHITE}TRÁFICO ACUMULADO${C_RESET}"; down=$(printf '%s\n' "$data" | awk '/^hysteria_traffic_downlink_bytes_total/ {s+=$NF} END {print s+0}'); up=$(printf '%s\n' "$data" | awk '/^hysteria_traffic_uplink_bytes_total/ {s+=$NF} END {print s+0}'); printf '%-14s %s bytes\n' 'Descarga:' "$down"; printf '%-14s %s bytes\n' 'Subida:' "$up"; read -r -p "ENTER..."
}
function hysteria_toggle_metrics() {
    clear; echo -e "${C_YELLOW}==================================${C_RESET}"; echo -e "${C_WHITE}      MÉTRICAS PROMETHEUS${C_RESET}"; echo -e "${C_YELLOW}==================================${C_RESET}"; echo
    command -v jq >/dev/null 2>&1 || { echo -e "${C_RED}Falta jq; no se modificó nada.${C_RESET}"; read -r -p "ENTER..."; return; }
    [ -f "$HYSTERIA_CONFIG" ] || { echo -e "${C_RED}No existe $HYSTERIA_CONFIG${C_RESET}"; read -r -p "ENTER..."; return; }
    if hysteria_metrics_enabled; then read -r -p "Escriba DESACTIVAR para continuar: " answer; [ "$answer" = "DESACTIVAR" ] || { echo -e "${C_YELLOW}Debe escribir DESACTIVAR.${C_RESET}"; read -r -p "ENTER..."; return; }; value=null; else read -r -p "Escriba ACTIVAR para continuar: " answer; [ "$answer" = "ACTIVAR" ] || { echo -e "${C_YELLOW}Debe escribir ACTIVAR.${C_RESET}"; read -r -p "ENTER..."; return; }; value='"127.0.0.1:8080"'; fi
    backup="$HYSTERIA_CONFIG.bak.$(date +%Y%m%d-%H%M%S)"; cp -a "$HYSTERIA_CONFIG" "$backup" || return; tmp=$(mktemp); jq --argjson v "$value" '.prometheus_listen=$v' "$HYSTERIA_CONFIG" > "$tmp" && install -m 0644 "$tmp" "$HYSTERIA_CONFIG"; rm -f "$tmp"
    if systemctl restart "$HYSTERIA_SERVICE"; then echo -e "${C_GREEN}Métricas actualizadas correctamente.${C_RESET}"; echo "Backup: $backup"; else cp -a "$backup" "$HYSTERIA_CONFIG"; systemctl restart "$HYSTERIA_SERVICE"; echo -e "${C_RED}Falló el reinicio; configuración restaurada.${C_RESET}"; fi; read -r -p "ENTER..."
}
function hysteria_admin_menu() {
    while true; do
        clear
        echo -e "${C_YELLOW}==================================${C_RESET}"
        echo -e "${C_WHITE}      ADMINISTRADOR HYSTERIA 1${C_RESET}"
        echo -e "${C_YELLOW}==================================${C_RESET}"
        echo -e "${C_CYAN}[1]${C_WHITE} Instalar/Reinstalar Hysteria + API${C_RESET}"
        echo -e "${C_CYAN}[2]${C_WHITE} Estado resumido${C_RESET}"
        echo -e "${C_CYAN}[3]${C_WHITE} Reiniciar solo Hysteria${C_RESET}"
        echo -e "${C_CYAN}[4]${C_WHITE} Reiniciar solo API${C_RESET}"
        echo -e "${C_CYAN}[5]${C_WHITE} Comprobar NAT y persistencia${C_RESET}"
        echo -e "${C_CYAN}[6]${C_WHITE} Ver eventos resumidos${C_RESET}"
        echo -e "${C_CYAN}[7]${C_WHITE} Ver JSON completo${C_RESET}"
        echo -e "${C_CYAN}[8]${C_WHITE} Activar/Desactivar métricas${C_RESET}"
        echo -e "${C_CYAN}[9]${C_WHITE} Ver usuarios conectados${C_RESET}"
        echo -e "${C_CYAN}[10]${C_WHITE} Resumen de métricas${C_RESET}"
        echo -e "${C_CYAN}[0]${C_WHITE} Volver${C_RESET}"
        echo -e "${C_YELLOW}==================================${C_RESET}"
        read -r -p "Seleccione una opción: " opt
        case "$opt" in
            1) install_hysteria;;
            2) clear; echo -e "${C_YELLOW}==================================${C_RESET}"; echo -e "${C_WHITE}       ESTADO RESUMIDO${C_RESET}"; echo -e "${C_YELLOW}==================================${C_RESET}"; echo; printf 'Hysteria: '; systemctl is-active --quiet "$HYSTERIA_SERVICE" && echo -e "${C_GREEN}ACTIVA${C_RESET}" || echo -e "${C_RED}DETENIDA${C_RESET}"; printf 'API:      '; systemctl is-active --quiet "$HYSTERIA_API_SERVICE" 2>/dev/null && echo -e "${C_GREEN}ACTIVA${C_RESET}" || echo -e "${C_RED}DETENIDA${C_RESET}"; printf 'UDP:      '; ss -lun | grep -q ':20000 ' && echo -e "${C_GREEN}ESCUCHANDO${C_RESET}" || echo -e "${C_RED}NO CONFIRMADO${C_RESET}"; printf 'API :8989:'; ss -ltn | grep -q ':8989 ' && echo -e "${C_GREEN}ESCUCHANDO${C_RESET}" || echo -e "${C_RED}NO ESCUCHANDO${C_RESET}"; read -r -p "ENTER...";;
            3) systemctl restart "$HYSTERIA_SERVICE" && echo -e "${C_GREEN}Hysteria reiniciada.${C_RESET}" || echo -e "${C_RED}Falló Hysteria.${C_RESET}"; read -r -p "ENTER...";;
            4) systemctl restart "$HYSTERIA_API_SERVICE" && echo -e "${C_GREEN}API reiniciada.${C_RESET}" || echo -e "${C_RED}Falló la API.${C_RESET}"; read -r -p "ENTER...";;
            5) clear; echo -e "${C_YELLOW}==================================${C_RESET}"; echo -e "${C_WHITE}       NAT Y PERSISTENCIA${C_RESET}"; echo -e "${C_YELLOW}==================================${C_RESET}"; echo; echo -e "${C_WHITE}REGLAS ACTIVAS${C_RESET}"; echo -e "${C_YELLOW}----------------------------------${C_RESET}"; n=0; while IFS= read -r rule; do n=$((n+1)); echo -e "${C_CYAN}[$n]${C_RESET} $rule"; echo; done < <(iptables -t nat -S PREROUTING 2>/dev/null | grep -- "--dport" || true); [ "$n" -eq 0 ] && echo -e "${C_YELLOW}No se encontraron reglas NAT.${C_RESET}"; echo -e "${C_YELLOW}----------------------------------${C_RESET}"; echo -e "${C_WHITE}PERSISTENCIA${C_RESET}"; [ -s /etc/iptables/rules.v4 ] && echo -e "Archivo rules.v4: ${C_GREEN}EXISTE${C_RESET}" || echo -e "Archivo rules.v4: ${C_RED}NO EXISTE${C_RESET}"; read -r -p "ENTER...";;
            6) clear; echo -e "${C_YELLOW}==================================${C_RESET}"; echo -e "${C_WHITE}       EVENTOS RELEVANTES${C_RESET}"; echo -e "${C_YELLOW}==================================${C_RESET}"; echo; if journalctl -u "$HYSTERIA_SERVICE" -n 30 --no-pager | grep -q '127.0.0.1:1080.*connection refused'; then echo -e "${C_YELLOW}Advertencia: Hysteria intenta usar el proxy local 127.0.0.1:1080, pero no hay servicio escuchando.${C_RESET}"; else echo -e "${C_GREEN}No se detectó el error del proxy local 1080.${C_RESET}"; fi; journalctl -u "$HYSTERIA_SERVICE" -n 5 --no-pager | grep -E 'ERROR|WARN|failed|started|Started' | tail -5; read -r -p "ENTER...";;
            7) cat "$HYSTERIA_CONFIG" 2>/dev/null || echo -e "${C_RED}No existe la configuración.${C_RESET}"; read -r -p "ENTER...";;
            8) hysteria_toggle_metrics;;
            9) hysteria_metrics_readable;;
            10) hysteria_metrics_all;;
            0) return;;
            *) echo -e "${C_RED}Opción inválida${C_RESET}"; sleep 1;;
        esac
    done
}

function hysteria_submenu() {
    if is_hysteria_installed; then hysteria_admin_menu; else install_hysteria; fi
}

# En main_menu(), agregar una línea después de UDP-Custom:
# echo -e "${C_CYAN}[5] ${C_WHITE}Hysteria 1 + API ...................... [$(if is_hysteria_installed; then get_hysteria_status; else echo -e "${C_RED}OFF${C_RESET}"; fi)]${C_RESET}"
# En el case de main_menu(), agregar:
# 5) hysteria_submenu;;
function main_status_white() {
    printf "%b" "$1" | sed -E $'s/\033\[[0-9;]*m//g'
}

function main_menu() {
    while true; do
        clear
        echo -e "${C_BLUE}==================================================${C_RESET}"
        echo -e "${C_WHITE}         PANEL DE CONTROL DE PROTOCOLOS UDP${C_RESET}"
        echo -e "${C_GRAY}         SCRIPT BY: MaulYnetZ | Versión: 1.0${C_RESET}"
        echo -e "${C_BLUE}==================================================${C_RESET}"
        printf '%b[1] %b%-18s %-24s %b[%s%b]%b\n' "$C_CYAN" "$C_WHITE" "Dropbear" "........................" "$C_WHITE" "$(get_dropbear_status)" "$C_WHITE" "$C_RESET"
        printf '%b[2] %b%-18s %-24s %b[%s%b]%b\n' "$C_CYAN" "$C_WHITE" "SSL (Stunnel)" "........................" "$C_WHITE" "$(get_stunnel_status)" "$C_WHITE" "$C_RESET"
        printf '%b[3] %b%-18s %-24s %b[%s%b]%b\n' "$C_CYAN" "$C_WHITE" "BadVPN-UDP" "........................" "$C_WHITE" "$(get_badvpn_status)" "$C_WHITE" "$C_RESET"
        printf '%b[4] %b%-18s %-24s %b[%s%b]%b\n' "$C_CYAN" "$C_WHITE" "UDP-Custom" "........................" "$C_WHITE" "$(get_udpcustom_status)" "$C_WHITE" "$C_RESET"
        printf '%b[5] %b%-18s %-24s %b[%s%b]%b\n' "$C_CYAN" "$C_WHITE" "Hysteria 1 + API" "........................" "$C_WHITE" "$(get_hysteria_status 2>/dev/null || echo -e "${C_RED}OFF${C_RESET}")" "$C_WHITE" "$C_RESET"
        echo -e "${C_BLUE}==================================================${C_RESET}"
        echo -e "${C_CYAN}[0] ${C_WHITE}Salir del Panel${C_RESET}"
        echo -e "${C_BLUE}==================================================${C_RESET}"
        echo -e -n "${C_YELLOW}Seleccione una opción: ${C_RESET}"
        read -r opcion
        case "$opcion" in
            1) dropbear_submenu;; 2) ssl_submenu;; 3) badvpn_submenu;; 4) udpcustom_submenu;; 5) hysteria_submenu;;
            0) clear; if [[ "${BASH_SOURCE[0]}" != "$0" ]]; then return 0; else exit 0; fi;;
            *) echo -e "${C_RED}Opción inválida${C_RESET}"; sleep 1;;
        esac
    done
}

# Punto de entrada
main_menu
