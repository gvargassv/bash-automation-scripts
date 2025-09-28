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
192.168.1.10
192.168.1.11
192.168.1.12
aix-dev01.company.com
aix-dev02.company.com
10.0.0.15
```

---

### 🔐 Archivo `ssh_passwords.txt`

Este archivo contiene las contraseñas SSH para conectarse a cada servidor. Todas contraseñas puestas en el archivo seran probadas con cada servidor de la lista en el archivo server.txt, cuando encuentra la correcta procede con el proceso de creacion de usuario.

Ejemplo de contenido (`ssh_passwords.txt`):

```text
RootPassword123!
RootPassword456@
DevPassword789#
DevPassword012$
TestPassword345%
```

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
