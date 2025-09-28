# Ejemplos de Uso

## 🔧 Script AIX - Creación Masiva

### Ejemplo básico

```bash
./create_users_aix.sh -u deployuser -p 'SecureP@ss123' -s root -W ssh_passwords.txt -f servers.txt
```

---

## 📄 Archivos de Configuración Requeridos

### 🖥️ Archivo `servers.txt`

Este archivo contiene la lista de servidores AIX donde se crearán los usuarios.  
Formato:

- Una IP o hostname por línea  
- Líneas que comienzan con `#` son comentarios  
- Líneas vacías son ignoradas  
- Se eliminan automáticamente espacios y caracteres extraños  

Ejemplo de contenido:

```text
# Servidores de producción AIX
192.168.1.10
192.168.1.11
192.168.1.12

# Servidores de desarrollo
aix-dev01.company.com
aix-dev02.company.com

# Servidor de pruebas
10.0.0.15
```

---

### 🔐 Archivo `ssh_passwords.txt`

Este archivo contiene las contraseñas SSH para conectarse a cada servidor.  
Es crítico que cada línea corresponda exactamente al servidor en la misma posición del archivo `servers.txt`.

⚠️ **IMPORTANTE - CORRESPONDENCIA EXACTA:**

- El orden **DEBE** coincidir línea por línea con `servers.txt`  
- Una contraseña por línea  
- Sin comentarios ni líneas vacías adicionales  
- Mantener este archivo seguro (**permisos 600**)  
- Si hay comentarios en `servers.txt`, **NO** los incluyas en `ssh_passwords.txt`  

Ejemplo de contenido (`ssh_passwords.txt`):

```text
RootPassword123!
RootPassword456@
DevPassword789#
DevPassword012$
TestPassword345%
```

Correspondencia con `servers.txt`:

```text
LÍNEA  servers.txt              ssh_passwords.txt
  1    192.168.1.10         →   RootPassword123!
  2    192.168.1.11         →   RootPassword456@
  3    192.168.1.12         →   DevPassword789#
  4    aix-dev01.company... →   DevPassword012$
  5    10.0.0.15            →   TestPassword345%
```

**NOTA:** Los comentarios (`#`) y líneas vacías en `servers.txt`  
se ignoran automáticamente, **NO** cuentan para la correspondencia.

---

## 🔒 Configuración de Seguridad para Archivos

```bash
# Establecer permisos seguros para archivos de contraseñas
chmod 600 ssh_passwords.txt
chmod 644 servers.txt

# Verificar permisos
ls -la *.txt
```

---

## 🚀 Ejemplos Completos de Ejecución

### Ejemplo 1: Crear usuario de aplicación

```bash
# Preparar archivos
echo -e "192.168.1.10\n192.168.1.11" > servers.txt
echo -e "Pass123!\nPass456@" > ssh_passwords.txt
chmod 600 ssh_passwords.txt

# Ejecutar script
./create_users_aix.sh -u appuser -p 'AppUser123!' -s root -W ssh_passwords.txt -f servers.txt
```

---

### Ejemplo 2: Crear usuario administrativo

```bash
# Servidores de infraestructura
cat > servers.txt << 'EOF'
# Servidores críticos
192.168.10.5
192.168.10.6
192.168.10.7
EOF

# Contraseñas (una por servidor)
cat > ssh_passwords.txt << 'EOF'
CriticalPass1!
CriticalPass2@
CriticalPass3#
EOF

chmod 600 ssh_passwords.txt

# Crear usuario sysadmin
./create_users_aix.sh -u sysadmin -p 'SysAdmin789!' -s root -W ssh_passwords.txt -f servers.txt
```

---

### Ejemplo 3: Validación previa completa

```bash
#!/bin/bash

# Archivos de configuración
SERVERS_FILE="servers.txt"
PASSWORDS_FILE="ssh_passwords.txt"
USERNAME="deployuser"
USER_PASSWORD="Deploy123!"
SSH_USER="admin"

# Validar que archivos existan
if [ ! -f "$SERVERS_FILE" ]; then
    echo "❌ Archivo $SERVERS_FILE no encontrado"
    exit 1
fi

if [ ! -f "$PASSWORDS_FILE" ]; then
    echo "❌ Archivo $PASSWORDS_FILE no encontrado"
    exit 1
fi

# Contar líneas (deben coincidir)
servers_count=$(grep -v '^#' "$SERVERS_FILE" | grep -v '^$' | wc -l)
passwords_count=$(wc -l < "$PASSWORDS_FILE")

if [ "$servers_count" -ne "$passwords_count" ]; then
    echo "❌ El número de servidores ($servers_count) no coincide con contraseñas ($passwords_count)"
    exit 1
fi

echo "✅ Validación completa. Archivos correctos."
```

---

### Ejemplo 4: Crear múltiples usuarios con diferentes configuraciones

```bash
#!/bin/bash

# Array de usuarios a crear
declare -A users=(
    ["devuser"]="DevPass123!"
    ["testuser"]="TestPass456@"
    ["monitoruser"]="MonitorPass789#"
)

# Crear cada usuario
for username in "${!users[@]}"; do
    echo "🔄 Creando usuario: $username"
    ./create_users_aix.sh -u "$username" -p "${users[$username]}" -s root -W ssh_passwords.txt -f servers.txt
    
    if [ $? -eq 0 ]; then
        echo "✅ Usuario $username creado exitosamente"
    else
        echo "❌ Error creando usuario $username"
    fi
    echo "================================"
done
```
