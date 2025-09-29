#!/bin/bash

# Script para ejecutar Segment Advisor y Shrink de tablas Oracle
# Ejecutar desde el servidor de base de datos con usuario oracle
# Uso: ./oracle_shrink.sh <esquema> <tabla> [ORACLE_SID]

# Función para mostrar ayuda
show_help() {
    echo "Uso: $0 <esquema> <tabla> [ORACLE_SID]"
    echo ""
    echo "Parámetros obligatorios:"
    echo "  esquema    - Esquema de la tabla (ej: ESQUEMA)"
    echo "  tabla      - Nombre de la tabla (ej: TABLA)"
    echo ""
    echo "Parámetros opcionales:"
    echo "  ORACLE_SID - SID de la base de datos (se usa variable de entorno si no se especifica)"
    echo ""
    echo "Prerequisitos:"
    echo "  - Ejecutar como usuario 'oracle' o equivalente"
    echo "  - Variables ORACLE_HOME y ORACLE_SID configuradas"
    echo "  - Conexión / as sysdba disponible"
    echo ""
    echo "Ejemplo:"
    echo "  $0 ESQUEMA TABLA"
    echo "  $0 ESQUEMA TABLA ORCL"
}

# Verificar parámetros mínimos
if [ $# -lt 2 ]; then
    echo "Error: Se requieren al menos 2 parámetros"
    echo ""
    show_help
    exit 1
fi

# Verificar que esté ejecutándose en el servidor de BD
if [ -z "$ORACLE_HOME" ]; then
    echo "Error: Variable ORACLE_HOME no está configurada"
    echo "Asegúrese de estar ejecutando el script como usuario oracle con el entorno configurado"
    exit 1
fi

# Asignar parámetros
SCHEMA=$1
TABLE=$2

# Generar nombre de tarea con máximo 30 caracteres
# Formato: XX_<hash>_<timestamp>
HASH=$(echo "${SCHEMA}_${TABLE}" | md5sum | cut -c1-8)
TIMESTAMP=$(date +%H%M%S)
TASK_NAME="XX_${HASH}_${TIMESTAMP}"

echo "Nombre de tarea generado: $TASK_NAME (${#TASK_NAME} caracteres)"

# Configurar ORACLE_SID si se proporciona como parámetro
if [ $# -ge 3 ]; then
    export ORACLE_SID=$3
    echo "Usando ORACLE_SID: $ORACLE_SID"
elif [ -z "$ORACLE_SID" ]; then
    echo "Error: ORACLE_SID no está configurado"
    echo "Proporcione el SID como parámetro o configure la variable de entorno"
    exit 1
fi

# Verificar conectividad antes de proceder
echo "Verificando conectividad a la base de datos..."
sqlplus -S / as sysdba << EOF > /tmp/test_connection.tmp 2>&1
SELECT 'DB_CONNECTED' FROM dual;
EXIT;
EOF

if ! grep -q "DB_CONNECTED" /tmp/test_connection.tmp; then
    echo "Error: No se puede conectar a la base de datos"
    echo "Verifique que:"
    echo "  - Esté ejecutando como usuario oracle"
    echo "  - ORACLE_HOME esté configurado correctamente"
    echo "  - ORACLE_SID esté configurado correctamente"
    echo "  - La base de datos esté ejecutándose"
    cat /tmp/test_connection.tmp
    rm -f /tmp/test_connection.tmp
    exit 1
fi
rm -f /tmp/test_connection.tmp
echo "✅ Conectividad verificada correctamente"

# Crear directorio de evidencias
EVIDENCE_DIR="evidencias_${SCHEMA}_${TABLE}_$(date +%Y%m%d_%H%M%S)"
mkdir -p "$EVIDENCE_DIR"

# Archivo de log principal
LOG_FILE="$EVIDENCE_DIR/ejecucion_completa.log"

# Función para ejecutar SQL y registrar evidencias
execute_sql() {
    local step_name=$1
    local sql_command=$2
    local output_file="$EVIDENCE_DIR/${step_name}_$(date +%H%M%S).txt"
    
    echo "========================================" | tee -a "$LOG_FILE"
    echo "PASO: $step_name" | tee -a "$LOG_FILE"
    echo "HORA INICIO: $(date)" | tee -a "$LOG_FILE"
    echo "COMANDO SQL:" | tee -a "$LOG_FILE"
    echo "$sql_command" | tee -a "$LOG_FILE"
    echo "========================================" | tee -a "$LOG_FILE"
    
    local start_time=$(date +%s)
    
    # Ejecutar el comando SQL usando conexión local como sysdba
    sqlplus -S / as sysdba << EOF > "$output_file" 2>&1
SET PAGESIZE 0
SET FEEDBACK ON
SET TIMING ON
SET ECHO ON
SPOOL $EVIDENCE_DIR/${step_name}_spool.log

$sql_command

SPOOL OFF
EXIT;
EOF
    
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))
    
    echo "RESULTADO:" | tee -a "$LOG_FILE"
    cat "$output_file" | tee -a "$LOG_FILE"
    echo "" | tee -a "$LOG_FILE"
    echo "HORA FIN: $(date)" | tee -a "$LOG_FILE"
    echo "DURACIÓN: ${duration} segundos" | tee -a "$LOG_FILE"
    echo "" | tee -a "$LOG_FILE"
    
    # Verificar si hubo errores (excluyendo el check de detección automática que no funciona bien)
    if grep -i "ORA-\|ERROR" "$output_file" > /dev/null; then
        echo "⚠️  ADVERTENCIA: Se detectaron posibles errores en este paso" | tee -a "$LOG_FILE"
        echo "Revise el archivo: $output_file" | tee -a "$LOG_FILE"
        
        # Si es un error crítico, detener ejecución
        if grep -i "ORA-13608\|ORA-00942\|ORA-00955" "$output_file" > /dev/null; then
            echo "❌ Error crítico detectado. Deteniendo ejecución." | tee -a "$LOG_FILE"
            echo "Revise el error en: $output_file" | tee -a "$LOG_FILE"
            return 1
        fi
    else
        echo "✅ Paso completado exitosamente" | tee -a "$LOG_FILE"
    fi
    echo "" | tee -a "$LOG_FILE"
    return 0
}

