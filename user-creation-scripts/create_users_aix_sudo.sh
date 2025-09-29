#!/bin/bash
#
# Script para creación masiva de usuarios en servidores AIX
# Versión: 1.0
#

# Variables de configuración
SERVERS_FILE="servers.txt"
USERNAME=""
PASSWORD=""
SSH_USER=""
SSH_PASSWORD=""
LOG_FILE="user_creation_$(date +%Y%m%d_%H%M%S).log"

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Función para mostrar el uso del script
usage() {
    echo "Uso: $0 -u <usuario_a_crear> -p <password_usuario> -s <usuario_ssh> -w <password_ssh> -f <archivo_servidores>"
    echo ""
    echo "Parámetros:"
    echo "  -u <usuario>     Usuario que se creará en los servidores"
    echo "  -p <password>    Password para el nuevo usuario"
    echo "  -s <ssh_user>    Usuario para conectar por SSH"
    echo "  -w <ssh_pass>    Password del usuario SSH"
    echo "  -f <archivo>     Archivo con lista de IPs"
    echo ""
    echo "Ejemplo:"
    echo "  $0 -u newuser -p 'MyP@ss' -s root -w 'RootPass' -f servers.txt"
    exit 1
}

# Función para logging
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$LOG_FILE"
}

# Función para mostrar mensajes con colores
print_status() {
    local color=$1
    local message=$2
    echo -e "${color}${message}${NC}"
    log "$message"
}

# Función para limpiar y validar IP
validate_ip() {
    local ip="$1"
    # Remover espacios y caracteres extraños
    ip=$(echo "$ip" | tr -d '\r\n\t ' | grep -E '^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$')
    echo "$ip"
}

