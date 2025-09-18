# Guía de Troubleshooting

## 🚨 Errores Críticos

### Error: ORA-13608 - Nombre de tarea inválido
```
ORA-13608: The specified name XX_SCHEMA_TABLE_NAME... is invalid.
```

**Causa**: El nombre de la tarea excede 30 caracteres
**Solución**: El script ya maneja esto automáticamente generando nombres cortos con hash

**Verificación**:
```bash
# El script debe mostrar:
Nombre de tarea generado: XX_A1B2C3D4_143022 (18 caracteres)
```

### Error: ORA-00942 - Tabla o vista no existe
```
ORA-00942: table or view does not exist
```

**Causa**: La tabla especificada no existe o no tienes permisos
**Diagnóstico**:
```sql
-- Verificar existencia de tabla
SELECT owner, table_name, status 
FROM dba_tables 
WHERE owner = 'SCHEMA_NAME' AND table_name = 'TABLE_NAME';

-- Verificar permisos
SELECT privilege 
FROM dba_tab_privs 
WHERE grantee = USER 
AND owner = 'SCHEMA_NAME' 
AND table_name = 'TABLE_NAME';
```

### Error: ORA-01031 - Privilegios insuficientes
```
ORA-01031: insufficient privileges
```

**Causa**: Usuario sin privilegios DBA
**Solución**:
```sql
-- Otorgar privilegios necesarios (como SYS)
GRANT DBA TO oracle;
-- O privilegios específicos
GRANT ADVISOR TO oracle;
GRANT ALTER ANY TABLE TO oracle;
```

## 🔧 Problemas de Conexión

### Error: ORACLE_HOME no configurado
```
Error: Variable ORACLE_HOME no está configurada
```

**Solución**:
```bash
# Encontrar ORACLE_HOME
ps -ef | grep pmon
# O usar oratab
cat /etc/oratab

# Configurar entorno
export ORACLE_HOME=/u01/app/oracle/product/19.0.0/dbhome_1
export PATH=$ORACLE_HOME/bin:$PATH
export ORACLE_SID=PROD
```

### Error: No se puede conectar a la base de datos
```
Error: No se puede conectar a la base de datos
```

**Diagnóstico paso a paso**:
```bash
# 1. Verificar que la BD esté ejecutándose
ps -ef | grep pmon | grep $ORACLE_SID

# 2. Verificar listener
lsnrctl status

# 3. Verificar conectividad local
sqlplus / as sysdba
```

**Causas comunes**:
- Base de datos detenida: `startup;`
- ORACLE_SID incorrecto: verificar con `ps -ef | grep pmon`
- Listener detenido: `lsnrctl start`

## ⚠️ Problemas Durante Shrink

### Error: ORA-10635 - Tipo de segmento inválido
```
ORA-10635: Invalid segment or tablespace type
```

**Causas**:
- Tablespace read-only
- Tabla temporal
- Tabla con LOBs complejos

**Diagnóstico**:
```sql
-- Verificar tipo de tablespace
SELECT tablespace_name, status 
FROM dba_tablespaces 
WHERE tablespace_name = (
    SELECT tablespace_name 
    FROM dba_tables 
    WHERE owner = 'SCHEMA' AND table_name = 'TABLE'
);

-- Verificar si es tabla temporal
SELECT temporary, duration 
FROM dba_tables 
WHERE owner = 'SCHEMA' AND table_name = 'TABLE';
```

### Error: ORA-00054 - Recurso ocupado
```
ORA-00054: resource busy and acquire with NOWAIT specified
```

**Causa**: Tabla bloqueada por otra sesión
**Diagnóstico**:
```sql
-- Encontrar sesiones bloqueantes
SELECT 
    s.sid, 
    s.serial#, 
    s.username, 
    s.program,
    l.type,
    l.lmode
FROM v$session s, v$lock l, dba_objects o
WHERE s.sid = l.sid
AND l.id1 = o.object_id
AND o.owner = 'SCHEMA'
AND o.object_name = 'TABLE'
AND l.type = 'TM';
```

**Solución**:
```sql
-- Si es seguro, terminar la sesión bloqueante
ALTER SYSTEM KILL SESSION 'sid,serial#';
-- O esperar a que termine naturalmente
```

## 📊 Problemas de Performance

### Shrink muy lento
**Síntomas**: El shrink toma más de 1 hora para tablas < 10GB

**Diagnóstico**:
```sql
-- Verificar progreso del shrink
SELECT 
    sid, 
    serial#, 
    context, 
    sofar, 
    totalwork,
    ROUND(sofar/totalwork*100, 2) as pct_done
FROM v$session_longops
WHERE opname LIKE '%shrink%';

-- Verificar I/O
SELECT event, total_waits, time_waited
FROM v$session_event
WHERE sid = <session_id>
AND event LIKE '%I/O%';
```

