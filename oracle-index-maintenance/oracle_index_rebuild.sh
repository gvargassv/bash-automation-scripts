#!/bin/bash

#==============================================================================
# Script: oracle_index_rebuild.sh
# Propósito: Rebuild de índices fragmentados en Oracle Database
# Autor: DBA Script Generator
# Fecha: $(date +"%Y-%m-%d")
# Uso: ./oracle_index_rebuild.sh <OWNER> <INDEX_NAME>
#==============================================================================

# Configuración de colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuración de auditoría
EXECUTION_ID="REBUILD_$(date +%Y%m%d_%H%M%S)_$"
AUDIT_DIR=$PWD"/index_rebuild_"$EXECUTION_ID
AUDIT_FILE="index_rebuild_audit.log"
DETAILED_LOG="${AUDIT_DIR}/detailed_${EXECUTION_ID}.log"

# Función para logging con auditoría
log_message() {
    local level=$1
    local message=$2
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    local full_message="[$level] $timestamp - $message"

    case $level in
        "INFO")
            echo -e "${BLUE}[INFO]${NC} $timestamp - $message"
            ;;
        "WARN")
            echo -e "${YELLOW}[WARN]${NC} $timestamp - $message"
            ;;
        "ERROR")
            echo -e "${RED}[ERROR]${NC} $timestamp - $message"
            ;;
        "SUCCESS")
            echo -e "${GREEN}[SUCCESS]${NC} $timestamp - $message"
            ;;
        "AUDIT")
            echo -e "${BLUE}[AUDIT]${NC} $timestamp - $message"
            ;;
    esac

    echo "$full_message" >> "$DETAILED_LOG"
    if [ -f "$AUDIT_DIR/$AUDIT_FILE" ]; then
        echo "$timestamp|$EXECUTION_ID|$OWNER|$INDEX_NAME|$level|$message" >> "$AUDIT_DIR/$AUDIT_FILE"
    fi
}

audit_log() {
    local action=$1
    local status=$2
    local details=$3
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    local user_info=$(whoami)
    local host_info=$(hostname)

    local audit_entry="$timestamp|$EXECUTION_ID|$user_info|$host_info|$OWNER|$INDEX_NAME|$action|$status|$details"
    echo "$audit_entry" >> "$AUDIT_DIR/$AUDIT_FILE"
    log_message "AUDIT" "$action - $status: $details"
}

setup_audit() {
    if [ ! -d "$AUDIT_DIR" ]; then
        mkdir -p "$AUDIT_DIR" || {
            log_message "ERROR" "No se pudo crear directorio de logs: $AUDIT_DIR"
            exit 1
        }
    fi

    touch "$DETAILED_LOG" || {
        log_message "ERROR" "No se pudo crear log detallado: $DETAILED_LOG"
        exit 1
    }

    if [ ! -f "$AUDIT_DIR/$AUDIT_FILE" ]; then
        echo "TIMESTAMP|EXECUTION_ID|USER|HOST|OWNER|INDEX_NAME|ACTION|STATUS|DETAILS" > "$AUDIT_DIR/$AUDIT_FILE"
    fi

    chmod 644 "$DETAILED_LOG" 2>/dev/null
    chmod 644 "$AUDIT_DIR/$AUDIT_FILE" 2>/dev/null
}

show_usage() {
    echo -e "\n${BLUE}Uso:${NC}"
    echo -e "  $0 <OWNER> <INDEX_NAME>"
    echo -e "\n${BLUE}Ejemplos:${NC}"
    echo -e "  $0 HR EMP_NAME_IDX"
    echo -e "  $0 SALES PK_ORDERS"
    echo -e "\n${BLUE}Descripción:${NC}"
    echo -e "  - OWNER: Esquema propietario del índice (ej: HR, SALES)"
    echo -e "  - INDEX_NAME: Nombre del índice a reconstruir"
    echo -e "\n"
}

