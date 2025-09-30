# Oracle Index Maintenance Scripts

Este directorio contiene scripts para tareas de mantenimiento de índices
en Oracle Database.

## 📌 Scripts incluidos

### 1. `oracle_index_rebuild.sh`

Rebuild de un índice específico en Oracle Database con auditoría de
ejecución.

#### Uso

``` bash
./oracle_index_rebuild.sh <OWNER> <INDEX_NAME>
```

#### Parámetros

-   `OWNER`: Esquema propietario del índice (ejemplo: HR, SALES).
-   `INDEX_NAME`: Nombre del índice a reconstruir.

#### Ejemplos

``` bash
./oracle_index_rebuild.sh HR EMP_NAME_IDX
./oracle_index_rebuild.sh SALES PK_ORDERS
```

#### Archivos generados

-   **Log principal de auditoría** →
    `index_rebuild_<EXECUTION_ID>/index_rebuild_audit.log`
-   **Log detallado de ejecución** →
    `index_rebuild_<EXECUTION_ID>/detailed_<EXECUTION_ID>.log`
-   **Reporte de auditoría** →
    `index_rebuild_<EXECUTION_ID>/rebuild_report_<EXECUTION_ID>.txt`

#### Dependencias

-   `sqlplus` (Oracle Instant Client o cliente completo instalado).
-   Usuario con permisos suficientes (`/ as sysdba` o credenciales
    adecuadas).

------------------------------------------------------------------------