# Iniciar el proceso
echo "=============================================" | tee "$LOG_FILE"
echo "INICIO DEL PROCESO DE SEGMENT ADVISOR Y SHRINK" | tee -a "$LOG_FILE"
echo "Servidor: $(hostname)" | tee -a "$LOG_FILE"
echo "Usuario: $(whoami)" | tee -a "$LOG_FILE"
echo "ORACLE_HOME: $ORACLE_HOME" | tee -a "$LOG_FILE"
echo "ORACLE_SID: $ORACLE_SID" | tee -a "$LOG_FILE"
echo "Esquema: $SCHEMA" | tee -a "$LOG_FILE"
echo "Tabla: $TABLE" | tee -a "$LOG_FILE"
echo "Tarea: $TASK_NAME (basado en ${SCHEMA}.${TABLE})" | tee -a "$LOG_FILE"
echo "Fecha/Hora: $(date)" | tee -a "$LOG_FILE"
echo "Directorio de evidencias: $EVIDENCE_DIR" | tee -a "$LOG_FILE"
echo "=============================================" | tee -a "$LOG_FILE"
echo "" | tee -a "$LOG_FILE"

# Paso 1: Crear la tarea del Segment Advisor
if ! execute_sql "01_crear_tarea" "
EXEC DBMS_ADVISOR.CREATE_TASK (advisor_name=>'Segment Advisor', task_name=> '$TASK_NAME');
"; then
    echo "❌ Error crítico al crear la tarea. Abortando ejecución." | tee -a "$LOG_FILE"
    exit 1
fi

# Paso 2: Crear objeto para análisis
if ! execute_sql "02_crear_objeto" "
DECLARE
    objid NUMBER;
BEGIN
    DBMS_ADVISOR.CREATE_OBJECT (
        task_name=> '$TASK_NAME',
        object_type=> 'TABLE',
        attr1 => '$SCHEMA',
        attr2 => '$TABLE',
        attr3 => NULL,
        attr4 => 'NULL',
        attr5 => NULL,
        object_id => objid
    );
END;
/"; then
    echo "❌ Error crítico al crear el objeto. Abortando ejecución." | tee -a "$LOG_FILE"
    exit 1
fi

# Paso 3: Configurar parámetros de la tarea
execute_sql "03_configurar_parametros" "
EXEC DBMS_ADVISOR.SET_TASK_PARAMETER (task_name => '$TASK_NAME', parameter => 'RECOMMEND_ALL', value => 'TRUE');
"

# Paso 4: Ejecutar la tarea del Segment Advisor
execute_sql "04_ejecutar_tarea" "
EXEC DBMS_ADVISOR.EXECUTE_TASK (task_name => '$TASK_NAME');
"

