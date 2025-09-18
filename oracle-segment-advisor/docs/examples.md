# Ejemplos de Uso

## Ejemplo 1: Tabla de Transacciones (Caso Real)

```bash
./oracle_shrink.sh SALES TRANSACTIONS PROD
```

### Salida Esperada
```
✅ Conectividad verificada correctamente
Nombre de tarea generado: XX_A1B2C3D4_143022 (18 caracteres)
=============================================
INICIO DEL PROCESO DE SEGMENT ADVISOR Y SHRINK
Servidor: oracle-prod-01
Usuario: oracle
ORACLE_HOME: /u01/app/oracle/product/19.0.0/dbhome_1
ORACLE_SID: PROD
Esquema: SALES
Tabla: TRANSACTIONS
Tarea: XX_A1B2C3D4_143022 (basado en SALES.TRANSACTIONS)
Fecha/Hora: Thu Dec 01 14:30:22 CST 2024
Directorio de evidencias: evidencias_SALES_TRANSACTIONS_20241201_143022
=============================================
```

### Resultado Típico
- **Tiempo total**: 2-5 minutos
- **Archivos generados**: 15-20 archivos de evidencia
- **Ahorro típico**: 10-30% del espacio original

## Ejemplo 2: Tabla Grande con Mucho Ahorro

```bash
./oracle_shrink.sh WAREHOUSE INVENTORY_HISTORY
```

### Caso de Estudio: Tabla de 50GB
```
Tamaño inicial:     51,200 MB (50 GB)
Post-shrink compact: 45,056 MB (44 GB) - Ahorro: 6.14 GB
Tamaño final:       42,240 MB (41.25 GB) - Ahorro total: 8.75 GB (17%)
```

### Log de Tiempos
```
PASO: 01_crear_tarea - DURACIÓN: 1 segundos
PASO: 02_crear_objeto - DURACIÓN: 1 segundos
PASO: 04_ejecutar_tarea - DURACIÓN: 45 segundos
PASO: 08_habilitar_row_movement - DURACIÓN: 2 segundos
PASO: 09_shrink_compact - DURACIÓN: 180 segundos (3 min)
PASO: 11_shrink_completo - DURACIÓN: 120 segundos (2 min)
```

## Ejemplo 3: Múltiples Tablas (Script de Batch)

Para procesar múltiples tablas, crear un script wrapper:

```bash
#!/bin/bash
# batch_shrink.sh

TABLES=(
    "SALES:CUSTOMERS"
    "SALES:ORDERS"
    "SALES:ORDER_ITEMS"
    "HR:EMPLOYEES"
    "HR:DEPARTMENTS"
)

for table_info in "${TABLES[@]}"; do
    SCHEMA=$(echo $table_info | cut -d: -f1)
    TABLE=$(echo $table_info | cut -d: -f2)
    
    echo "Procesando $SCHEMA.$TABLE..."
    ./oracle_shrink.sh $SCHEMA $TABLE
    
    echo "Esperando 30 segundos antes de la siguiente tabla..."
    sleep 30
done
```

## Ejemplo 4: Verificación Pre-Shrink

Antes de ejecutar el shrink, verificar el estado de la tabla:

```sql
-- Verificar tamaño actual
SELECT 
    segment_name,
    ROUND(bytes/1024/1024/1024, 2) as GB,
    tablespace_name
FROM dba_segments 
WHERE owner = 'SALES' AND segment_name = 'TRANSACTIONS';

-- Verificar actividad reciente
SELECT COUNT(*) as active_sessions
FROM v$session s, v$lock l
WHERE s.sid = l.sid
AND l.type = 'TM'
AND l.id1 = (SELECT object_id FROM dba_objects 
              WHERE owner = 'SALES' AND object_name = 'TRANSACTIONS');

-- Verificar fragmentación
SELECT 
    avg_space, 
    chain_cnt, 
    avg_row_len,
    num_rows
FROM dba_tables 
WHERE owner = 'SALES' AND table_name = 'TRANSACTIONS';
```

## Ejemplo 5: Monitoreo Durante Ejecución

En otra sesión, monitorear el progreso:

