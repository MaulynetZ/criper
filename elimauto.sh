#!/usr/bin/env bash
# elimauto.sh - Limpieza automática de usuarios HWID expirados (-3d o más)

set -euo pipefail

today_days=$(( $(date +%s) / 86400 ))

while IFS=: read -r user pw uid gid gecos home shell; do
    first_field=$(printf '%s' "$gecos" | awk -F, '{print $1}')
    [[ "$first_field" != "hwid" ]] && continue

    exp_days=$(getent shadow "$user" | awk -F: '{print $8}')
    if [[ -z "$exp_days" || ! "$exp_days" =~ ^[0-9]+$ ]]; then
        continue
    fi

    diff=$(( exp_days - today_days ))
    if [ "$diff" -le -3 ]; then
        days_ago=$(( -diff ))
        echo "🗑 Eliminando $user (expirado hace ${days_ago}d)..."

        # --- Bloque de eliminación personalizado ---
        HWID="$user"
        HASH="$(getent shadow "$HWID" | cut -d: -f2 2>/dev/null || true)"
        pkill -KILL -u "$HWID" 2>/dev/null || true
        crontab -r -u "$HWID" 2>/dev/null || true

        if (userdel -r "$HWID" 2>/dev/null || userdel "$HWID" 2>/dev/null ||             deluser --remove-home "$HWID" 2>/dev/null || deluser "$HWID" 2>/dev/null); then
            for dir in /etc/adm-ruffu /root/adm-ruffu /opt/adm-ruffu /usr/local/adm-ruffu; do
                [ -d "$dir" ] || continue
                find "$dir" -maxdepth 3 -type f -print0 2>/dev/null | while IFS= read -r -d '' f; do
                    cp -f "$f" "$f.bak" 2>/dev/null || true
                    awk -v u="$HWID" -v h="$HASH" 'BEGIN{IGNORECASE=1} index($0,u)==0 && (h=="" || index($0,h)==0)' "$f.bak" > "$f"
                done
            done

            echo "$(date +'%F %T') DEL $HWID" >> /var/log/adm-ruffu.log
            echo "✅ Usuario '$HWID' eliminado correctamente."
        else
            echo "⚠️ Error al eliminar usuario '$HWID'."
        fi
        # --- Fin bloque de eliminación ---
    fi
done < /etc/passwd
