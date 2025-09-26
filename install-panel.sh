#!/bin/bash
set -e

echo "=== Instalador del Panel ==="

# 1. Actualizar sistema
apt update && apt upgrade -y

echo
read -p "Presione ENTER para instalar dependencias..."

# 2. Instalar dependencias
apt install -y curl wget git cron

echo
read -p "Presione ENTER para instalar el panel..."

# 3. Descargar e instalar el panel (ejemplo)
echo "Descargando e instalando panel..."
# Aquí iría la lógica real de tu panel, se deja como placeholder
# curl -s -o /usr/local/bin/panel.sh https://raw.githubusercontent.com/tu_repo/panel/main/panel.sh
# chmod +x /usr/local/bin/panel.sh

echo "✔ Panel instalado."

echo
read -p "¿Desea programar la eliminación automática diaria a las 2 AM? Presione ENTER para continuar o Ctrl+C para cancelar."

# === Configuración de limpieza automática ===
AUTO_DIR="/root/auto"
SCRIPT_NAME="elimauto.sh"
SCRIPT_URL="https://raw.githubusercontent.com/MaulynetZ/criper/refs/heads/main/elimauto.sh"
SCRIPT_PATH="$AUTO_DIR/$SCRIPT_NAME"

# 1. Crear carpeta si no existe
mkdir -p "$AUTO_DIR"

# 2. Descargar el script actualizado
echo "Descargando script de limpieza automática..."
curl -s -o "$SCRIPT_PATH" "$SCRIPT_URL"

# 3. Dar permisos de ejecución
chmod +x "$SCRIPT_PATH"

# 4. Programar cron para que se ejecute todos los días a las 2:00 AM
CRON_JOB="0 2 * * * $SCRIPT_PATH"
( crontab -l 2>/dev/null | grep -v "$SCRIPT_PATH" ; echo "$CRON_JOB" ) | crontab -

echo "✔ Limpieza automática configurada: se ejecutará todos los días a las 2:00 AM"

echo "=== Instalación finalizada ==="
