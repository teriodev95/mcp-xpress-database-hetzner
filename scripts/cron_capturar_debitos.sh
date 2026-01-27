#!/bin/bash
# =====================================================
# Script: cron_capturar_debitos.sh
# Descripción: Script para ejecutar desde cron cada miércoles
#              Captura débitos de la semana actual
# =====================================================

# Configuración de conexión a la base de datos
DB_HOST="65.21.188.158"
DB_PORT="3306"
DB_USER="tu_usuario"
DB_PASS="tu_password"
DB_NAME="xpress_dinero"

# Fecha actual en zona horaria de México
FECHA_ACTUAL=$(TZ='America/Mexico_City' date '+%Y-%m-%d %H:%M:%S')

# Obtener semana y año actual
QUERY_SEMANA="SELECT semana FROM calendario WHERE CURDATE() BETWEEN desde AND hasta LIMIT 1;"
QUERY_ANIO="SELECT YEAR(CURDATE());"

SEMANA=$(mysql -h"$DB_HOST" -P"$DB_PORT" -u"$DB_USER" -p"$DB_PASS" "$DB_NAME" -sN -e "$QUERY_SEMANA")
ANIO=$(mysql -h"$DB_HOST" -P"$DB_PORT" -u"$DB_USER" -p"$DB_PASS" "$DB_NAME" -sN -e "$QUERY_ANIO")

# Log file
LOG_FILE="/var/log/xpress_debitos_$(date +%Y%m).log"

# Ejecutar el procedimiento almacenado
echo "[$FECHA_ACTUAL] Iniciando captura de débitos para semana $SEMANA/$ANIO" >> "$LOG_FILE"

mysql -h"$DB_HOST" -P"$DB_PORT" -u"$DB_USER" -p"$DB_PASS" "$DB_NAME" -e "CALL sp_insertar_debitos_agencias($SEMANA, $ANIO);" >> "$LOG_FILE" 2>&1

if [ $? -eq 0 ]; then
    echo "[$FECHA_ACTUAL] ✅ Débitos capturados exitosamente" >> "$LOG_FILE"
else
    echo "[$FECHA_ACTUAL] ❌ Error al capturar débitos" >> "$LOG_FILE"
    # Opcional: Enviar notificación de error
    # mail -s "Error en captura de débitos" admin@ejemplo.com < "$LOG_FILE"
fi

echo "" >> "$LOG_FILE"

# =====================================================
# Instalación del cron job:
# =====================================================

# 1. Dar permisos de ejecución al script:
#    chmod +x /path/to/cron_capturar_debitos.sh

# 2. Editar crontab:
#    crontab -e

# 3. Agregar línea para ejecutar cada miércoles a las 6:00 AM:
#    0 6 * * 3 /path/to/cron_capturar_debitos.sh

# Explicación del formato cron:
# ┌───────────── minuto (0 - 59)
# │ ┌───────────── hora (0 - 23)
# │ │ ┌───────────── día del mes (1 - 31)
# │ │ │ ┌───────────── mes (1 - 12)
# │ │ │ │ ┌───────────── día de la semana (0 - 7) (0 y 7 = domingo, 3 = miércoles)
# │ │ │ │ │
# 0 6 * * 3

# =====================================================
# Ejemplos de horarios alternativos:
# =====================================================

# Cada miércoles a las 6:00 AM:
# 0 6 * * 3 /path/to/script.sh

# Cada miércoles a las 3:00 AM:
# 0 3 * * 3 /path/to/script.sh

# Cada lunes a las 6:00 AM (para capturar semana anterior):
# 0 6 * * 1 /path/to/script.sh

# =====================================================
# Verificar que el cron está funcionando:
# =====================================================

# Ver cron jobs activos:
# crontab -l

# Ver logs del cron:
# grep CRON /var/log/syslog

# Ver logs del script:
# tail -f /var/log/xpress_debitos_$(date +%Y%m).log
