#!/bin/bash

# Script de démarrage rapide Kafka
# Usage: ./quick-start.sh [start|stop|restart|status]

KAFKA_HOME=${KAFKA_HOME:-/opt/kafka}
KAFKA_LOGS=${KAFKA_LOGS:-/tmp/kafka-logs}
ZK_LOGS=${ZK_LOGS:-/tmp/zookeeper}

# Couleurs pour l'affichage
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
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

check_kafka_home() {
    if [ ! -d "$KAFKA_HOME" ]; then
        log_error "KAFKA_HOME directory not found: $KAFKA_HOME"
        log_info "Please set KAFKA_HOME environment variable or install Kafka"
        exit 1
    fi
}

start_zookeeper() {
    log_info "Starting Zookeeper..."
    if pgrep -f "zookeeper" > /dev/null; then
        log_warn "Zookeeper is already running"
        return 0
    fi
    
    mkdir -p $ZK_LOGS
    $KAFKA_HOME/bin/zookeeper-server-start.sh -daemon $KAFKA_HOME/config/zookeeper.properties
    sleep 3
    
    if pgrep -f "zookeeper" > /dev/null; then
        log_info "Zookeeper started successfully"
    else
        log_error "Failed to start Zookeeper"
        return 1
    fi
}

start_kafka() {
    log_info "Starting Kafka..."
    if pgrep -f "kafka.Kafka" > /dev/null; then
        log_warn "Kafka is already running"
        return 0
    fi
    
    mkdir -p $KAFKA_LOGS
    $KAFKA_HOME/bin/kafka-server-start.sh -daemon $KAFKA_HOME/config/server.properties
    sleep 5
    
    if pgrep -f "kafka.Kafka" > /dev/null; then
        log_info "Kafka started successfully"
    else
        log_error "Failed to start Kafka"
        return 1
    fi
}

stop_kafka() {
    log_info "Stopping Kafka..."
    if pgrep -f "kafka.Kafka" > /dev/null; then
        $KAFKA_HOME/bin/kafka-server-stop.sh
        sleep 3
        log_info "Kafka stopped"
    else
        log_warn "Kafka is not running"
    fi
}

stop_zookeeper() {
    log_info "Stopping Zookeeper..."
    if pgrep -f "zookeeper" > /dev/null; then
        $KAFKA_HOME/bin/zookeeper-server-stop.sh
        sleep 3
        log_info "Zookeeper stopped"
    else
        log_warn "Zookeeper is not running"
    fi
}

status() {
    echo "=== Kafka Status ==="
    if pgrep -f "zookeeper" > /dev/null; then
        log_info "Zookeeper: Running (PID: $(pgrep -f zookeeper))"
    else
        log_error "Zookeeper: Not running"
    fi
    
    if pgrep -f "kafka.Kafka" > /dev/null; then
        log_info "Kafka: Running (PID: $(pgrep -f kafka.Kafka))"
    else
        log_error "Kafka: Not running"
    fi
    
    echo ""
    echo "=== Port Status ==="
    if netstat -tlnp 2>/dev/null | grep :2181 > /dev/null; then
        log_info "Zookeeper port 2181: Open"
    else
        log_error "Zookeeper port 2181: Closed"
    fi
    
    if netstat -tlnp 2>/dev/null | grep :9092 > /dev/null; then
        log_info "Kafka port 9092: Open"
    else
        log_error "Kafka port 9092: Closed"
    fi
}

case "$1" in
    start)
        check_kafka_home
        start_zookeeper
        start_kafka
        echo ""
        status
        ;;
    stop)
        stop_kafka
        stop_zookeeper
        ;;
    restart)
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
    *)
        echo "Usage: $0 {start|stop|restart|status}"
        echo ""
        echo "Commands:"
        echo "  start   - Start Zookeeper and Kafka"
        echo "  stop    - Stop Kafka and Zookeeper"
        echo "  restart - Restart both services"
        echo "  status  - Show status of services"
        echo ""
        echo "Environment variables:"
        echo "  KAFKA_HOME - Kafka installation directory (default: /opt/kafka)"
        echo "  KAFKA_LOGS - Kafka logs directory (default: /tmp/kafka-logs)"
        echo "  ZK_LOGS    - Zookeeper logs directory (default: /tmp/zookeeper)"
        exit 1
        ;;
esac 