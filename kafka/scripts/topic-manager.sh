#!/bin/bash

# Script de gestion des topics Kafka
# Usage: ./topic-manager.sh [create|list|describe|delete] [options]

KAFKA_SERVER=${KAFKA_SERVER:-localhost:9092}
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

show_help() {
    echo "Usage: $0 [command] [options]"
    echo ""
    echo "Commands:"
    echo "  create   - Créer un nouveau topic"
    echo "  list     - Lister tous les topics"
    echo "  describe - Décrire un topic spécifique"
    echo "  delete   - Supprimer un topic"
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
    echo "Options pour reset:"
    echo "  -t, --topic TOPIC        Nom du topic (requis)"
    echo "  -g, --group GROUP        Groupe de consommateurs (requis)"
    echo "  --to-earliest           Reset au début"
    echo "  --to-latest             Reset à la fin"
    echo "  --to-offset OFFSET      Reset à un offset spécifique"
    echo ""
    echo "Variables d'environnement:"
    echo "  KAFKA_SERVER - Serveur Kafka (défaut: localhost:9092)"
    echo ""
    echo "Exemples:"
    echo "  $0 create -t mon-topic -p 5 -r 1"
    echo "  $0 list"
    echo "  $0 describe -t mon-topic"
    echo "  $0 delete -t mon-topic"
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
                reset_type="--to-earliest"
                shift
                ;;
            --to-latest)
                reset_type="--to-latest"
                shift
                ;;
            --to-offset)
                reset_type="--to-offset"
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
        log_error "Le type de reset est requis (--to-earliest, --to-latest, ou --to-offset)"
        return 1
    fi
    
    log_info "Reset des offsets pour le groupe '$group' sur le topic '$topic'"
    
    local cmd="kafka-consumer-groups --bootstrap-server $KAFKA_SERVER --group $group --reset-offsets $reset_type --topic $topic --execute"
    
    if [ "$reset_type" = "--to-offset" ]; then
        cmd="kafka-consumer-groups --bootstrap-server $KAFKA_SERVER --group $group --reset-offsets $reset_type $offset_value --topic $topic --execute"
    fi
    
    eval $cmd
    
    if [ $? -eq 0 ]; then
        log_info "Reset des offsets effectué avec succès"
    else
        log_error "Échec du reset des offsets"
        return 1
    fi
}

# Parse command
case "$1" in
    create)
        shift
        create_topic "$@"
        ;;
    list)
        list_topics
        ;;
    describe)
        shift
        describe_topic "$@"
        ;;
    delete)
        shift
        delete_topic "$@"
        ;;
    reset)
        shift
        reset_offsets "$@"
        ;;
    -h|--help|help)
        show_help
        ;;
    *)
        log_error "Commande inconnue: $1"
        echo ""
        show_help
        exit 1
        ;;
esac 