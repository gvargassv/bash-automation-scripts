#!/bin/bash

# Script de Diagnóstico de Conectividad de Red con Pruebas de Persistencia
# Autor: Administrador de Sistema
# Versión: 3.0

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Función para logging
log() {
    echo -e "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

# Función para mostrar ayuda
show_help() {
    echo "Uso: $0 -h <host_destino> -p <puerto> [opciones]"
    echo ""
    echo "Opciones obligatorias:"
    echo "  -h <host>     Host o IP destino"
    echo "  -p <puerto>   Puerto destino"
    echo ""
    echo "Opciones adicionales:"
    echo "  -t <timeout>  Timeout en segundos (default: 10)"
    echo "  -c <count>    Número de pings (default: 4)"
    echo "  -d <duration> Duración de prueba de persistencia en segundos (default: 0 = no ejecutar)"
    echo "  -i <interval> Intervalo entre verificaciones de conexión en segundos (default: 5)"
    echo "  -k            Mantener conexión activa durante la prueba de persistencia"
    echo "  -v            Modo verbose"
    echo "  -f <archivo>  Guardar resultado en archivo"
    echo "  --help        Mostrar esta ayuda"
    echo ""
    echo "Ejemplos:"
    echo "  $0 -h google.com -p 443"
    echo "  $0 -h 192.168.1.100 -p 22 -t 5 -c 10"
    echo "  $0 -h servidor.local -p 3306 -v -f diagnostico.log"
    echo "  $0 -h servidor.com -p 80 -d 300 -i 10 -k    # Prueba de 5 minutos"
}

# Función para verificar si el comando existe
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Función de prueba básica de conectividad
test_ping() {
    local host=$1
    local count=$2
    
    log "${BLUE}=== PRUEBA DE PING ===${NC}"
    
    if ping -c $count -W 3 "$host" >/dev/null 2>&1; then
        log "${GREEN}✓ PING: Host alcanzable${NC}"
        # Obtener estadísticas detalladas
        ping_stats=$(ping -c $count -W 3 "$host" 2>/dev/null | tail -n 2)
        echo "$ping_stats"
        return 0
    else
        log "${RED}✗ PING: Host no alcanzable o filtrado${NC}"
        return 1
    fi
}

# Función para resolver DNS
test_dns() {
    local host=$1
    
    log "${BLUE}=== RESOLUCIÓN DNS ===${NC}"
    
    if [[ "$host" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        log "${YELLOW}⚠ IP proporcionada, saltando resolución DNS${NC}"
        return 0
    fi
    
    if command_exists nslookup; then
        local ip=$(nslookup "$host" 2>/dev/null | grep -A1 "Name:" | tail -n1 | awk '{print $2}')
        if [[ -n "$ip" ]]; then
            log "${GREEN}✓ DNS: $host resuelve a $ip${NC}"
            return 0
        else
            log "${RED}✗ DNS: No se puede resolver $host${NC}"
            return 1
        fi
    elif command_exists dig; then
        local ip=$(dig +short "$host" 2>/dev/null | head -1)
        if [[ -n "$ip" ]]; then
            log "${GREEN}✓ DNS: $host resuelve a $ip${NC}"
            return 0
        else
            log "${RED}✗ DNS: No se puede resolver $host${NC}"
            return 1
        fi
    else
        log "${YELLOW}⚠ DNS: No hay herramientas de DNS disponibles${NC}"
        return 0
    fi
}

# Función para probar conexión TCP
test_tcp_connection() {
    local host=$1
    local port=$2
    local timeout=$3
    
    log "${BLUE}=== PRUEBA DE CONEXIÓN TCP ===${NC}"
    
    # Usando netcat si está disponible
    if command_exists nc; then
        if nc -z -w "$timeout" "$host" "$port" 2>/dev/null; then
            log "${GREEN}✓ TCP: Puerto $port abierto en $host${NC}"
            return 0
        else
            log "${RED}✗ TCP: Puerto $port cerrado/filtrado en $host${NC}"
            return 1
        fi
    # Usando telnet como alternativa
    elif command_exists telnet; then
        if timeout "$timeout" telnet "$host" "$port" </dev/null 2>/dev/null | grep -q "Connected"; then
            log "${GREEN}✓ TCP: Puerto $port abierto en $host${NC}"
            return 0
        else
            log "${RED}✗ TCP: Puerto $port cerrado/filtrado en $host${NC}"
            return 1
        fi
    # Usando bash TCP si no hay otras opciones
    else
        if timeout "$timeout" bash -c "</dev/tcp/$host/$port" 2>/dev/null; then
            log "${GREEN}✓ TCP: Puerto $port abierto en $host${NC}"
            return 0
        else
            log "${RED}✗ TCP: Puerto $port cerrado/filtrado en $host${NC}"
            return 1
        fi
    fi
}

# Función para traceroute
test_traceroute() {
    local host=$1
    local timeout=$2
    
    log "${BLUE}=== TRAZADO DE RUTA ===${NC}"
    
    if command_exists traceroute; then
        log "Trazando ruta hacia $host..."
        traceroute -w "$timeout" -m 15 "$host" 2>/dev/null | head -20
    elif command_exists tracepath; then
        log "Trazando ruta hacia $host..."
        tracepath "$host" 2>/dev/null | head -20
    else
        log "${YELLOW}⚠ TRACEROUTE: No disponible${NC}"
    fi
}

# Función para verificar MTU
test_mtu() {
    local host=$1
    
    log "${BLUE}=== PRUEBA DE MTU ===${NC}"
    
    # Probar diferentes tamaños de MTU
    local mtu_sizes=(1500 1472 1400 1200 1000 576)
    
    for size in "${mtu_sizes[@]}"; do
        if ping -c 1 -M do -s $size "$host" >/dev/null 2>&1; then
            log "${GREEN}✓ MTU: $size bytes OK${NC}"
            break
        else
            log "${YELLOW}⚠ MTU: $size bytes falla${NC}"
        fi
    done
}

# Función para verificar servicios locales
check_local_services() {
    log "${BLUE}=== VERIFICACIÓN LOCAL ===${NC}"
    
    # Verificar conectividad a internet
    if ping -c 1 -W 3 8.8.8.8 >/dev/null 2>&1; then
        log "${GREEN}✓ LOCAL: Conectividad a Internet OK${NC}"
    else
        log "${RED}✗ LOCAL: Sin conectividad a Internet${NC}"
    fi
    
    # Verificar gateway por defecto
    local gateway=$(ip route | grep default | awk '{print $3}' | head -1)
    if [[ -n "$gateway" ]]; then
        if ping -c 1 -W 3 "$gateway" >/dev/null 2>&1; then
            log "${GREEN}✓ LOCAL: Gateway ($gateway) alcanzable${NC}"
        else
            log "${RED}✗ LOCAL: Gateway ($gateway) no alcanzable${NC}"
        fi
    fi
    
    # Verificar DNS configurado
    if [[ -f /etc/resolv.conf ]]; then
        local dns_servers=$(grep nameserver /etc/resolv.conf | awk '{print $2}' | head -2)
        for dns in $dns_servers; do
            if ping -c 1 -W 3 "$dns" >/dev/null 2>&1; then
                log "${GREEN}✓ LOCAL: DNS $dns alcanzable${NC}"
            else
                log "${RED}✗ LOCAL: DNS $dns no alcanzable${NC}"
            fi
        done
    fi
}

# Función para análisis de firewall local
check_local_firewall() {
    log "${BLUE}=== VERIFICACIÓN DE FIREWALL LOCAL ===${NC}"
    
    # Verificar iptables
    if command_exists iptables; then
        local rules_count=$(iptables -L 2>/dev/null | grep -c "Chain\|target")
        if [[ $rules_count -gt 6 ]]; then
            log "${YELLOW}⚠ FIREWALL: iptables tiene reglas activas${NC}"
        else
            log "${GREEN}✓ FIREWALL: iptables sin restricciones aparentes${NC}"
        fi
    fi
    
    # Verificar firewalld
    if command_exists firewall-cmd; then
        if systemctl is-active firewalld >/dev/null 2>&1; then
            log "${YELLOW}⚠ FIREWALL: firewalld activo${NC}"
        else
            log "${GREEN}✓ FIREWALL: firewalld inactivo${NC}"
        fi
    fi
    
    # Verificar ufw
    if command_exists ufw; then
        local ufw_status=$(ufw status 2>/dev/null | grep Status | awk '{print $2}')
        if [[ "$ufw_status" == "active" ]]; then
            log "${YELLOW}⚠ FIREWALL: ufw activo${NC}"
        else
            log "${GREEN}✓ FIREWALL: ufw inactivo${NC}"
        fi
    fi
}

# Función para análisis de performance
performance_test() {
    local host=$1
    local port=$2
    local timeout=$3
    
    log "${BLUE}=== ANÁLISIS DE PERFORMANCE ===${NC}"
    
    # Test de latencia múltiple
    local total_time=0
    local successful_tests=0
    
    for i in {1..5}; do
        local start_time=$(date +%s.%N)
        if timeout "$timeout" bash -c "</dev/tcp/$host/$port" 2>/dev/null; then
            local end_time=$(date +%s.%N)
            local duration=$(echo "$end_time - $start_time" | bc 2>/dev/null || echo "0")
            total_time=$(echo "$total_time + $duration" | bc 2>/dev/null || echo "$total_time")
            successful_tests=$((successful_tests + 1))
            log "Intento $i: ${duration}s"
        else
            log "${RED}Intento $i: Fallo${NC}"
        fi
    done
    
    if [[ $successful_tests -gt 0 ]]; then
        local avg_time=$(echo "scale=3; $total_time / $successful_tests" | bc 2>/dev/null || echo "N/A")
        log "${GREEN}✓ PERFORMANCE: Promedio de conexión: ${avg_time}s${NC}"
        
        if command_exists bc && (( $(echo "$avg_time > 5" | bc -l 2>/dev/null || echo 0) )); then
            log "${YELLOW}⚠ PERFORMANCE: Latencia alta detectada${NC}"
        fi
    else
        log "${RED}✗ PERFORMANCE: Todas las conexiones fallaron${NC}"
    fi
}

# Función para prueba de persistencia de conexión
test_connection_persistence() {
    local host=$1
    local port=$2
    local duration=$3
    local interval=$4
    local keep_alive=$5
    local timeout=30
    
    log "${BLUE}=== PRUEBA DE PERSISTENCIA DE CONEXIÓN ===${NC}"
    log "Duración: ${duration}s | Intervalo de verificación: ${interval}s | Keep-alive: $([[ "$keep_alive" == "true" ]] && echo "Sí" || echo "No")"
    
    local start_time=$(date +%s)
    local end_time=$((start_time + duration))
    local checks_total=0
    local checks_success=0
    local checks_failed=0
    local connection_drops=0
    local last_status="unknown"
    local total_downtime=0
    local downtime_start=0
    local longest_connection=0
    local current_connection_start=$start_time
    local connections_established=0
    
    # Arrays para almacenar estadísticas
    local response_times=()
    local failure_times=()
    
    log "Iniciando monitoreo de conexión..."
    
    while [[ $(date +%s) -lt $end_time ]]; do
        local current_time=$(date +%s)
        local elapsed=$((current_time - start_time))
        local remaining=$((end_time - current_time))
        
        checks_total=$((checks_total + 1))
        
        # Probar conexión con medición de tiempo
        local conn_start_time=$(date +%s.%N)
        local connection_status=false
        
        if command_exists nc; then
            if timeout $timeout nc -z -w 5 "$host" "$port" 2>/dev/null; then
                connection_status=true
            fi
        else
            if timeout $timeout bash -c "</dev/tcp/$host/$port" 2>/dev/null; then
                connection_status=true
            fi
        fi
        
        local conn_end_time=$(date +%s.%N)
        local response_time="0"
        if command_exists bc; then
            response_time=$(echo "$conn_end_time - $conn_start_time" | bc 2>/dev/null || echo "0")
        fi
        
        if [[ "$connection_status" == "true" ]]; then
            checks_success=$((checks_success + 1))
            response_times+=($response_time)
            
            # Si la conexión estaba caída y ahora funciona
            if [[ "$last_status" == "failed" ]]; then
                local downtime_duration=$((current_time - downtime_start))
                total_downtime=$((total_downtime + downtime_duration))
                log "${GREEN}[$(date '+%H:%M:%S')] ✓ Conexión restaurada (estuvo caída ${downtime_duration}s)${NC}"
                connections_established=$((connections_established + 1))
                current_connection_start=$current_time
            elif [[ "$last_status" == "unknown" ]]; then
                log "${GREEN}[$(date '+%H:%M:%S')] ✓ Conexión inicial establecida${NC}"
                connections_established=1
                current_connection_start=$current_time
            fi
            
            if [[ $((elapsed % 30)) -eq 0 ]] || [[ "$last_status" != "success" ]]; then
                printf "\r${GREEN}[$(date '+%H:%M:%S')] ✓ Conexión activa | Transcurrido: ${elapsed}s | Restante: ${remaining}s | Latencia: ${response_time}s${NC}"
            fi
            
            last_status="success"
        else
            checks_failed=$((checks_failed + 1))
            failure_times+=($(date '+%H:%M:%S'))
            
            # Si la conexión funcionaba y ahora falla
            if [[ "$last_status" == "success" ]]; then
                local connection_duration=$((current_time - current_connection_start))
                if [[ $connection_duration -gt $longest_connection ]]; then
                    longest_connection=$connection_duration
                fi
                connection_drops=$((connection_drops + 1))
                downtime_start=$current_time
                echo ""
                log "${RED}[$(date '+%H:%M:%S')] ✗ Conexión perdida (duró ${connection_duration}s)${NC}"
            elif [[ "$last_status" == "unknown" ]]; then
                log "${RED}[$(date '+%H:%M:%S')] ✗ No se pudo establecer conexión inicial${NC}"
                downtime_start=$current_time
            fi
            
            printf "\r${RED}[$(date '+%H:%M:%S')] ✗ Conexión fallida | Transcurrido: ${elapsed}s | Restante: ${remaining}s${NC}"
            
            last_status="failed"
        fi
        
        sleep $interval
    done
    
    # Si la conexión estaba activa al final
    if [[ "$last_status" == "success" ]]; then
        local final_connection_duration=$(($(date +%s) - current_connection_start))
        if [[ $final_connection_duration -gt $longest_connection ]]; then
            longest_connection=$final_connection_duration
        fi
    elif [[ "$last_status" == "failed" ]]; then
        local final_downtime_duration=$(($(date +%s) - downtime_start))
        total_downtime=$((total_downtime + final_downtime_duration))
    fi
    
    echo ""
    log "${BLUE}=== RESUMEN DE PERSISTENCIA ===${NC}"
    log "Duración total de prueba: ${duration}s"
    log "Verificaciones realizadas: $checks_total"
    log "Conexiones exitosas: $checks_success"
    log "Conexiones fallidas: $checks_failed"
    
    if [[ $checks_total -gt 0 ]]; then
        local success_rate=$((checks_success * 100 / checks_total))
        log "Tasa de éxito: ${success_rate}%"
    fi
    
    log "Caídas de conexión detectadas: $connection_drops"
    log "Tiempo total de inactividad: ${total_downtime}s"
    log "Conexión más larga: ${longest_connection}s"
    
    if [[ ${#response_times[@]} -gt 0 ]]; then
        # Calcular estadísticas sin bc si no está disponible
        local min_response=${response_times[0]}
        local max_response=${response_times[0]}
        local sum_response=0
        
        for time in "${response_times[@]}"; do
            # Comparación simple sin decimales para min/max
            if command_exists bc; then
                if (( $(echo "$time < $min_response" | bc -l) )); then
                    min_response=$time
                fi
                if (( $(echo "$time > $max_response" | bc -l) )); then
                    max_response=$time
                fi
            fi
        done
        
        log "Latencia mínima: ${min_response}s"
        log "Latencia máxima: ${max_response}s"
    fi
    
    if [[ ${#failure_times[@]} -gt 0 ]]; then
        log "${RED}Horarios de fallos detectados:${NC}"
        for fail_time in "${failure_times[@]}"; do
            log "  - $fail_time"
        done
    fi
    
    # Evaluación de estabilidad
    if [[ $connection_drops -eq 0 && $checks_failed -eq 0 ]]; then
        log "${GREEN}✅ ESTABILIDAD: Conexión completamente estable${NC}"
        return 0
    elif [[ $connection_drops -le 2 && $total_downtime -lt 30 ]]; then
        log "${YELLOW}⚠️ ESTABILIDAD: Conexión mayormente estable con interrupciones menores${NC}"
        return 1
    elif [[ $connection_drops -le 5 ]]; then
        log "${YELLOW}⚠️ ESTABILIDAD: Conexión intermitente${NC}"
        return 2
    else
        log "${RED}❌ ESTABILIDAD: Conexión muy inestable${NC}"
        return 3
    fi
}

# Función para generar reporte final
generate_report() {
    local host=$1
    local port=$2
    local ping_result=$3
    local dns_result=$4
    local tcp_result=$5
    local persistence_result=$6
    
    log "${BLUE}=== RESUMEN DIAGNÓSTICO ===${NC}"
    log "Host destino: $host"
    log "Puerto: $port"
    log "Fecha: $(date)"
    echo ""
    
    # Diagnóstico básico
    if [[ $dns_result -eq 0 && $ping_result -eq 0 && $tcp_result -eq 0 ]]; then
        log "${GREEN}✅ DIAGNÓSTICO BÁSICO: Conexión completamente funcional${NC}"
    elif [[ $dns_result -ne 0 ]]; then
        log "${RED}❌ DIAGNÓSTICO BÁSICO: Problema de resolución DNS${NC}"
        log "   Recomendación: Verificar configuración DNS o usar IP directa"
    elif [[ $ping_result -ne 0 && $tcp_result -eq 0 ]]; then
        log "${YELLOW}⚠️ DIAGNÓSTICO BÁSICO: ICMP bloqueado pero TCP funcional${NC}"
        log "   Recomendación: Firewall bloquea ICMP pero permite TCP"
    elif [[ $ping_result -eq 0 && $tcp_result -ne 0 ]]; then
        log "${RED}❌ DIAGNÓSTICO BÁSICO: Host alcanzable pero puerto cerrado/filtrado${NC}"
        log "   Recomendación: Verificar servicio en puerto $port o firewall"
    else
        log "${RED}❌ DIAGNÓSTICO BÁSICO: Problema de conectividad general${NC}"
        log "   Recomendación: Verificar red, routing o firewall intermedio"
    fi
    
    # Diagnóstico de persistencia si se ejecutó
    if [[ -n "$persistence_result" ]]; then
        echo ""
        case $persistence_result in
            0)
                log "${GREEN}✅ DIAGNÓSTICO DE PERSISTENCIA: Conexión estable durante toda la prueba${NC}"
                log "   La conexión es confiable para aplicaciones de larga duración"
                ;;
            1)
                log "${YELLOW}⚠️ DIAGNÓSTICO DE PERSISTENCIA: Conexión mayormente estable${NC}"
                log "   Interrupciones menores detectadas - revisar configuración de timeout"
                ;;
            2)
                log "${YELLOW}⚠️ DIAGNÓSTICO DE PERSISTENCIA: Conexión intermitente${NC}"
                log "   Posible problema de firewall con timeout o balanceador de carga"
                ;;
            3)
                log "${RED}❌ DIAGNÓSTICO DE PERSISTENCIA: Conexión muy inestable${NC}"
                log "   Problema serio de red, firewall o configuración del servicio"
                ;;
        esac
    fi
}

# Función principal
main() {
    local host=""
    local port=""
    local timeout=10
    local ping_count=4
    local duration=0
    local interval=5
    local keep_alive=false
    local output_file=""
    local verbose=false
    
    # Parsear argumentos
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h)
                host="$2"
                shift 2
                ;;
            -p)
                port="$2"
                shift 2
                ;;
            -t)
                timeout="$2"
                shift 2
                ;;
            -c)
                ping_count="$2"
                shift 2
                ;;
            -d)
                duration="$2"
                shift 2
                ;;
            -i)
                interval="$2"
                shift 2
                ;;
            -k)
                keep_alive=true
                shift
                ;;
            -f)
                output_file="$2"
                shift 2
                ;;
            -v)
                verbose=true
                shift
                ;;
            --help)
                show_help
                exit 0
                ;;
            *)
                log "${RED}Argumento desconocido: $1${NC}"
                show_help
                exit 1
                ;;
        esac
    done
    
    # Validar argumentos obligatorios
    if [[ -z "$host" || -z "$port" ]]; then
        log "${RED}Error: Host y puerto son obligatorios${NC}"
        show_help
        exit 1
    fi
    
    # Validar que el puerto sea numérico
    if ! [[ "$port" =~ ^[0-9]+$ ]]; then
        log "${RED}Error: El puerto debe ser numérico${NC}"
        exit 1
    fi
    
    # Validar duración si se especifica
    if [[ $duration -gt 0 ]] && ! [[ "$duration" =~ ^[0-9]+$ ]]; then
        log "${RED}Error: La duración debe ser numérica${NC}"
        exit 1
    fi
    
    # Validar intervalo
    if ! [[ "$interval" =~ ^[0-9]+$ ]] || [[ $interval -lt 1 ]]; then
        log "${RED}Error: El intervalo debe ser un número positivo${NC}"
        exit 1
    fi
    
    # Redirigir output si se especifica archivo
    if [[ -n "$output_file" ]]; then
        exec > >(tee "$output_file")
        exec 2>&1
    fi
    
    # Mostrar información inicial
    log "${GREEN}Iniciando diagnóstico de conectividad...${NC}"
    log "Destino: $host:$port"
    log "Timeout: ${timeout}s"
    if [[ $duration -gt 0 ]]; then
        log "Prueba de persistencia: ${duration}s (intervalo: ${interval}s, keep-alive: $([[ "$keep_alive" == "true" ]] && echo "activado" || echo "desactivado"))"
    fi
    echo ""
    
    # Ejecutar pruebas básicas
    check_local_services
    echo ""
    
    check_local_firewall
    echo ""
    
    test_dns "$host"
    dns_result=$?
    echo ""
    
    test_ping "$host" "$ping_count"
    ping_result=$?
    echo ""
    
    test_tcp_connection "$host" "$port" "$timeout"
    tcp_result=$?
    echo ""
    
    # Ejecutar pruebas adicionales si modo verbose
    if [[ "$verbose" == "true" ]]; then
        test_traceroute "$host" "$timeout"
        echo ""
        
        test_mtu "$host"
        echo ""
        
        performance_test "$host" "$port" "$timeout"
        echo ""
    fi
    
    # Ejecutar prueba de persistencia si se especificó duración
    local persistence_result=""
    if [[ $duration -gt 0 ]]; then
        if [[ $tcp_result -eq 0 ]]; then
            test_connection_persistence "$host" "$port" "$duration" "$interval" "$keep_alive"
            persistence_result=$?
            echo ""
        else
            log "${YELLOW}⚠ Saltando prueba de persistencia porque la conexión TCP básica falló${NC}"
            echo ""
        fi
    fi
    
    # Generar reporte final
    generate_report "$host" "$port" "$ping_result" "$dns_result" "$tcp_result" "$persistence_result"
    
    if [[ -n "$output_file" ]]; then
        log "${GREEN}Resultado guardado en: $output_file${NC}"
    fi
    
    # Código de salida basado en resultados
    if [[ $tcp_result -ne 0 ]]; then
        exit 2  # Conexión básica falló
    elif [[ -n "$persistence_result" && $persistence_result -gt 2 ]]; then
        exit 3  # Conexión muy inestable
    elif [[ -n "$persistence_result" && $persistence_result -gt 0 ]]; then
        exit 1  # Conexión con problemas menores
    else
        exit 0  # Todo OK
    fi
}

# Verificar si se ejecuta directamente
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi