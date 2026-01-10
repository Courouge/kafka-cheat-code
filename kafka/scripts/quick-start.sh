#!/bin/bash

# Script de démarrage rapide Kafka
# Usage: ./quick-start.sh [start|stop|restart|status]

set -e

KAFKA_HOME="${KAFKA_HOME:-/opt/kafka}"
KAFKA_LOGS="${KAFKA_LOGS:-/tmp/kafka-logs}"
ZK_LOGS="${ZK_LOGS:-/tmp/zookeeper}"

# Couleurs pour l'affichage
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_title() {
    echo -e "${BLUE}=== $1 ===${NC}"
}

# Vérifier les dépendances
check_dependencies() {
    local missing=()

    if ! command -v java &>/dev/null; then
        missing+=("java")
    fi

    if [ ${#missing[@]} -gt 0 ]; then
        log_error "Dépendances manquantes: ${missing[*]}"
        log_info "Veuillez installer les dépendances requises"
        exit 1
    fi
}

check_kafka_home() {
    if [ ! -d "$KAFKA_HOME" ]; then
        log_error "KAFKA_HOME directory not found: $KAFKA_HOME"
        log_info "Please set KAFKA_HOME environment variable or install Kafka"
        exit 1
    fi

    if [ ! -f "$KAFKA_HOME/bin/kafka-server-start.sh" ]; then
        log_error "Kafka scripts not found in $KAFKA_HOME/bin"
        exit 1
    fi
}

start_zookeeper() {
    log_info "Starting Zookeeper..."
    if pgrep -f "org.apache.zookeeper" > /dev/null; then
        log_warn "Zookeeper is already running"
        return 0
    fi

    mkdir -p "$ZK_LOGS"
    "$KAFKA_HOME/bin/zookeeper-server-start.sh" -daemon "$KAFKA_HOME/config/zookeeper.properties"

    # Attendre le démarrage avec retry
    local retries=10
    while [ $retries -gt 0 ]; do
        if pgrep -f "org.apache.zookeeper" > /dev/null; then
            log_info "Zookeeper started successfully"
            return 0
        fi
        sleep 1
        retries=$((retries - 1))
    done

    log_error "Failed to start Zookeeper"
    return 1
}

start_kafka() {
    log_info "Starting Kafka..."
    if pgrep -f "kafka.Kafka" > /dev/null; then
        log_warn "Kafka is already running"
        return 0
    fi

    mkdir -p "$KAFKA_LOGS"
    "$KAFKA_HOME/bin/kafka-server-start.sh" -daemon "$KAFKA_HOME/config/server.properties"

    # Attendre le démarrage avec retry
    local retries=15
    while [ $retries -gt 0 ]; do
        if pgrep -f "kafka.Kafka" > /dev/null; then
            log_info "Kafka started successfully"
            return 0
        fi
        sleep 1
        retries=$((retries - 1))
    done

    log_error "Failed to start Kafka"
    return 1
}

stop_kafka() {
    log_info "Stopping Kafka..."
    if pgrep -f "kafka.Kafka" > /dev/null; then
        "$KAFKA_HOME/bin/kafka-server-stop.sh" 2>/dev/null || true

        # Attendre l'arrêt
        local retries=10
        while [ $retries -gt 0 ]; do
            if ! pgrep -f "kafka.Kafka" > /dev/null; then
                log_info "Kafka stopped"
                return 0
            fi
            sleep 1
            retries=$((retries - 1))
        done

        # Force kill si nécessaire
        log_warn "Forcing Kafka shutdown..."
        pkill -9 -f "kafka.Kafka" 2>/dev/null || true
        log_info "Kafka stopped (forced)"
    else
        log_warn "Kafka is not running"
    fi
}

stop_zookeeper() {
    log_info "Stopping Zookeeper..."
    if pgrep -f "org.apache.zookeeper" > /dev/null; then
        "$KAFKA_HOME/bin/zookeeper-server-stop.sh" 2>/dev/null || true

        # Attendre l'arrêt
        local retries=10
        while [ $retries -gt 0 ]; do
            if ! pgrep -f "org.apache.zookeeper" > /dev/null; then
                log_info "Zookeeper stopped"
                return 0
            fi
            sleep 1
            retries=$((retries - 1))
        done

        # Force kill si nécessaire
        log_warn "Forcing Zookeeper shutdown..."
        pkill -9 -f "org.apache.zookeeper" 2>/dev/null || true
        log_info "Zookeeper stopped (forced)"
    else
        log_warn "Zookeeper is not running"
    fi
}

check_port() {
    local port=$1
    # Essayer ss d'abord, puis netstat, puis lsof
    if command -v ss &>/dev/null; then
        ss -tlnp 2>/dev/null | grep -q ":$port " && return 0
    elif command -v netstat &>/dev/null; then
        netstat -tlnp 2>/dev/null | grep -q ":$port " && return 0
    elif command -v lsof &>/dev/null; then
        lsof -i ":$port" -sTCP:LISTEN &>/dev/null && return 0
    fi
    return 1
}

status() {
    log_title "Kafka Status"

    echo ""
    echo "Process Status:"
    if pgrep -f "org.apache.zookeeper" > /dev/null; then
        local zk_pid=$(pgrep -f "org.apache.zookeeper" | head -1)
        log_info "Zookeeper: Running (PID: $zk_pid)"
    else
        log_error "Zookeeper: Not running"
    fi

    if pgrep -f "kafka.Kafka" > /dev/null; then
        local kafka_pid=$(pgrep -f "kafka.Kafka" | head -1)
        log_info "Kafka: Running (PID: $kafka_pid)"
    else
        log_error "Kafka: Not running"
    fi

    echo ""
    echo "Port Status:"
    if check_port 2181; then
        log_info "Zookeeper port 2181: Open"
    else
        log_error "Zookeeper port 2181: Closed"
    fi

    if check_port 9092; then
        log_info "Kafka port 9092: Open"
    else
        log_error "Kafka port 9092: Closed"
    fi

    echo ""
    echo "Directories:"
    log_info "KAFKA_HOME: $KAFKA_HOME"
    log_info "KAFKA_LOGS: $KAFKA_LOGS"
    log_info "ZK_LOGS: $ZK_LOGS"
}

show_help() {
    echo "Usage: $0 {start|stop|restart|status|logs}"
    echo ""
    echo "Commands:"
    echo "  start   - Start Zookeeper and Kafka"
    echo "  stop    - Stop Kafka and Zookeeper"
    echo "  restart - Restart both services"
    echo "  status  - Show status of services"
    echo "  logs    - Show Kafka logs (tail -f)"
    echo ""
    echo "Environment variables:"
    echo "  KAFKA_HOME - Kafka installation directory (default: /opt/kafka)"
    echo "  KAFKA_LOGS - Kafka logs directory (default: /tmp/kafka-logs)"
    echo "  ZK_LOGS    - Zookeeper logs directory (default: /tmp/zookeeper)"
    echo ""
    echo "Examples:"
    echo "  $0 start"
    echo "  KAFKA_HOME=/usr/local/kafka $0 start"
    echo "  $0 status"
}

show_logs() {
    local log_file="$KAFKA_HOME/logs/server.log"
    if [ -f "$log_file" ]; then
        log_info "Showing Kafka logs (Ctrl+C to stop)..."
        tail -f "$log_file"
    else
        log_error "Log file not found: $log_file"
        log_info "Available log files:"
        ls -la "$KAFKA_HOME/logs/" 2>/dev/null || echo "  (logs directory not found)"
    fi
}

case "$1" in
    start)
        check_dependencies
        check_kafka_home
        start_zookeeper
        start_kafka
        echo ""
        status
        ;;
    stop)
        check_kafka_home
        stop_kafka
        stop_zookeeper
        ;;
    restart)
        check_dependencies
        check_kafka_home
        stop_kafka
        stop_zookeeper
        sleep 2
        start_zookeeper
        start_kafka
        echo ""
        status
        ;;
    status)
        status
        ;;
    logs)
        check_kafka_home
        show_logs
        ;;
    -h|--help|help)
        show_help
        exit 0
        ;;
    *)
        if [ -n "$1" ]; then
            log_error "Unknown command: $1"
            echo ""
        fi
        show_help
        exit 1
        ;;
esac 