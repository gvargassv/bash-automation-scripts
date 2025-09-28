# 🛠️ Network Diagnostic Script

Script en **Bash** para diagnóstico de conectividad de red con soporte de pruebas de persistencia, análisis de latencia, verificación de DNS, traceroute, MTU y firewalls locales.  

Su objetivo es proporcionar un **informe completo de la conectividad entre un host y un puerto**, ideal para tareas de troubleshooting, soporte y validaciones en entornos de red o aplicaciones críticas.

---

## 📌 Características principales

- ✅ Verificación de servicios locales (Internet, gateway, DNS).
- ✅ Resolución de DNS (`nslookup`, `dig`).
- ✅ Prueba de **ping** con estadísticas.
- ✅ Prueba de **conexión TCP** (via `nc`, `telnet` o bash TCP).
- ✅ Análisis de **traceroute** (`traceroute`, `tracepath`).
- ✅ Prueba de **MTU** en diferentes tamaños.
- ✅ Verificación de **firewall local** (`iptables`, `firewalld`, `ufw`).
- ✅ Análisis de **performance** y latencia promedio.
- ✅ **Prueba de persistencia** de conexión con reporte detallado de estabilidad.
- ✅ Soporte de **modo verbose** para pruebas extendidas.
- ✅ Opción de exportar resultados a archivo.

---

## ⚙️ Uso

```bash
./network_diagnostic.sh -h <host_destino> -p <puerto> [opciones]
```

### Opciones obligatorias:
- `-h <host>` → Host o IP destino.  
- `-p <puerto>` → Puerto destino.  

### Opciones adicionales:
- `-t <timeout>` → Timeout en segundos (default: 10).  
- `-c <count>` → Número de pings (default: 4).  
- `-d <duration>` → Duración de prueba de persistencia en segundos (default: 0 = no ejecutar).  
- `-i <interval>` → Intervalo entre verificaciones en segundos (default: 5).  
- `-k` → Mantener conexión activa durante la prueba de persistencia.  
- `-v` → Modo verbose (ejecuta pruebas adicionales: traceroute, MTU, performance).  
- `-f <archivo>` → Guardar resultado en archivo.  
- `--help` → Mostrar ayuda.  

---

## 📄 Ejemplos de uso

```bash
# Prueba básica a Google HTTPS
./network_diagnostic.sh -h google.com -p 443

# Prueba SSH con timeout y pings extra
./network_diagnostic.sh -h 192.168.1.100 -p 22 -t 5 -c 10

# Prueba MySQL con modo verbose y log en archivo
./network_diagnostic.sh -h servidor.local -p 3306 -v -f diagnostico.log

# Prueba HTTP con persistencia de 5 minutos
./network_diagnostic.sh -h servidor.com -p 80 -d 300 -i 10 -k
```

---

## 📊 Salida esperada

El script muestra resultados en tiempo real y genera un **resumen final de diagnóstico**, incluyendo:
- Estado de resolución DNS.
- Resultados de ping y conexión TCP.
- Análisis de traceroute y MTU.
- Verificación de firewall local.
- Estabilidad de conexión en pruebas de persistencia.
- Recomendaciones basadas en los resultados obtenidos.  

Ejemplo de salida resumida:

```
[2025-09-27 23:45:12] Iniciando diagnóstico de conectividad...
[2025-09-27 23:45:12] Host destino: google.com
[2025-09-27 23:45:12] Puerto: 443

=== RESUMEN DIAGNÓSTICO ===
✅ DIAGNÓSTICO BÁSICO: Conexión completamente funcional
✅ DIAGNÓSTICO DE PERSISTENCIA: Conexión estable durante toda la prueba
```

---

## 📥 Requisitos

El script utiliza utilidades estándar de Linux/Unix. Algunas opcionales para pruebas extendidas:  
- `ping`  
- `nc` (netcat)  
- `telnet`  
- `traceroute` o `tracepath`  
- `nslookup` o `dig`  
- `iptables`, `firewalld`, `ufw` (para firewall local)  
- `bc` (para cálculos de latencia promedio)

---

## 📌 Código de salida

El script retorna códigos de salida que pueden integrarse en otras herramientas (ej. Ansible, monitoreo):

- `0` → Todo OK.  
- `1` → Conexión con problemas menores.  
- `2` → Conexión básica falló (TCP).  
- `3` → Conexión muy inestable.  

---
