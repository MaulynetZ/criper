#!/bin/bash
# install-panel.sh

# Colores
red="\e[1;31m"
green="\e[1;32m"
yellow="\e[1;33m"
nc="\e[0m"
white="\e[1;37m"

# Barra
BARRA="${red}==================================================${nc}"

# Actualización del sistema
echo -e "$BARRA"
echo -e "          ${white}ACTUALIZANDO SISTEMA${nc}"
echo -e "$BARRA"
sudo apt update -y
sudo apt upgrade -y
echo -e "$BARRA"
read -p "      ▶▷ Presione enter para continuar con la instalación de dependencias ◁◀"
clear

# Instalación de dependencias
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

# Instalación del panel
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

read -p "      ▶▷ Presione enter para finalizar ◁◀"
clear
echo -e "\n\n${green}¡Instalación completada!${nc}\n"