# Paso 5: Consultar resultados del análisis
execute_sql "05_consultar_findings" "
SELECT message, more_info FROM DBA_ADVISOR_FINDINGS WHERE task_name = '$TASK_NAME';
"

# Paso 6: Consultar recomendaciones
execute_sql "06_consultar_recomendaciones" "
SELECT benefit_type FROM dba_advisor_recommendations WHERE task_name = '$TASK_NAME';
"

# Paso 7: Consultar tamaño inicial de la tabla
execute_sql "07_tamaño_inicial" "
SELECT 
    segment_name,
    bytes,
    ROUND(bytes/1024/1024, 2) as MB,
    ROUND(bytes/1024/1024/1024, 2) as GB
FROM dba_segments 
WHERE segment_name = '$TABLE' AND owner = '$SCHEMA';
"

# Paso 8: Habilitar movimiento de filas
execute_sql "08_habilitar_row_movement" "
ALTER TABLE $SCHEMA.$TABLE ENABLE ROW MOVEMENT;
"

# Paso 9: Shrink compacto
execute_sql "09_shrink_compact" "
ALTER TABLE $SCHEMA.$TABLE SHRINK SPACE COMPACT;
"

# Paso 10: Verificar tamaño después del shrink compacto
execute_sql "10_tamaño_post_compact" "
SELECT 
    segment_name,
    bytes,
    ROUND(bytes/1024/1024, 2) as MB,
    ROUND(bytes/1024/1024/1024, 2) as GB
FROM dba_segments 
WHERE segment_name = '$TABLE' AND owner = '$SCHEMA';
"

# Paso 11: Shrink completo
execute_sql "11_shrink_completo" "
ALTER TABLE $SCHEMA.$TABLE SHRINK SPACE;
"

# Paso 12: Verificar tamaño final
execute_sql "12_tamaño_final" "
SELECT 
    segment_name,
    bytes,
    ROUND(bytes/1024/1024, 2) as MB,
    ROUND(bytes/1024/1024/1024, 2) as GB
FROM dba_segments 
WHERE segment_name = '$TABLE' AND owner = '$SCHEMA';
"

# Paso 13: Limpiar tarea del Segment Advisor
execute_sql "13_limpiar_tarea" "
BEGIN
    DBMS_ADVISOR.DELETE_TASK('$TASK_NAME');
EXCEPTION
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('Error al eliminar tarea: ' || SQLERRM);
END;
/"

# Crear resumen final
SUMMARY_FILE="$EVIDENCE_DIR/resumen_ejecucion.txt"
echo "RESUMEN DE EJECUCIÓN" > "$SUMMARY_FILE"
echo "===================" >> "$SUMMARY_FILE"
echo "Servidor: $(hostname)" >> "$SUMMARY_FILE"
echo "Usuario: $(whoami)" >> "$SUMMARY_FILE"
echo "ORACLE_HOME: $ORACLE_HOME" >> "$SUMMARY_FILE"
echo "ORACLE_SID: $ORACLE_SID" >> "$SUMMARY_FILE"
echo "Esquema: $SCHEMA" >> "$SUMMARY_FILE"
echo "Tabla: $TABLE" >> "$SUMMARY_FILE"
echo "Tarea: $TASK_NAME (basado en ${SCHEMA}.${TABLE})" >> "$SUMMARY_FILE"
echo "Fecha: $(date)" >> "$SUMMARY_FILE"
echo "" >> "$SUMMARY_FILE"
echo "Archivos de evidencia generados:" >> "$SUMMARY_FILE"
ls -la "$EVIDENCE_DIR"/*.txt >> "$SUMMARY_FILE" 2>/dev/null
echo "" >> "$SUMMARY_FILE"
echo "Revise el archivo $LOG_FILE para el log completo de la ejecución" >> "$SUMMARY_FILE"

echo "=============================================" | tee -a "$LOG_FILE"
echo "PROCESO COMPLETADO" | tee -a "$LOG_FILE"
echo "Todas las evidencias se guardaron en: $EVIDENCE_DIR" | tee -a "$LOG_FILE"
echo "Log principal: $LOG_FILE" | tee -a "$LOG_FILE"
echo "Resumen: $SUMMARY_FILE" | tee -a "$LOG_FILE"
echo "=============================================" | tee -a "$LOG_FILE"

echo ""
echo "✅ Script completado. Revise los archivos de evidencia en el directorio: $EVIDENCE_DIR"