```bash
# Monitorear archivos de log en tiempo real
tail -f evidencias_SALES_TRANSACTIONS_*/ejecucion_completa.log

# Verificar sesiones activas
sqlplus / as sysdba << EOF
SELECT sid, serial#, username, status, sql_id
FROM v\$session 
WHERE username = 'ORACLE' 
AND status = 'ACTIVE';
EOF

# Monitorear espacio en tablespace
sqlplus / as sysdba << EOF
SELECT 
    tablespace_name,
    ROUND((total_space - free_space)/1024/1024, 2) as used_mb,
    ROUND(free_space/1024/1024, 2) as free_mb,
    ROUND(total_space/1024/1024, 2) as total_mb
FROM (
    SELECT 
        tablespace_name,
        SUM(bytes) as total_space
    FROM dba_data_files
    GROUP BY tablespace_name
) total,
(
    SELECT 
        tablespace_name,
        SUM(bytes) as free_space
    FROM dba_free_space
    GROUP BY tablespace_name
) free
WHERE total.tablespace_name = free.tablespace_name(+);
EOF
```

## Ejemplo 6: Análisis Post-Ejecución

```bash
# Script para analizar resultados
#!/bin/bash
EVIDENCE_DIR="evidencias_SALES_TRANSACTIONS_20241201_143022"

# Extraer información de tamaños
echo "=== ANÁLISIS DE RESULTADOS ==="
echo "Tamaño inicial:"
grep -A 5 "segment_name" $EVIDENCE_DIR/07_tamaño_inicial_*.txt

echo "Tamaño post-compact:"
grep -A 5 "segment_name" $EVIDENCE_DIR/10_tamaño_post_compact_*.txt

echo "Tamaño final:"
grep -A 5 "segment_name" $EVIDENCE_DIR/12_tamaño_final_*.txt

# Calcular ahorro
INITIAL_MB=$(grep -A 1 "segment_name" $EVIDENCE_DIR/07_tamaño_inicial_*.txt | tail -1 | awk '{print $3}')
FINAL_MB=$(grep -A 1 "segment_name" $EVIDENCE_DIR/12_tamaño_final_*.txt | tail -1 | awk '{print $3}')
SAVINGS=$(echo "$INITIAL_MB - $FINAL_MB" | bc)
PERCENTAGE=$(echo "scale=2; ($SAVINGS / $INITIAL_MB) * 100" | bc)

echo "Ahorro total: ${SAVINGS} MB (${PERCENTAGE}%)"
```

## Ejemplo 7: Integración con Crontab

Para ejecución programada semanal:

```bash
# Agregar a crontab del usuario oracle
# Ejecutar cada domingo a las 2:00 AM
0 2 * * 0 /home/oracle/scripts/oracle_shrink.sh SALES TRANSACTIONS_ARCHIVE >> /var/log/oracle_shrink_cron.log 2>&1

# Para múltiples tablas con delay
0 2 * * 0 /home/oracle/scripts/batch_shrink.sh >> /var/log/oracle_batch_shrink.log 2>&1
```

## Ejemplo 8: Validación de Resultados

Script para validar que el shrink fue exitoso:

```bash
#!/bin/bash
# validate_shrink.sh
EVIDENCE_DIR=$1

if [ -z "$EVIDENCE_DIR" ]; then
    echo "Uso: $0 <directorio_evidencias>"
    exit 1
fi

echo "=== VALIDACIÓN DE SHRINK ==="

# Verificar que todos los pasos se completaron
STEPS=(
    "01_crear_tarea"
    "02_crear_objeto"
    "04_ejecutar_tarea"
    "08_habilitar_row_movement"
    "09_shrink_compact"
    "11_shrink_completo"
)

for step in "${STEPS[@]}"; do
    if ls $EVIDENCE_DIR/${step}_*.txt >/dev/null 2>&1; then
        if grep -q "✅ Paso completado exitosamente" $EVIDENCE_DIR/ejecucion_completa.log; then
            echo "✅ $step: COMPLETADO"
        else
            echo "⚠️  $step: CON ADVERTENCIAS"
        fi
    else
        echo "❌ $step: NO ENCONTRADO"
    fi
done

echo ""
echo "=== RESUMEN DE AHORRO ==="
if [ -f "$EVIDENCE_DIR/resumen_ejecucion.txt" ]; then
    cat "$EVIDENCE_DIR/resumen_ejecucion.txt"
fi
```