# Función para crear usuario usando expect
create_user_aix() {
    local server=$1
    local ssh_user=$2
    local ssh_password=$3
    local new_user=$4
    local new_password=$5
    
    print_status "$YELLOW" "Procesando servidor: $server"
    
    # Crear archivo temporal para el script expect
    local expect_script="/tmp/create_user_${server}_$$.exp"
    
    cat > "$expect_script" << 'EXPECTEOF'
#!/usr/bin/expect -f

set timeout 60
set server [lindex $argv 0]
set ssh_user [lindex $argv 1] 
set ssh_password [lindex $argv 2]
set new_user [lindex $argv 3]
set new_password [lindex $argv 4]

proc log_msg {msg} {
    #puts "[exec date '+%Y-%m-%d %H:%M:%S'] - $msg"
    set timestamp [clock format [clock seconds] -format "%Y-%m-%d %H:%M:%S"]
    puts "$timestamp - $msg"
}

log_msg "Iniciando conexión a $server"

# Conectar por SSH
spawn ssh -o StrictHostKeyChecking=no -o ConnectTimeout=15 $ssh_user@$server

expect {
    timeout {
        log_msg "ERROR: Timeout conectando a $server"
        exit 1
    }
    "Connection refused" {
        log_msg "ERROR: Conexión rechazada por $server"
        exit 1
    }
    "No route to host" {
        log_msg "ERROR: No hay ruta a $server"  
        exit 1
    }
    "password:" {
        send "$ssh_password\r"
    }
    "Password:" {
        send "$ssh_password\r"
    }
    -re ".*\\\$|.*#|.*>" {
        log_msg "Conexión exitosa sin password a $server"
    }
}

# Verificar login exitoso
expect {
    timeout {
        log_msg "ERROR: Timeout esperando prompt"
        exit 1
    }
    "Permission denied" {
        log_msg "ERROR: Password incorrecto para $server"
        exit 1
    }
    "Login incorrect" {
        log_msg "ERROR: Login incorrecto para $server"
        exit 1
    }
    -re ".*\\\$|.*#|.*>" {
        log_msg "Login exitoso en $server"
    }
}

# Verificar si necesitamos sudo
send "whoami\r"
expect -re ".*\\\$|.*#|.*>"

if {[string match "*#*" $expect_out(buffer)]} {
    log_msg "Ya somos root en $server"
} else {
    log_msg "Obteniendo permisos sudo en $server"
    send "sudo -s\r"
    expect {
        timeout {
            log_msg "ERROR: Timeout esperando sudo"
            exit 1
        }
        "password" {
            send "$ssh_password\r"
            expect {
                timeout {
                    log_msg "ERROR: Timeout después de password sudo"
                    exit 1
                }
                -re ".*#" {
                    log_msg "Sudo exitoso en $server"
                }
            }
        }
        -re ".*#" {
            log_msg "Sudo sin password en $server"
        }
    }
}

log_msg "Verificando si usuario $new_user existe en $server"

# Verificar si usuario existe
send "id $new_user\r"
expect {
    -re ".*#" {
        if {[string match "*no such user*" $expect_out(buffer)] || [string match "*not found*" $expect_out(buffer)]} {
            set user_exists 0
            log_msg "Usuario $new_user no existe, creando..."
        } else {
            set user_exists 1
            log_msg "Usuario $new_user ya existe en $server"
        }
    }
}

# Crear usuario si no existe
if {$user_exists == 0} {
    log_msg "Creando usuario $new_user en $server"
    
    # Obtener siguiente UID
    send "awk -F: '\$3>=1000 && \$3<65534 {print \$3}' /etc/passwd | sort -n | tail -1\r"
    expect -re ".*#"
    
    # Intentar crear con mkuser (AIX)
    send "if command -v mkuser >/dev/null 2>&1; then echo 'USING_MKUSER'; else echo 'USING_USERADD'; fi\r"
    expect {
        "USING_MKUSER" {
            log_msg "Usando mkuser para crear usuario en $server"
            send "mkuser pgrp=staff groups=staff home=/home/$new_user shell=/usr/bin/ksh $new_user\r"
            expect -re ".*#"
        }
        "USING_USERADD" {
            log_msg "Usando useradd para crear usuario en $server"
            send "useradd -m -s /bin/bash $new_user\r"
            expect -re ".*#"
        }
    }
    
    # Crear directorio home
    send "mkdir -p /home/$new_user\r"
    expect -re ".*#"
    send "chown $new_user:staff /home/$new_user 2>/dev/null || chown $new_user:$new_user /home/$new_user\r"
    expect -re ".*#"
    send "chmod 755 /home/$new_user\r"
    expect -re ".*#"
    
    # Establecer password
    log_msg "Estableciendo password para $new_user en $server"
    send "echo '$new_user:$new_password' | chpasswd\r"
    expect -re ".*#"
    
    log_msg "Usuario $new_user creado en $server"
}

# Configurar sudo
log_msg "Configurando sudo para $new_user en $server"

send "grep '^$new_user ' /etc/sudoers\r"
expect -re ".*#"

if {[string match "*$new_user*ALL*" $expect_out(buffer)]} {
    log_msg "Sudo ya configurado para $new_user en $server"
} else {
    log_msg "Agregando sudo para $new_user en $server"
    #send "cp /etc/sudoers /etc/sudoers.backup.$(date +%Y%m%d_%H%M%S)\r"
    set ts [clock format [clock seconds] -format "%Y%m%d_%H%M%S"]
    send "cp /etc/sudoers /etc/sudoers.backup.$ts\r"
    expect -re ".*#"
    send "echo '$new_user ALL=(ALL) NOPASSWD: ALL' >> /etc/sudoers\r"
    expect -re ".*#"
    
    # Validar sudoers
    send "visudo -c\r"
    expect -re ".*#"
    log_msg "Sudo configurado para $new_user en $server"
}

log_msg "Configuración completada para $new_user en $server"

# Salir
send "exit\r"
expect {
    -re ".*\\\$|.*>" {
        send "exit\r"
    }
    eof {}
}

log_msg "SUCCESS: Usuario $new_user configurado en $server"
exit 0
EXPECTEOF

    # Ejecutar script expect
    if expect "$expect_script" "$server" "$ssh_user" "$ssh_password" "$new_user" "$new_password" >> "$LOG_FILE" 2>&1; then
        print_status "$GREEN" "✓ Usuario $new_user creado exitosamente en $server"
        rm -f "$expect_script"
        return 0
    else
        print_status "$RED" "✗ Error creando usuario $new_user en $server"
        rm -f "$expect_script"
        return 1
    fi
}

# Función para validar conectividad simple
test_connection() {
    local server=$1
    local ssh_user=$2
    local ssh_password=$3
    
    timeout 15 expect << EOF >/dev/null 2>&1
set timeout 10
spawn ssh -o ConnectTimeout=5 -o StrictHostKeyChecking=no $ssh_user@$server "echo test_ok"
expect {
    "password:" { 
        send "$ssh_password\r"
        expect "test_ok" { exit 0 }
    }
    "Password:" { 
        send "$ssh_password\r"
        expect "test_ok" { exit 0 }
    }
    "test_ok" { exit 0 }
    timeout { exit 1 }
}
EOF
}

