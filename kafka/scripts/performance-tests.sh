#!/bin/bash

# Script de tests de performance Kafka
# Usage: ./performance-tests.sh [producer|consumer|full] [topic-name]

KAFKA_SERVER=${KAFKA_SERVER:-localhost:9092}
TOPIC=${2:-perf-test-topic}
TEST_TYPE=${1:-full}

# Couleurs
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }
log_title() { echo -e "${BLUE}=== $1 ===${NC}"; }
log_test() { echo -e "${CYAN}🧪 $1${NC}"; }

show_help() {
    echo "Usage: $0 [test-type] [topic-name]"
    echo ""
    echo "Types de test:"
    echo "  producer  - Tests de performance producteur uniquement"
    echo "  consumer  - Tests de performance consommateur uniquement"
    echo "  full      - Tests complets (défaut)"
    echo "  latency   - Tests de latence"
    echo "  batch     - Tests de batch.size et linger.ms"
    echo "  compression - Tests de compression"
    echo ""
    echo "Variables d'environnement:"
    echo "  KAFKA_SERVER - Serveur Kafka (défaut: localhost:9092)"
    echo ""
    echo "Exemples:"
    echo "  $0 producer my-test-topic"
    echo "  $0 full"
    echo "  $0 batch test-batching"
}

create_test_topic() {
    local topic_name=$1
    local partitions=${2:-6}
    
    log_info "Création du topic de test: $topic_name"
    kafka-topics --create \
        --topic "$topic_name" \
        --bootstrap-server "$KAFKA_SERVER" \
        --partitions "$partitions" \
        --replication-factor 1 \
        --if-not-exists
    
    if [ $? -eq 0 ]; then
        log_info "Topic '$topic_name' prêt pour les tests"
    else
        log_error "Échec de la création du topic"
        return 1
    fi
}

test_producer_baseline() {
    log_title "Test Producteur - Configuration de base"
    log_test "Configuration: batch.size=16KB, linger.ms=0, compression=none"
    
    kafka-producer-perf-test \
        --topic "$TOPIC-baseline" \
        --num-records 100000 \
        --record-size 1000 \
        --throughput -1 \
        --producer-props \
            bootstrap.servers="$KAFKA_SERVER" \
            batch.size=16384 \
            linger.ms=0 \
            compression.type=none
}

test_producer_optimized_batching() {
    log_title "Test Producteur - Batching optimisé"
    
    # Test 1: Petit batch, pas d'attente
    log_test "Test 1: batch.size=16KB, linger.ms=0"
    kafka-producer-perf-test \
        --topic "$TOPIC-batch-small" \
        --num-records 50000 \
        --record-size 1000 \
        --throughput -1 \
        --producer-props \
            bootstrap.servers="$KAFKA_SERVER" \
            batch.size=16384 \
            linger.ms=0 \
            compression.type=snappy
    
    echo ""
    
    # Test 2: Batch moyen avec attente courte
    log_test "Test 2: batch.size=32KB, linger.ms=5"
    kafka-producer-perf-test \
        --topic "$TOPIC-batch-medium" \
        --num-records 50000 \
        --record-size 1000 \
        --throughput -1 \
        --producer-props \
            bootstrap.servers="$KAFKA_SERVER" \
            batch.size=32768 \
            linger.ms=5 \
            compression.type=snappy
    
    echo ""
    
    # Test 3: Gros batch avec attente plus longue
    log_test "Test 3: batch.size=64KB, linger.ms=50"
    kafka-producer-perf-test \
        --topic "$TOPIC-batch-large" \
        --num-records 50000 \
        --record-size 1000 \
        --throughput -1 \
        --producer-props \
            bootstrap.servers="$KAFKA_SERVER" \
            batch.size=65536 \
            linger.ms=50 \
            compression.type=snappy
    
    echo ""
    
    # Test 4: Très gros batch pour débit maximum
    log_test "Test 4: batch.size=128KB, linger.ms=100"
    kafka-producer-perf-test \
        --topic "$TOPIC-batch-xlarge" \
        --num-records 50000 \
        --record-size 1000 \
        --throughput -1 \
        --producer-props \
            bootstrap.servers="$KAFKA_SERVER" \
            batch.size=131072 \
            linger.ms=100 \
            compression.type=snappy
}

test_producer_compression() {
    log_title "Test Producteur - Compression"
    
    for compression in none gzip snappy lz4; do
        log_test "Test compression: $compression"
        kafka-producer-perf-test \
            --topic "$TOPIC-comp-$compression" \
            --num-records 30000 \
            --record-size 1000 \
            --throughput -1 \
            --producer-props \
                bootstrap.servers="$KAFKA_SERVER" \
                compression.type="$compression" \
                batch.size=65536 \
                linger.ms=10
        echo ""
    done
}