if [ $# -ne 2 ]; then
    log_message "ERROR" "Número incorrecto de parámetros"
    show_usage
    exit 1
fi

OWNER=$(echo "$1" | tr '[:lower:]' '[:upper:]')
INDEX_NAME=$(echo "$2" | tr '[:lower:]' '[:upper:]')

setup_audit
audit_log "SCRIPT_START" "INITIATED" "User: $(whoami), Parameters: $OWNER.$INDEX_NAME"

log_message "INFO" "=== INICIO DE EJECUCIÓN ==="
log_message "INFO" "ID de Ejecución: $EXECUTION_ID"
log_message "INFO" "Usuario: $(whoami)"
log_message "INFO" "Servidor: $(hostname)"
log_message "INFO" "Directorio del script: $SCRIPT_DIR"
log_message "INFO" "Directorio de logs: $AUDIT_DIR"
log_message "INFO" "Log detallado: $DETAILED_LOG"
log_message "INFO" "Iniciando proceso de rebuild para índice: ${OWNER}.${INDEX_NAME}"

TEMP_SQL="/tmp/rebuild_${OWNER}_${INDEX_NAME}_$$.sql"
LOG_FILE="/tmp/rebuild_${OWNER}_${INDEX_NAME}_$$.log"

cleanup() {
    local exit_status=$?
    log_message "INFO" "Limpiando archivos temporales..."

    if [ $exit_status -eq 0 ]; then
        audit_log "SCRIPT_END" "SUCCESS" "Proceso completado exitosamente"
    else
        audit_log "SCRIPT_END" "FAILED" "Proceso terminó con errores (exit code: $exit_status)"
    fi

    if [ -f "$DETAILED_LOG" ]; then
        local file_size=$(wc -c < "$DETAILED_LOG" 2>/dev/null || echo 0)
        if [ $file_size -gt 1048576 ]; then
            gzip "$DETAILED_LOG" 2>/dev/null && log_message "INFO" "Log detallado comprimido: ${DETAILED_LOG}.gz"
        fi
    fi

    rm -f "$TEMP_SQL" "$LOG_FILE"

    log_message "INFO" "=== FIN DE EJECUCIÓN ==="
    log_message "INFO" "Consulte los logs de auditoría en: $AUDIT_DIR"
    log_message "INFO" "Estructura de archivos generados:"
    log_message "INFO" "  - Log principal: $AUDIT_DIR/$AUDIT_FILE"
    log_message "INFO" "  - Log detallado: $DETAILED_LOG"
    if [ -f "${AUDIT_DIR}/rebuild_report_${EXECUTION_ID}.txt" ]; then
        log_message "INFO" "  - Reporte: ${AUDIT_DIR}/rebuild_report_${EXECUTION_ID}.txt"
    fi
}

trap cleanup EXIT

# ==================== FIX: PROBAR CONEXIÓN SQLPLUS ====================
log_message "INFO" "Verificando conectividad con la base de datos..."
audit_log "DB_CONNECTION" "ATTEMPT" "Verificando conectividad con sqlplus / as sysdba"

sqlplus -s / as sysdba <<EOF > /dev/null 2>&1
whenever sqlerror exit 1;
select 1 from dual;
exit;
EOF

if [ $? -eq 0 ]; then
    log_message "SUCCESS" "Conexión a la base de datos verificada"
    audit_log "DB_CONNECTION" "SUCCESS" "Conexión establecida correctamente"
else
    log_message "ERROR" "No se pudo establecer conexión con la base de datos"
    audit_log "DB_CONNECTION" "FAILED" "Fallo de conexión con sqlplus"
    exit 1
fi
# =====================================================================

# ==================== REBUILD DEL ÍNDICE ====================
cat > "$TEMP_SQL" <<EOF
set serveroutput on
whenever sqlerror exit 1;

prompt AUDIT_INDEX_REBUILD_START: Iniciando rebuild del índice ${OWNER}.${INDEX_NAME}
ALTER INDEX ${OWNER}.${INDEX_NAME} REBUILD;

prompt AUDIT_INDEX_REBUILD_END: Rebuild del índice ${OWNER}.${INDEX_NAME} finalizado
exit;
EOF

sqlplus -s / as sysdba @"$TEMP_SQL" | while read -r line; do
    if [[ $line == AUDIT_*:* ]]; then
        if [[ $line == AUDIT_INDEX_REBUILD_START:* ]]; then
            audit_log "INDEX_REBUILD_START" "INFO" "${line#AUDIT_INDEX_REBUILD_START: }"
        elif [[ $line == AUDIT_INDEX_REBUILD_END:* ]]; then
            audit_log "INDEX_REBUILD_END" "INFO" "${line#AUDIT_INDEX_REBUILD_END: }"
        fi
    elif [[ -n "$line" ]]; then
        echo "$line"
        echo "[OUTPUT] $(date '+%Y-%m-%d %H:%M:%S') - $line" >> "$DETAILED_LOG"
    fi
done

if [ ${PIPESTATUS[0]} -eq 0 ]; then
    log_message "SUCCESS" "Proceso de rebuild completado exitosamente"
    log_message "INFO" "Índice ${OWNER}.${INDEX_NAME} ha sido reconstruido"
    audit_log "PROCESS_RESULT" "SUCCESS" "Rebuild completado sin errores"
else
    log_message "ERROR" "El proceso de rebuild falló"
    audit_log "PROCESS_RESULT" "FAILED" "Proceso terminó con errores"
    exit 1
fi

# ==================== REPORTE DE AUDITORÍA ====================
generate_audit_report() {
    local report_file="${AUDIT_DIR}/rebuild_report_${EXECUTION_ID}.txt"

    cat > "$report_file" <<EOF
================================================================================
                    REPORTE DE AUDITORÍA - REBUILD DE ÍNDICE
================================================================================

INFORMACIÓN GENERAL:
- ID de Ejecución: ${EXECUTION_ID}
- Usuario: $(whoami)
- Servidor: $(hostname)
- Directorio del script: ${SCRIPT_DIR}
- Fecha/Hora Inicio: $(head -1 "$DETAILED_LOG" | cut -d'-' -f2-3 2>/dev/null || echo "N/A")
- Fecha/Hora Fin: $(date '+%Y-%m-%d %H:%M:%S')

OBJETO PROCESADO:
- Esquema: ${OWNER}
- Índice: ${INDEX_NAME}

ARCHIVOS GENERADOS:
- Log Detallado: ${DETAILED_LOG}
- Log de Auditoría: ${AUDIT_DIR}/${AUDIT_FILE}
- Reporte: ${report_file}

RESUMEN DE EJECUCIÓN:
$(grep "AUDIT.*SUCCESS\\|AUDIT.*FAILED" "$AUDIT_DIR/$AUDIT_FILE" | grep "$EXECUTION_ID" | tail -5 2>/dev/null || echo "No se encontraron entradas de auditoría")

UBICACIÓN DE LOGS:
Todos los archivos de log se encuentran en el directorio:
${AUDIT_DIR}

================================================================================
Generado automáticamente por: oracle_index_rebuild.sh
Directorio de trabajo: ${SCRIPT_DIR}
================================================================================
EOF

    echo -e "Reporte de auditoría generado: ${BLUE}${report_file}${NC}"
}

generate_audit_report

show_audit_summary() {
    echo -e "\n${YELLOW}=== ESTADÍSTICAS DE AUDITORÍA ===${NC}"

    if [ -f "$AUDIT_DIR/$AUDIT_FILE" ]; then
        local total_executions=$(grep -c "$OWNER\\|$INDEX_NAME" "$AUDIT_DIR/$AUDIT_FILE" 2>/dev/null || echo "0")
        local successful_rebuilds=$(grep -c "REBUILD.*SUCCESS" "$AUDIT_DIR/$AUDIT_FILE" 2>/dev/null || echo "0")
        local failed_rebuilds=$(grep -c "REBUILD.*FAILED\\|ERROR" "$AUDIT_DIR/$AUDIT_FILE" 2>/dev/null || echo "0")

        echo -e "Archivo de auditoría: ${BLUE}${AUDIT_DIR}/${AUDIT_FILE}${NC}"
        echo -e "Total de ejecuciones registradas: ${BLUE}${total_executions}${NC}"
        echo -e "Rebuilds exitosos: ${GREEN}${successful_rebuilds}${NC}"
        echo -e "Rebuilds fallidos: ${RED}${failed_rebuilds}${NC}"

        echo -e "\nÚltimas ejecuciones para ${OWNER}.${INDEX_NAME}:"
        grep "$OWNER.*$INDEX_NAME" "$AUDIT_DIR/$AUDIT_FILE" 2>/dev/null | tail -3 | while IFS='|' read -r timestamp exec_id user host owner index action status details; do
            echo -e "  ${BLUE}${timestamp}${NC} - ${action}: ${status}"
        done

        echo -e "\nPara ver el historial completo:"
        echo -e "  ${BLUE}cat ${AUDIT_DIR}/${AUDIT_FILE}${NC}"
    else
        echo -e "No se encontró archivo de auditoría en: ${RED}${AUDIT_DIR}/${AUDIT_FILE}${NC}"
    fi
}

show_audit_summary
