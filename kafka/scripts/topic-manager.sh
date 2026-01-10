#!/bin/bash

# Script de gestion des topics Kafka
# Usage: ./topic-manager.sh [create|list|describe|delete] [options]

set -e

KAFKA_SERVER="${KAFKA_SERVER:-localhost:9092}"
DEFAULT_PARTITIONS=3
DEFAULT_REPLICATION=1

# Couleurs
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }
log_title() { echo -e "${BLUE}=== $1 ===${NC}"; }

# Vérifier que kafka-topics est disponible
check_kafka_tools() {
    if ! command -v kafka-topics &>/dev/null; then
        log_error "kafka-topics command not found"
        log_info "Make sure Kafka bin directory is in your PATH"
        log_info "Example: export PATH=\$PATH:/opt/kafka/bin"
        exit 1
    fi
}

# Vérifier la connexion au serveur Kafka
check_kafka_connection() {
    if ! kafka-topics --list --bootstrap-server "$KAFKA_SERVER" &>/dev/null; then
        log_error "Cannot connect to Kafka server at $KAFKA_SERVER"
        log_info "Make sure Kafka is running and accessible"
        exit 1
    fi
}

show_help() {
    echo "Usage: $0 [command] [options]"
    echo ""
    echo "Topic Commands:"
    echo "  create   - Créer un nouveau topic"
    echo "  list     - Lister tous les topics"
    echo "  describe - Décrire un topic spécifique"
    echo "  delete   - Supprimer un topic"
    echo ""
    echo "Consumer Group Commands:"
    echo "  groups   - Lister tous les groupes de consommateurs"
    echo "  group    - Décrire un groupe de consommateurs"
    echo "  reset    - Reset les offsets d'un groupe de consommateurs"
    echo ""
    echo "Options pour create:"
    echo "  -t, --topic TOPIC        Nom du topic (requis)"
    echo "  -p, --partitions NUM     Nombre de partitions (défaut: $DEFAULT_PARTITIONS)"
    echo "  -r, --replication NUM    Facteur de réplication (défaut: $DEFAULT_REPLICATION)"
    echo "  -c, --config KEY=VALUE   Configuration supplémentaire"
    echo ""
    echo "Options pour describe/delete:"
    echo "  -t, --topic TOPIC        Nom du topic (requis)"
    echo ""
    echo "Options pour group:"
    echo "  -g, --group GROUP        Nom du groupe (requis)"
    echo ""
    echo "Options pour reset:"
    echo "  -t, --topic TOPIC        Nom du topic (requis)"
    echo "  -g, --group GROUP        Groupe de consommateurs (requis)"
    echo "  --to-earliest            Reset au début"
    echo "  --to-latest              Reset à la fin"
    echo "  --to-offset OFFSET       Reset à un offset spécifique"
    echo "  --to-datetime DATETIME   Reset à une date (format: YYYY-MM-DDTHH:mm:SS.sss)"
    echo ""
    echo "Variables d'environnement:"
    echo "  KAFKA_SERVER - Serveur Kafka (défaut: localhost:9092)"
    echo ""
    echo "Exemples:"
    echo "  $0 create -t mon-topic -p 5 -r 1"
    echo "  $0 create -t mon-topic -c retention.ms=86400000"
    echo "  $0 list"
    echo "  $0 describe -t mon-topic"
    echo "  $0 delete -t mon-topic"
    echo "  $0 groups"
    echo "  $0 group -g mon-groupe"
    echo "  $0 reset -t mon-topic -g mon-groupe --to-earliest"
}

create_topic() {
    local topic=""
    local partitions=$DEFAULT_PARTITIONS
    local replication=$DEFAULT_REPLICATION
    local configs=()
    
    while [[ $# -gt 0 ]]; do
        case $1 in
            -t|--topic)
                topic="$2"
                shift 2
                ;;
            -p|--partitions)
                partitions="$2"
                shift 2
                ;;
            -r|--replication)
                replication="$2"
                shift 2
                ;;
            -c|--config)
                configs+=("--config" "$2")
                shift 2
                ;;
            *)
                log_error "Option inconnue: $1"
                return 1
                ;;
        esac
    done
    
    if [ -z "$topic" ]; then
        log_error "Le nom du topic est requis (-t)"
        return 1
    fi
    
    log_info "Création du topic '$topic' avec $partitions partitions et un facteur de réplication de $replication"
    
    kafka-topics --create \
        --topic "$topic" \
        --bootstrap-server "$KAFKA_SERVER" \
        --partitions "$partitions" \
        --replication-factor "$replication" \
        "${configs[@]}"
    
    if [ $? -eq 0 ]; then
        log_info "Topic '$topic' créé avec succès"
        kafka-topics --describe --topic "$topic" --bootstrap-server "$KAFKA_SERVER"
    else
        log_error "Échec de la création du topic '$topic'"
        return 1
    fi
}

list_topics() {
    log_title "Liste des topics"
    kafka-topics --list --bootstrap-server "$KAFKA_SERVER"
    
    echo ""
    log_title "Détails des topics"
    kafka-topics --describe --bootstrap-server "$KAFKA_SERVER"
}

describe_topic() {
    local topic=""
    
    while [[ $# -gt 0 ]]; do
        case $1 in
            -t|--topic)
                topic="$2"
                shift 2
                ;;
            *)
                log_error "Option inconnue: $1"
                return 1
                ;;
        esac
    done
    
    if [ -z "$topic" ]; then
        log_error "Le nom du topic est requis (-t)"
        return 1
    fi
    
    log_title "Description du topic '$topic'"
    kafka-topics --describe --topic "$topic" --bootstrap-server "$KAFKA_SERVER"
    
    echo ""
    log_title "Configuration du topic '$topic'"
    kafka-configs --describe --entity-type topics --entity-name "$topic" --bootstrap-server "$KAFKA_SERVER"
}