**Optimizaciones**:
- Ejecutar durante ventana de baja actividad
- Considerar usar `SHRINK SPACE CASCADE` para tablas con índices
- Verificar que no hay procesos de backup concurrentes

### Script se cuelga
**Síntomas**: El script no avanza por más de 30 minutos

**Diagnóstico**:
```bash
# Verificar proceso del script
ps aux | grep oracle_shrink

# Verificar sesiones Oracle activas
sqlplus / as sysdba << EOF
SELECT sid, serial#, status, last_call_et
FROM v\$session 
WHERE username = 'ORACLE'
AND status = 'ACTIVE';
EOF
```

**Solución**:
```bash
# Terminar el script
kill -TERM <pid>

# Limpiar tarea del Segment Advisor si quedó pendiente
sqlplus / as sysdba << EOF
BEGIN
    FOR task IN (SELECT task_name FROM dba_advisor_tasks 
                 WHERE task_name LIKE 'XX_%') 
    LOOP
        DBMS_ADVISOR.DELETE_TASK(task.task_name);
    END LOOP;
END;
/
EOF
```

## 📁 Problemas con Archivos de Salida

### Permisos de escritura
```
mkdir: cannot create directory: Permission denied
```

**Solución**:
```bash
# Verificar permisos del directorio actual
ls -la .

# Ejecutar en directorio con permisos
cd /tmp
/ruta/completa/oracle_shrink.sh SCHEMA TABLE
```

### Espacio insuficiente
```
No space left on device
```

**Diagnóstico**:
```bash
# Verificar espacio disponible
df -h .

# Verificar inodes
df -i .
```

**Solución**:
```bash
# Limpiar archivos temporales
find /tmp -name "*.tmp" -mtime +1 -delete

# Usar otro directorio con más espacio
export TMPDIR=/u01/temp
```

## 🔍 Validación de Resultados

### Verificar que el shrink fue efectivo
```sql
-- Comparar estadísticas antes y después
SELECT 
    last_analyzed,
    num_rows,
    blocks,
    avg_row_len,
    chain_cnt
FROM dba_tables 
WHERE owner = 'SCHEMA' AND table_name = 'TABLE';

-- Verificar fragmentación
SELECT 
    avg_space,
    chain_cnt,
    num_rows * avg_row_len as estimated_size,
    blocks * 8192 as actual_size
FROM dba_tables 
WHERE owner = 'SCHEMA' AND table_name = 'TABLE';
```

### ROWIDs cambieron después del shrink
**Síntoma**: Aplicaciones reportan errores con ROWIDs

**Verificación**:
```sql
-- Las aplicaciones no deberían usar ROWIDs después de shrink
-- Verificar si hay código que use ROWID
SELECT * FROM dba_source 
WHERE UPPER(text) LIKE '%ROWID%'
AND owner IN ('APP_USER1', 'APP_USER2');
```

## 🚨 Recuperación de Errores

### Si el script falla a mitad de proceso

1. **Verificar estado de la tabla**:
```sql
SELECT row_movement FROM dba_tables 
WHERE owner = 'SCHEMA' AND table_name = 'TABLE';
```

2. **Limpiar tareas pendientes**:
```sql
BEGIN
    FOR task IN (SELECT task_name FROM dba_advisor_tasks 
                 WHERE task_name LIKE 'XX_%') 
    LOOP
        DBMS_ADVISOR.DELETE_TASK(task.task_name);
    END LOOP;
END;
/
```

3. **Revertir row movement si es necesario**:
```sql
ALTER TABLE SCHEMA.TABLE DISABLE ROW MOVEMENT;
```

### Rollback de cambios
**Nota**: El shrink no se puede deshacer, pero no debería causar problemas funcionales.

Si hay problemas:
1. Verificar integridad de datos:
```sql
ANALYZE TABLE SCHEMA.TABLE VALIDATE STRUCTURE;
```

2. Reconstruir índices si es necesario:
```sql
ALTER INDEX SCHEMA.INDEX_NAME REBUILD;
```

## 📞 Escalación

### Cuándo contactar soporte Oracle
- Errores ORA-600 o ORA-7445 durante shrink
- Corrupción de datos detectada
- Performance degradada significativamente después del shrink

### Información a recopilar
- Versión de Oracle: `SELECT banner FROM v$version;`
- Archivos de evidencia completos del script
- Alert log de la base de datos
- Estadísticas de la tabla antes y después

```bash
# Generar reporte completo para soporte
sqlplus / as sysdba << EOF
SPOOL support_info.log
SELECT banner FROM v\$version;
SELECT * FROM v\$option WHERE parameter LIKE '%Segment%';
SELECT owner, table_name, tablespace_name, status
