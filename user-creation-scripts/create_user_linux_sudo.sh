#!/bin/bash

# Script para crear usuario con permisos sudo sin contraseña en RHEL 8/9
# Uso: ./create_user_linux_sudo.sh <nombre_usuario>

set -e  # Salir si hay algún error

# Verificar si se ejecuta como root
if [[ $EUID -ne 0 ]]; then
   echo "Error: Este script debe ejecutarse como root (sudo)"
   exit 1
fi

# Verificar parámetros
if [ $# -ne 1 ]; then
    echo "Uso: $0 <nombre_usuario>"
    echo "Ejemplo: $0 adminuser"
    exit 1
fi

USERNAME=$1

# Validar nombre de usuario
if ! [[ "$USERNAME" =~ ^[a-z_][a-z0-9_-]*$ ]]; then
    echo "Error: Nombre de usuario inválido. Use solo letras minúsculas, números, guiones y guiones bajos."
    echo "Debe comenzar con letra o guión bajo."
    exit 1
fi

# Verificar si el usuario ya existe
if id "$USERNAME" &>/dev/null; then
    echo "Error: El usuario '$USERNAME' ya existe"
    exit 1
fi

echo "=== Creando usuario con permisos sudo sin contraseña ==="
echo "Usuario: $USERNAME"
echo

# Crear el usuario
echo "1. Creando usuario '$USERNAME'..."
useradd -m -s /bin/bash "$USERNAME"

if [ $? -eq 0 ]; then
    echo "   ✓ Usuario creado exitosamente"
else
    echo "   ✗ Error al crear el usuario"
    exit 1
fi

# Establecer contraseña
echo "2. Estableciendo contraseña para el usuario..."
echo "Ingrese la contraseña para el usuario '$USERNAME':"
passwd "$USERNAME"

if [ $? -eq 0 ]; then
    echo "   ✓ Contraseña establecida exitosamente"
else
    echo "   ✗ Error al establecer la contraseña"
    exit 1
fi

# Agregar usuario al grupo wheel (grupo con permisos sudo en RHEL)
echo "3. Agregando usuario al grupo 'wheel'..."
usermod -aG wheel "$USERNAME"

if [ $? -eq 0 ]; then
    echo "   ✓ Usuario agregado al grupo wheel"
else
    echo "   ✗ Error al agregar usuario al grupo wheel"
    exit 1
fi

# Crear archivo sudoers personalizado para el usuario
echo "4. Configurando permisos sudo sin contraseña..."
SUDOERS_FILE="/etc/sudoers.d/10-${USERNAME}-nopasswd"

# Crear el archivo sudoers
cat > "$SUDOERS_FILE" << EOF
# Permitir al usuario $USERNAME ejecutar cualquier comando sin contraseña
$USERNAME ALL=(ALL) NOPASSWD: ALL
EOF

# Establecer permisos correctos para el archivo sudoers
chmod 440 "$SUDOERS_FILE"

# Verificar la sintaxis del archivo sudoers
if visudo -c -f "$SUDOERS_FILE" >/dev/null 2>&1; then
    echo "   ✓ Configuración sudo creada correctamente"
else
    echo "   ✗ Error en la configuración sudo, eliminando archivo..."
    rm -f "$SUDOERS_FILE"
    exit 1
fi

# Crear directorio .ssh si se necesita para llaves SSH
echo "5. Preparando directorio SSH..."
USER_HOME="/home/$USERNAME"
SSH_DIR="$USER_HOME/.ssh"

mkdir -p "$SSH_DIR"
chown "$USERNAME:$USERNAME" "$SSH_DIR"
chmod 700 "$SSH_DIR"

echo "   ✓ Directorio SSH preparado"

echo
echo "=== CONFIGURACIÓN COMPLETADA ==="
echo "Usuario: $USERNAME"
echo "Grupo: wheel"
echo "Sudo: SIN contraseña"
echo "Directorio home: $USER_HOME"
echo "Archivo sudoers: $SUDOERS_FILE"
echo

echo "=== SIGUIENTES PASOS OPCIONALES ==="
echo "1. Para configurar acceso SSH con llave pública:"
echo "   su - $USERNAME"
echo "   ssh-keygen -t rsa -b 4096"
echo "   # Luego agregar llave pública a ~/.ssh/authorized_keys"
echo
echo "2. Probar permisos sudo:"
echo "   su - $USERNAME"
echo "   sudo whoami  # Debería mostrar 'root' sin pedir contraseña"
echo

# Mostrar información del usuario creado
echo "=== INFORMACIÓN DEL USUARIO ==="
id "$USERNAME"
groups "$USERNAME"

echo
echo "✓ Script completado exitosamente"
