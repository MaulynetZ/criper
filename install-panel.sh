#!/bin/bash
# Script unificado: instala panel MaulYnetZ + banner

# Colores
red="\e[1;31m"
green="\e[1;32m"
yellow="\e[1;33m"
nc="\e[0m"
white="\e[1;37m"

# Barra
BARRA="${red}==================================================${nc}"

# ============================
# ACTUALIZAR SISTEMA
# ============================
echo -e "$BARRA"
echo -e "          ${white}ACTUALIZANDO SISTEMA${nc}"
echo -e "$BARRA"
sudo apt update -y
sudo apt upgrade -y
echo -e "$BARRA"
read -p "      ▶▷ Presione enter para continuar con la instalación de dependencias ◁◀"
clear

# ============================
# INSTALAR DEPENDENCIAS
# ============================
echo -e "$BARRA"
echo -e "          ${white}INSTALANDO DEPENDENCIAS${nc}"
echo -e "$BARRA"
ubuntu_version=$(lsb_release -ds 2>/dev/null || echo "Linux")
echo -e "              ${yellow}$ubuntu_version${nc}"
echo -e "             ${green}INSTALANDO DEPENDENCIAS${nc}\n"
dependencias=(sudo bsdmainutils zip unzip ufw curl python2 python3 python3-pip openssl screen cron iptables lsof nano at mlocate gawk grep bc jq npm nodejs socat netcat netcat-traditional net-tools cowsay figlet lolcat sqlite3 libsqlite3-dev locales)
for dep in "${dependencias[@]}"; do
    if sudo apt-get install -y "$dep" >/dev/null 2>&1; then
        status="${green}INSTALL${nc}"
    else
        status="${red}FAILED${nc}"
    fi
    printf "${white}instalando %-22s ................ ${status}\n${nc}" "$dep"
    sleep 0.1
done

echo -e "\n${yellow}Habilitando servicios críticos (AT y CRON)...${nc}"
sudo systemctl enable --now atd >/dev/null 2>&1
sudo systemctl enable --now cron >/dev/null 2>&1

echo -e "\n$BARRA"
echo -e " ${yellow}Si alguna de las dependencias falla, puede intentar instalarla manualmente."
echo -e " ${yellow}Use el comando: apt install nombre_del_paquete${nc}"
echo -e "$BARRA"
read -p "      ▶▷ Presione enter para instalar el panel ◁◀"
clear

# ============================
# INSTALACIÓN DEL PANEL
# ============================
INSTALL_DIR="/root/MaulYnetZ"
SCRIPT1_URL="https://raw.githubusercontent.com/MaulynetZ/criper/main/Panel_MaulYnetZ.sh"
SCRIPT2_URL="https://raw.githubusercontent.com/MaulynetZ/criper/main/Protocolos.sh"
ALIAS_NAME="mj"
ALIAS_CMD="/root/MaulYnetZ/Panel_MaulYnetZ.sh"

echo -e "$BARRA"
echo -e "          ${white}INSTALANDO PANEL MaulYnetZ${nc}"
echo -e "$BARRA"

if [ ! -d "$INSTALL_DIR" ]; then
    echo -e "${yellow}Creando directorio $INSTALL_DIR...${nc}"
    mkdir -p "$INSTALL_DIR"
fi

echo -e "${yellow}Descargando scripts desde GitHub...${nc}"
curl -sSL "$SCRIPT1_URL" -o "$INSTALL_DIR/Panel_MaulYnetZ.sh"
echo -e "${green}✔ Panel_MaulYnetZ.sh descargado${nc}"
sleep 0.2
curl -sSL "$SCRIPT2_URL" -o "$INSTALL_DIR/Protocolos.sh"
echo -e "${green}✔ Protocolos.sh descargado${nc}"
sleep 0.2

echo -e "${yellow}Asignando permisos de ejecución a los scripts...${nc}"
chmod +x "$INSTALL_DIR/Panel_MaulYnetZ.sh" "$INSTALL_DIR/Protocolos.sh"
echo -e "${green}✔ Permisos asignados${nc}"
sleep 0.2