test_producer_latency() {
    log_title "Test Producteur - Latence"
    
    # Test latence ultra faible
    log_test "Latence ultra-faible: batch.size=1, linger.ms=0, acks=1"
    kafka-producer-perf-test \
        --topic "$TOPIC-latency-ultra" \
        --num-records 10000 \
        --record-size 100 \
        --throughput 1000 \
        --producer-props \
            bootstrap.servers="$KAFKA_SERVER" \
            batch.size=1 \
            linger.ms=0 \
            acks=1
    
    echo ""
    
    # Test latence équilibrée
    log_test "Latence équilibrée: batch.size=1024, linger.ms=1, acks=all"
    kafka-producer-perf-test \
        --topic "$TOPIC-latency-balanced" \
        --num-records 10000 \
        --record-size 100 \
        --throughput 5000 \
        --producer-props \
            bootstrap.servers="$KAFKA_SERVER" \
            batch.size=1024 \
            linger.ms=1 \
            acks=all \
            enable.idempotence=true
}

test_producer_idempotence() {
    log_title "Test Producteur - Idempotence"
    
    log_test "Avec idempotence activée"
    kafka-producer-perf-test \
        --topic "$TOPIC-idempotent" \
        --num-records 50000 \
        --record-size 1000 \
        --throughput -1 \
        --producer-props \
            bootstrap.servers="$KAFKA_SERVER" \
            enable.idempotence=true \
            acks=all \
            max.in.flight.requests.per.connection=5 \
            batch.size=65536 \
            linger.ms=10
}

test_consumer_performance() {
    log_title "Test Consommateur - Performance"
    
    # Test consommateur simple
    log_test "Consommateur simple - 1 thread"
    kafka-consumer-perf-test \
        --topic "$TOPIC-baseline" \
        --bootstrap-server "$KAFKA_SERVER" \
        --messages 50000 \
        --threads 1
    
    echo ""
    
    # Test consommateur multi-thread
    log_test "Consommateur multi-thread - 4 threads"
    kafka-consumer-perf-test \
        --topic "$TOPIC-batch-large" \
        --bootstrap-server "$KAFKA_SERVER" \
        --messages 50000 \
        --threads 4
    
    echo ""
    
    # Test avec groupe de consommateurs
    log_test "Avec groupe de consommateurs"
    kafka-consumer-perf-test \
        --topic "$TOPIC-batch-xlarge" \
        --bootstrap-server "$KAFKA_SERVER" \
        --messages 50000 \
        --threads 2 \
        --group performance-test-group
}

run_performance_comparison() {
    log_title "Comparaison des configurations"
    
    echo "Configuration | Records/sec | MB/sec | Latence Avg | Latence 99th"
    echo "-------------|-------------|---------|-------------|-------------"
    
    # On devrait parser les résultats des tests précédents ici
    # Pour l'instant, on fait juste un résumé
    log_info "Consultez les résultats détaillés ci-dessus pour la comparaison"
}

cleanup_test_topics() {
    log_info "Nettoyage des topics de test..."
    
    kafka-topics --list --bootstrap-server "$KAFKA_SERVER" | \
        grep "^$TOPIC" | \
        while read topic; do
            log_info "Suppression du topic: $topic"
            kafka-topics --delete --topic "$topic" --bootstrap-server "$KAFKA_SERVER"
        done
}

# Fonction principale
run_tests() {
    case "$TEST_TYPE" in
        producer)
            create_test_topic "$TOPIC-baseline"
            test_producer_baseline
            ;;
        consumer)
            test_consumer_performance
            ;;
        latency)
            create_test_topic "$TOPIC-latency-ultra" 3
            create_test_topic "$TOPIC-latency-balanced" 3
            test_producer_latency
            ;;
        batch)
            create_test_topic "$TOPIC-batch-small"
            create_test_topic "$TOPIC-batch-medium"
            create_test_topic "$TOPIC-batch-large"
            create_test_topic "$TOPIC-batch-xlarge"
            test_producer_optimized_batching
            ;;
        compression)
            for comp in none gzip snappy lz4; do
                create_test_topic "$TOPIC-comp-$comp" 3
            done
            test_producer_compression
            ;;
        full)
            log_title "Tests de performance complets"
            
            # Créer tous les topics nécessaires
            create_test_topic "$TOPIC-baseline"
            create_test_topic "$TOPIC-batch-small"
            create_test_topic "$TOPIC-batch-medium"
            create_test_topic "$TOPIC-batch-large"
            create_test_topic "$TOPIC-batch-xlarge"
            create_test_topic "$TOPIC-idempotent"
            
            for comp in none gzip snappy lz4; do
                create_test_topic "$TOPIC-comp-$comp" 3
            done
            
            # Exécuter tous les tests
            test_producer_baseline
            test_producer_optimized_batching
            test_producer_compression
            test_producer_idempotence
            test_consumer_performance
            run_performance_comparison
            ;;
        cleanup)
            cleanup_test_topics
            exit 0
            ;;
        -h|--help|help)
            show_help
            exit 0
            ;;
        *)
            log_error "Type de test inconnu: $TEST_TYPE"
            show_help
            exit 1
            ;;
    esac
}

# Point d'entrée
log_title "Tests de performance Kafka"
log_info "Type de test: $TEST_TYPE"
log_info "Topic de base: $TOPIC"
log_info "Serveur Kafka: $KAFKA_SERVER"
echo ""

run_tests

echo ""
log_title "Tests terminés"
log_info "Pour nettoyer les topics de test: $0 cleanup" 