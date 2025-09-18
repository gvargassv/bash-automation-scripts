# Oracle Segment Advisor & Shrink Automation Script

Automatiza el proceso completo de análisis de segmentos y shrink de tablas Oracle usando Segment Advisor, con logging detallado y generación de evidencias.

## 📋 Descripción

Este script bash automatiza las siguientes tareas:
- Ejecuta Oracle Segment Advisor para analizar segmentos de tabla
- Obtiene recomendaciones de optimización
- Ejecuta shrink de tabla (compacto y completo)
- Registra todos los pasos con timestamps y duración
- Genera archivos de evidencia para auditoría

## 🎯 Características

- ✅ **Ejecución local segura**: Usa conexión `/ as sysdba` sin credenciales
- ✅ **Logging completo**: Registra cada paso con duración y resultados
- ✅ **Generación de evidencias**: Archivos separados por cada operación
- ✅ **Detección de errores**: Identifica y reporta errores Oracle automáticamente
- ✅ **Nombres de tarea inteligentes**: Genera nombres únicos respetando límites de Oracle
- ✅ **Comparación de tamaños**: Muestra tamaño antes y después del shrink

## 📋 Prerrequisitos

### Sistema Operativo
- Linux/Unix con Oracle Database instalado
- Usuario `oracle` o equivalente con permisos DBA
- Bash shell

### Base de Datos Oracle
- Oracle Database 11g o superior
- Variables de entorno configuradas:
  - `ORACLE_HOME`
  - `ORACLE_SID` (o proporcionado como parámetro)
  - `PATH` incluyendo `$ORACLE_HOME/bin`
- Conexión local `/ as sysdba` disponible
- Base de datos en estado OPEN

### Permisos Requeridos
- Privilegios DBA para ejecutar `DBMS_ADVISOR`
- Permisos `ALTER TABLE` en el esquema objetivo
- Acceso de lectura a vistas `DBA_*`

## 🚀 Instalación

1. **Clonar o descargar el script**:
   ```bash
   wget https://raw.githubusercontent.com/tu-usuario/tu-repo/main/oracle_shrink.sh
   chmod +x oracle_shrink.sh
   ```

2. **Verificar entorno Oracle**:
   ```bash
   echo $ORACLE_HOME
   echo $ORACLE_SID
   sqlplus / as sysdba
   ```

## 💻 Uso

### Sintaxis Básica
```bash
./oracle_shrink.sh <esquema> <tabla> [ORACLE_SID]
```

### Ejemplos

1. **Uso simple** (usando ORACLE_SID del entorno):
   ```bash
   ./oracle_shrink.sh SALES CUSTOMERS
   ```

2. **Especificando SID**:
   ```bash
   ./oracle_shrink.sh SALES CUSTOMERS PROD
   ```

3. **Con configuración de entorno**:
   ```bash
   export ORACLE_HOME=/u01/app/oracle/product/19.0.0/dbhome_1
   export ORACLE_SID=PROD
   ./oracle_shrink.sh HR EMPLOYEES
   ```

### Parámetros

| Parámetro | Tipo | Descripción | Ejemplo |
|-----------|------|-------------|---------|
| `esquema` | Obligatorio | Esquema propietario de la tabla | `SALES` |
| `tabla` | Obligatorio | Nombre de la tabla a analizar | `CUSTOMERS` |
| `ORACLE_SID` | Opcional | SID de la base de datos | `PROD` |

## 📁 Archivos de Salida

El script crea un directorio con timestamp: `evidencias_<ESQUEMA>_<TABLA>_<YYYYMMDD_HHMMSS>`

### Estructura de Archivos
```
evidencias_SALES_CUSTOMERS_20241201_143022/
├── ejecucion_completa.log           # Log principal completo
├── resumen_ejecucion.txt            # Resumen ejecutivo
├── 01_crear_tarea_143022.txt        # Evidencia paso 1
├── 01_crear_tarea_spool.log         # SQL*Plus spool paso 1
├── 02_crear_objeto_143023.txt       # Evidencia paso 2
├── ...                              # Otros pasos
├── 07_tamaño_inicial_143025.txt     # Tamaño antes del shrink
├── 10_tamaño_post_compact_143027.txt # Tamaño después shrink compacto
└── 12_tamaño_final_143029.txt       # Tamaño final
```