# Crear alias en bashrc si no existe
if ! grep -Fxq "alias $ALIAS_NAME=\"$ALIAS_CMD\"" ~/.bashrc; then
    echo "alias $ALIAS_NAME=\"$ALIAS_CMD\"" >> ~/.bashrc
fi

# Crear wrapper en /usr/local/bin para que funcione siempre
echo -e "${yellow}Creando acceso directo en /usr/local/bin...${nc}"
echo "#!/bin/bash
bash \"$ALIAS_CMD\" \"\$@\"" | sudo tee /usr/local/bin/$ALIAS_NAME >/dev/null
sudo chmod +x /usr/local/bin/$ALIAS_NAME
echo -e "${green}✔ Alias global creado: $ALIAS_NAME${nc}"

echo -e "\n$BARRA"
echo -e "${green}Instalación del panel completada. Puedes ejecutar el panel con el comando: $ALIAS_NAME${nc}"
echo -e "$BARRA"

# ============================
# INSTALACIÓN DEL BANNER
# ============================
echo -e "\n${yellow}Instalando banner personalizado...${nc}"

apt-get install -y figlet lolcat > /dev/null 2>&1

mkdir -p /etc/AdMaulYnetZ/tmp
echo "$(date +%F)" > /etc/AdMaulYnetZ/version

cat << 'EOF' > /etc/AdMaulYnetZ/bashrc
if [[ $(echo $PATH | grep "/usr/games") = "" ]]; then PATH=$PATH:/usr/games; fi
v=$(cat /etc/AdMaulYnetZ/version)
[[ -e /etc/AdMaulYnetZ/new_version ]] && up=$(cat /etc/AdMaulYnetZ/new_version) || up=$v
[[ $(date '+%s' -d $up) -gt $(date '+%s' -d $(cat /etc/AdMaulYnetZ/version)) ]] && v2="Nueva Version disponible: $v >>> $up" || v2="Script Version: $v"
[[ -e "/etc/AdMaulYnetZ/tmp/message.txt" ]] && mess1="$(cat /etc/AdMaulYnetZ/tmp/message.txt)"
[[ -z "$mess1" ]] && mess1="@MaulYnetZ"
clear && echo -e "\n$(figlet -f small "AdMaulYnetZ")\n        RESELLER : $mess1 \n\n   Para iniciar AdMaulYnetZ escriba:  mj \n\n   $v2\n\n" | lolcat
EOF

grep -q "AdMaulYnetZ/bashrc" /etc/bash.bashrc || echo '[[ -e /etc/AdMaulYnetZ/bashrc ]] && source /etc/AdMaulYnetZ/bashrc' >> /etc/bash.bashrc

echo -e "${green}✅ Banner AdMaulYnetZ instalado correctamente. Reloguea tu VPS para verlo.${nc}"

# ============================
# FINAL
# ============================
read -p "      ▶▷ Presione enter para finalizar ◁◀"
clear
echo -e "\n\n${green}¡Instalación completada!${nc}\n"


echo -e "\n\033[1;36m¿Desea programar la limpieza automática diaria a las 2 AM?\033[0m"
echo -e "   Presione ENTER para aceptar, o Ctrl+C para omitir."
read -r

# Crear directorio si no existe
mkdir -p /root/auto

# Descargar el script elimauto.sh desde GitHub
wget -O /root/auto/elimauto.sh https://raw.githubusercontent.com/MaulynetZ/criper/main/elimauto.sh

# Dar permisos de ejecución
chmod +x /root/auto/elimauto.sh

# Programar cron job diario a las 2 AM
# Primero quitamos cualquier línea previa igual para no duplicar
( crontab -l 2>/dev/null | grep -v '/root/auto/elimauto.sh' ; echo "0 2 * * * /root/auto/elimauto.sh" ) | crontab -

echo -e "\033[1;32m✔ Limpieza automática programada correctamente.\033[0m"

