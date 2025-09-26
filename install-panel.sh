#!/bin/bash
# ========================================
#  Installador del Panel - con animaciones
# ========================================

clear
echo "========================================"
echo "   🚀 Instalador del Panel MaulYnetZ    "
echo "========================================"
echo

# Paso 1: Actualizar sistema
echo "🔄 Actualizando el sistema operativo..."
apt update -y && apt upgrade -y
echo "✅ Sistema actualizado."
echo
read -p "👉 Presione ENTER para instalar dependencias..."

# Paso 2: Instalar dependencias
echo "📦 Instalando dependencias necesarias..."
apt install -y curl wget unzip git cron
echo "✅ Dependencias instaladas."
echo
read -p "👉 Presione ENTER para instalar el Panel..."

# Paso 3: Instalar el panel (ejemplo)
echo "⚙️ Instalando el Panel..."
# Aquí iría tu lógica original de instalación del panel
sleep 2
echo "✅ Panel instalado correctamente."
echo

# ============================================
# Nuevo bloque: limpieza automática diaria 2AM
# ============================================
read -p "❓ ¿Desea programar la limpieza automática diaria a las 2 AM? (ENTER = Sí / Ctrl+C = No)"

# Verificar carpeta destino
INSTALL_DIR="/root/auto"
SCRIPT_NAME="elimauto.sh"
SCRIPT_URL="https://raw.githubusercontent.com/MaulynetZ/criper/refs/heads/main/elimauto.sh"

mkdir -p "$INSTALL_DIR"

# Descargar el script
echo "⬇️ Descargando script de limpieza..."
wget -q -O "$INSTALL_DIR/$SCRIPT_NAME" "$SCRIPT_URL"

# Dar permisos
chmod +x "$INSTALL_DIR/$SCRIPT_NAME"

# Verificar que cron esté activo
if ! systemctl is-active --quiet cron; then
    echo "⚠️ Cron no está activo. Iniciando y habilitando..."
    systemctl enable cron
    systemctl start cron
fi

# Programar la tarea en cron (2:00 AM diario)
CRONLINE="0 2 * * * $INSTALL_DIR/$SCRIPT_NAME >> /var/log/elimauto.log 2>&1"
( crontab -l 2>/dev/null | grep -v "$SCRIPT_NAME" ; echo "$CRONLINE" ) | crontab -

echo "✅ Limpieza automática programada todos los días a las 2 AM."
echo "    Puede revisar /var/log/elimauto.log para el historial."
echo
echo "🎉 Instalación finalizada con éxito."