delete_topic() {
    local topic=""
    
    while [[ $# -gt 0 ]]; do
        case $1 in
            -t|--topic)
                topic="$2"
                shift 2
                ;;
            *)
                log_error "Option inconnue: $1"
                return 1
                ;;
        esac
    done
    
    if [ -z "$topic" ]; then
        log_error "Le nom du topic est requis (-t)"
        return 1
    fi
    
    log_warn "Êtes-vous sûr de vouloir supprimer le topic '$topic' ? (y/N)"
    read -r confirmation
    
    if [[ $confirmation =~ ^[Yy]$ ]]; then
        log_info "Suppression du topic '$topic'"
        kafka-topics --delete --topic "$topic" --bootstrap-server "$KAFKA_SERVER"
        
        if [ $? -eq 0 ]; then
            log_info "Topic '$topic' supprimé avec succès"
        else
            log_error "Échec de la suppression du topic '$topic'"
            return 1
        fi
    else
        log_info "Suppression annulée"
    fi
}

reset_offsets() {
    local topic=""
    local group=""
    local reset_type=""
    local offset_value=""

    while [[ $# -gt 0 ]]; do
        case $1 in
            -t|--topic)
                topic="$2"
                shift 2
                ;;
            -g|--group)
                group="$2"
                shift 2
                ;;
            --to-earliest)
                reset_type="earliest"
                shift
                ;;
            --to-latest)
                reset_type="latest"
                shift
                ;;
            --to-offset)
                reset_type="offset"
                offset_value="$2"
                shift 2
                ;;
            --to-datetime)
                reset_type="datetime"
                offset_value="$2"
                shift 2
                ;;
            *)
                log_error "Option inconnue: $1"
                return 1
                ;;
        esac
    done

    if [ -z "$topic" ] || [ -z "$group" ]; then
        log_error "Le topic (-t) et le groupe (-g) sont requis"
        return 1
    fi

    if [ -z "$reset_type" ]; then
        log_error "Le type de reset est requis (--to-earliest, --to-latest, --to-offset, ou --to-datetime)"
        return 1
    fi

    log_info "Reset des offsets pour le groupe '$group' sur le topic '$topic'"

    # Exécuter la commande sans eval
    case "$reset_type" in
        earliest)
            kafka-consumer-groups \
                --bootstrap-server "$KAFKA_SERVER" \
                --group "$group" \
                --reset-offsets \
                --to-earliest \
                --topic "$topic" \
                --execute
            ;;
        latest)
            kafka-consumer-groups \
                --bootstrap-server "$KAFKA_SERVER" \
                --group "$group" \
                --reset-offsets \
                --to-latest \
                --topic "$topic" \
                --execute
            ;;
        offset)
            if [ -z "$offset_value" ]; then
                log_error "La valeur de l'offset est requise"
                return 1
            fi
            kafka-consumer-groups \
                --bootstrap-server "$KAFKA_SERVER" \
                --group "$group" \
                --reset-offsets \
                --to-offset "$offset_value" \
                --topic "$topic" \
                --execute
            ;;
        datetime)
            if [ -z "$offset_value" ]; then
                log_error "La valeur datetime est requise (format: YYYY-MM-DDTHH:mm:SS.sss)"
                return 1
            fi
            kafka-consumer-groups \
                --bootstrap-server "$KAFKA_SERVER" \
                --group "$group" \
                --reset-offsets \
                --to-datetime "$offset_value" \
                --topic "$topic" \
                --execute
            ;;
    esac

    if [ $? -eq 0 ]; then
        log_info "Reset des offsets effectué avec succès"
    else
        log_error "Échec du reset des offsets"
        return 1
    fi
}

# Lister les groupes de consommateurs
list_groups() {
    log_title "Liste des groupes de consommateurs"
    kafka-consumer-groups --list --bootstrap-server "$KAFKA_SERVER"
}

# Décrire un groupe de consommateurs
describe_group() {
    local group=""

    while [[ $# -gt 0 ]]; do
        case $1 in
            -g|--group)
                group="$2"
                shift 2
                ;;
            *)
                log_error "Option inconnue: $1"
                return 1
                ;;
        esac
    done

    if [ -z "$group" ]; then
        log_error "Le nom du groupe est requis (-g)"
        return 1
    fi

    log_title "Description du groupe '$group'"
    kafka-consumer-groups --describe --group "$group" --bootstrap-server "$KAFKA_SERVER"
}

# Parse command
case "$1" in
    create)
        check_kafka_tools
        shift
        create_topic "$@"
        ;;
    list)
        check_kafka_tools
        list_topics
        ;;
    describe)
        check_kafka_tools
        shift
        describe_topic "$@"
        ;;
    delete)
        check_kafka_tools
        shift
        delete_topic "$@"
        ;;
    reset)
        check_kafka_tools
        shift
        reset_offsets "$@"
        ;;
    groups)
        check_kafka_tools
        list_groups
        ;;
    group)
        check_kafka_tools
        shift
        describe_group "$@"
        ;;
    -h|--help|help)
        show_help
        ;;
    "")
        show_help
        exit 0
        ;;
    *)
        log_error "Commande inconnue: $1"
        echo ""
        show_help
        exit 1
        ;;
esac 