#!/usr/bin/env bash
set -euo pipefail

# ESTE SCRIPT BORRA USUARIOS cuyo GECOS empiece con "hwid" (exacto, minúscula)
# y cuya fecha de expiración en /etc/shadow sea <= today - 3 días.
# Ejecuta como root. No pedirá confirmación.

# Función para el borrado avanzado de usuarios
# Argumento: nombre de usuario a borrar
advanced_delete_user() {
    local user_to_delete="$1"

    if id "$user_to_delete" &>/dev/null; then
        local HASH="$(getent shadow "$user_to_delete" | cut -d: -f2 2>/dev/null)"
        pkill -KILL -u "$user_to_delete" 2>/dev/null || true
        crontab -r -u "$user_to_delete" 2>/dev/null || true
        if (userdel -r "$user_to_delete" 2>/dev/null || userdel "$user_to_delete" 2>/dev/null || deluser --remove-home "$user_to_delete" 2>/dev/null || deluser "$user_to_delete" 2>/dev/null); then
            for dir in /etc/adm-ruffu /root/adm-ruffu /opt/adm-ruffu /usr/local/adm-ruffu; do
                [ -d "$dir" ] || continue
                find "$dir" -maxdepth 3 -type f -print0 2>/dev/null | while IFS= read -r -d '' f; do
                    cp -f "$f" "$f.bak" 2>/dev/null || true
                    awk -v u="$user_to_delete" -v h="$HASH" 'BEGIN{IGNORECASE=1} index($0,u)==0 && (h=="" || index($0,h)==0)' "$f.bak" > "$f"
                done
            done

            echo "$(date +'%F %T') DEL $user_to_delete" >> /var/log/adm-ruffu.log
            echo "✅ El usuario '$user_to_delete' fue eliminado correctamente del sistema."
            return 0 # Éxito
        else
            echo "⚠️ Hubo un error inesperado al intentar eliminar al usuario '$user_to_delete'."
            return 1 # Fallo
        fi
    else
        echo "❌ El usuario '$user_to_delete' no se encuentra registrado en el sistema (o ya fue eliminado)."
        return 1 # Fallo
    fi
}

today_days=$(( $(date +%s) / 86400 ))

echo "Modo: ELIMINAR (real). Fecha (days-since-epoch): $today_days"
echo "Buscando usuarios con GECOS primer campo = 'hwid' y expirados hace >=3 días..."
echo

deleted_count=0

while IFS=: read -r user pw uid gid gecos home shell; do
  # primer campo de GECOS antes de la primera coma
  first_field=$(printf '%s' "$gecos" | awk -F, '{print $1}')
  if [[ "$first_field" != "hwid" ]]; then
    continue
  fi

  # obtener campo 8 (fecha expiración en días) desde /etc/shadow via getent
  exp_days=$(getent shadow "$user" | awk -F: '{print $8}')

  # si no hay expiración numérica, saltar (no borramos)
  if [[ -z "$exp_days" || ! "$exp_days" =~ ^[0-9]+$ ]]; then
    printf "SALTA (sin fecha válida): %s    GECOS='%s'\n" "$user" "$gecos"
    continue
  fi

  diff=$(( exp_days - today_days ))

  # condición: eliminar si expiró hace 3 días o más (diff <= -3)
  if [ "$diff" -le -3 ]; then
    days_ago=$(( -diff ))
    printf "BORRANDO -> %s    (expiró hace %sd)    GECOS='%s'\n" "$user" "$days_ago" "$gecos"

    # Llamar a la función de borrado avanzado
    if advanced_delete_user "$user"; then
      printf "BORRADO OK: %s\n" "$user"
      deleted_count=$((deleted_count+1))
    else
      printf "ERROR borrando %s — intenta manualmente (revisar logs)\n" "$user"
    fi
  fi

done < /etc/passwd

echo
echo "Proceso terminado. Usuarios borrados: $deleted_count"