# Función para validar archivo de servidores
validate_servers_file() {
    local file=$1
    
    if [ ! -f "$file" ]; then
        print_status "$RED" "ERROR: El archivo $file no existe"
        return 1
    fi
    
    if [ ! -s "$file" ]; then
        print_status "$RED" "ERROR: El archivo $file está vacío"
        return 1
    fi
    
    return 0
}

# Verificar dependencias
check_dependencies() {
    if ! command -v expect &> /dev/null; then
        print_status "$RED" "ERROR: expect no está instalado"
        print_status "$YELLOW" "Para instalar: apt-get install expect"
        exit 1
    fi
}

# Función principal
main() {
    print_status "$GREEN" "=== CREACIÓN MASIVA DE USUARIOS AIX v2.1 ==="
    print_status "$YELLOW" "Usuario a crear: $USERNAME"
    print_status "$YELLOW" "Archivo de servidores: $SERVERS_FILE"
    print_status "$YELLOW" "Usuario SSH: $SSH_USER"
    print_status "$YELLOW" "Log file: $LOG_FILE"
    
    # Verificar dependencias
    check_dependencies
    
    # Validar archivo de servidores
    if ! validate_servers_file "$SERVERS_FILE"; then
        exit 1
    fi
    
    # Contar servidores válidos
    local valid_servers=0
    local servers_list=()
    
    while IFS= read -r line || [ -n "$line" ]; do
        # Saltar comentarios y líneas vacías
        [[ -z "$line" || "$line" =~ ^[[:space:]]*# ]] && continue
        
        # Limpiar y validar IP
        local clean_ip=$(validate_ip "$line")
        if [ -n "$clean_ip" ]; then
            servers_list+=("$clean_ip")
            valid_servers=$((valid_servers + 1))
        else
            print_status "$YELLOW" "AVISO: Línea inválida ignorada: '$line'"
        fi
    done < "$SERVERS_FILE"
    
    if [ $valid_servers -eq 0 ]; then
        print_status "$RED" "ERROR: No se encontraron IPs válidas en $SERVERS_FILE"
        exit 1
    fi
    
    print_status "$YELLOW" "Servidores válidos encontrados: $valid_servers"
    
    local success_count=0
    local error_count=0
    local current=0
    
    # Procesar cada servidor
    for server in "${servers_list[@]}"; do
        current=$((current + 1))
        print_status "$YELLOW" "[$current/$valid_servers] === SERVIDOR: $server ==="
        
        # Probar conectividad primero
        if test_connection "$server" "$SSH_USER" "$SSH_PASSWORD"; then
            print_status "$GREEN" "✓ Conectividad OK con $server"
            
            if create_user_aix "$server" "$SSH_USER" "$SSH_PASSWORD" "$USERNAME" "$PASSWORD"; then
                success_count=$((success_count + 1))
            else
                error_count=$((error_count + 1))
            fi
        else
            print_status "$RED" "✗ No se puede conectar a $server"
            error_count=$((error_count + 1))
        fi
        
        echo "========================================"
    done
    
    # Resumen final
    print_status "$GREEN" "=== RESUMEN FINAL ==="
    print_status "$GREEN" "Servidores procesados exitosamente: $success_count"
    print_status "$RED" "Servidores con errores: $error_count"
    print_status "$YELLOW" "Total procesados: $((success_count + error_count))"
    print_status "$YELLOW" "Log guardado en: $LOG_FILE"
    
    if [ $error_count -gt 0 ]; then
        print_status "$RED" "⚠ Revisa el log para detalles de los errores"
        exit 1
    else
        print_status "$GREEN" "✓ Todos los servidores procesados exitosamente"
        exit 0
    fi
}

# Procesar parámetros de línea de comandos
while getopts "u:p:s:w:f:h" opt; do
    case $opt in
        u) USERNAME="$OPTARG" ;;
        p) PASSWORD="$OPTARG" ;;
        s) SSH_USER="$OPTARG" ;;
        w) SSH_PASSWORD="$OPTARG" ;;
        f) SERVERS_FILE="$OPTARG" ;;
        h) usage ;;
        \?) echo "Opción inválida: -$OPTARG" >&2; usage ;;
        :) echo "La opción -$OPTARG requiere un argumento." >&2; usage ;;
    esac
done

# Validar parámetros requeridos
if [ -z "$USERNAME" ] || [ -z "$PASSWORD" ] || [ -z "$SSH_USER" ] || [ -z "$SSH_PASSWORD" ]; then
    echo "ERROR: Faltan parámetros requeridos"
    usage
fi

# Ejecutar función principal
main