### Contenido de Logs
- **Timestamp** de inicio y fin de cada paso
- **Duración** en segundos de cada operación
- **Comando SQL** ejecutado
- **Salida completa** de cada comando
- **Detección automática** de errores Oracle

## 📊 Proceso Paso a Paso

1. **Verificación de conectividad** - Valida conexión a BD
2. **Crear tarea Segment Advisor** - Inicializa análisis
3. **Crear objeto de análisis** - Define tabla objetivo
4. **Configurar parámetros** - Configura recomendaciones
5. **Ejecutar análisis** - Ejecuta Segment Advisor
6. **Consultar resultados** - Obtiene findings y recomendaciones
7. **Consultar tamaño inicial** - Registra tamaño pre-shrink
8. **Habilitar row movement** - Prepara tabla para shrink
9. **Shrink compacto** - Primera fase de optimización
10. **Consultar tamaño intermedio** - Registra progreso
11. **Shrink completo** - Liberación final de espacio
12. **Consultar tamaño final** - Registra resultado final
13. **Limpieza** - Elimina objetos temporales

## ⚠️ Consideraciones de Seguridad

### Impacto en Producción
- **Shrink compacto**: Mínimo impacto, permite operaciones DML concurrentes
- **Shrink completo**: Bloquea la tabla brevemente, planificar ventana de mantenimiento
- **Row movement**: Puede invalidar ROWIDs existentes

### Recomendaciones
- Ejecutar en ventana de mantenimiento para shrink completo
- Verificar que no existan ROWIDs hardcodeados en aplicaciones
- Hacer backup antes de ejecutar en tablas críticas
- Monitorear espacio disponible en tablespace

## 🔧 Troubleshooting

### Errores Comunes

#### Error: ORACLE_HOME no configurado
```bash
Error: Variable ORACLE_HOME no está configurada
```
**Solución**: Configurar entorno Oracle
```bash
export ORACLE_HOME=/ruta/oracle/home
export PATH=$ORACLE_HOME/bin:$PATH
```

#### Error: No se puede conectar a BD
```bash
Error: No se puede conectar a la base de datos
```
**Solución**: Verificar que la BD esté ejecutándose y ORACLE_SID sea correcto

#### Error: ORA-01031 insufficient privileges
**Solución**: Ejecutar como usuario con privilegios DBA o sysdba

#### Error: ORA-10635 Invalid segment or tablespace type
**Solución**: La tabla puede estar en un tablespace read-only o ser una tabla temporal

### Verificación de Prerrequisitos
```bash
# Verificar entorno
env | grep ORACLE

# Verificar conectividad
sqlplus / as sysdba << EOF
SELECT instance_name, status FROM v\$instance;
EXIT;
EOF

# Verificar permisos DBA
sqlplus / as sysdba << EOF
SELECT * FROM session_privs WHERE privilege LIKE '%DBA%';
EXIT;
EOF
```

## 📈 Interpretación de Resultados

### Archivos de Tamaño
Los archivos `07_tamaño_inicial`, `10_tamaño_post_compact`, y `12_tamaño_final` muestran:
- **bytes**: Tamaño en bytes
- **MB**: Tamaño en megabytes
- **GB**: Tamaño en gigabytes

### Ejemplo de Ahorro
```
Tamaño inicial: 1,024 MB
Post-compact:   900 MB    (ahorro: 124 MB)
Tamaño final:   850 MB    (ahorro total: 174 MB)
```

## 🤝 Contribuciones

Las contribuciones son bienvenidas. Por favor:

1. Fork el repositorio
2. Crea una branch para tu feature (`git checkout -b feature/mejora`)
3. Commit tus cambios (`git commit -am 'Agregar nueva funcionalidad'`)
4. Push a la branch (`git push origin feature/mejora`)
5. Abre un Pull Request

### Áreas de Mejora
- Soporte para múltiples tablas en batch
- Integración con Oracle Enterprise Manager
- Reportes HTML/JSON de resultados
- Validaciones adicionales pre-shrink

## 📄 Licencia

Este proyecto está licenciado bajo la Licencia MIT - ver el archivo [LICENSE](LICENSE) para detalles.

## ✍️ Autor

Desarrollado para automatizar tareas de administración Oracle con logging completo y generación de evidencias.

## 📞 Soporte

Para reportar bugs o solicitar features, por favor abre un [issue](../../issues) en este repositorio.

---

**⚡ Tip**: Siempre ejecuta en un entorno de prueba primero y verifica los resultados antes de usar en producción.
