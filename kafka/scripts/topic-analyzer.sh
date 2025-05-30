#!/bin/bash

# Script d'analyse avancée des topics Kafka
# Usage: ./topic-analyzer.sh [command] [topic-name]

KAFKA_SERVER=${KAFKA_SERVER:-localhost:9092}
KAFKA_LOGS=${KAFKA_LOGS:-/var/kafka-logs}

# Couleurs
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
PURPLE='\033[0;35m'
NC='\033[0m'

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }
log_title() { echo -e "${BLUE}=== $1 ===${NC}"; }
log_section() { echo -e "${CYAN}📊 $1${NC}"; }
log_detail() { echo -e "${PURPLE}  ➤ $1${NC}"; }

show_help() {
    echo "Usage: $0 [command] [topic-name]"
    echo ""
    echo "Commandes:"
    echo "  segments    - Analyser les segments d'un topic"
    echo "  timestamps  - Afficher les timestamps du topic"
    echo "  offsets     - Analyser les offsets et positions"
    echo "  size        - Calculer la taille du topic"
    echo "  health      - Vérifier la santé du topic"
    echo "  full        - Analyse complète"
    echo "  compare     - Comparer plusieurs topics"
    echo ""
    echo "Variables d'environnement:"
    echo "  KAFKA_SERVER - Serveur Kafka (défaut: localhost:9092)"
    echo "  KAFKA_LOGS   - Répertoire des logs (défaut: /var/kafka-logs)"
    echo ""
    echo "Exemples:"
    echo "  $0 segments mon-topic"
    echo "  $0 full mon-topic"
    echo "  $0 timestamps mon-topic"
}

check_topic_exists() {
    local topic=$1
    if ! kafka-topics --list --bootstrap-server "$KAFKA_SERVER" | grep -q "^$topic$"; then
        log_error "Topic '$topic' n'existe pas"
        return 1
    fi
    return 0
}

analyze_segments() {
    local topic=$1
    
    if ! check_topic_exists "$topic"; then
        return 1
    fi
    
    log_title "Analyse des segments pour le topic: $topic"
    
    # Obtenir les informations du topic
    local topic_info=$(kafka-topics --describe --topic "$topic" --bootstrap-server "$KAFKA_SERVER")
    local partitions=$(echo "$topic_info" | grep -o 'PartitionCount: [0-9]*' | cut -d' ' -f2)
    
    log_section "Topic: $topic ($partitions partitions)"
    
    for ((partition=0; partition<partitions; partition++)); do
        local partition_dir="$KAFKA_LOGS/$topic-$partition"
        
        if [ -d "$partition_dir" ]; then
            log_section "Partition $partition"
            
            # Lister les fichiers de segment
            log_detail "Fichiers de segment:"
            ls -la "$partition_dir"/*.log 2>/dev/null | while read line; do
                echo "    $line"
            done
            
            # Informations sur les segments
            log_detail "Informations détaillées des segments:"
            for log_file in "$partition_dir"/*.log; do
                if [ -f "$log_file" ]; then
                    local segment_name=$(basename "$log_file")
                    local base_offset=$(echo "$segment_name" | sed 's/\.log$//')
                    
                    echo "    📄 Segment: $segment_name"
                    echo "       Base offset: $base_offset"
                    echo "       Taille: $(du -h "$log_file" | cut -f1)"
                    echo "       Modifié: $(stat -c %y "$log_file" 2>/dev/null || stat -f %Sm "$log_file")"
                    
                    # Première et dernière entrée du segment
                    if command -v kafka-dump-log >/dev/null 2>&1; then
                        local first_entry=$(kafka-dump-log --files "$log_file" --print-data-log 2>/dev/null | head -n 1)
                        if [ -n "$first_entry" ]; then
                            echo "       Premier message: $(echo "$first_entry" | grep -o 'CreateTime:[0-9]*' | head -n1)"
                        fi
                    fi
                    echo ""
                fi
            done
            
            # Index files
            log_detail "Fichiers d'index:"
            ls -la "$partition_dir"/*.index "$partition_dir"/*.timeindex 2>/dev/null | while read line; do
                echo "    $line"
            done
            
            echo ""
        else
            log_warn "Répertoire de partition non trouvé: $partition_dir"
        fi
    done
}

analyze_timestamps() {
    local topic=$1
    
    if ! check_topic_exists "$topic"; then
        return 1
    fi
    
    log_title "Analyse des timestamps pour le topic: $topic"
    
    # Obtenir les premiers et derniers offsets
    log_section "Offsets et timestamps"
    
    local earliest_offsets=$(kafka-run-class kafka.tools.GetOffsetShell \
        --broker-list "$KAFKA_SERVER" \
        --topic "$topic" \
        --time -2 2>/dev/null)
    
    local latest_offsets=$(kafka-run-class kafka.tools.GetOffsetShell \
        --broker-list "$KAFKA_SERVER" \
        --topic "$topic" \
        --time -1 2>/dev/null)
    
    echo "$earliest_offsets" | while read line; do
        if [ -n "$line" ]; then
            local partition=$(echo "$line" | cut -d: -f2)
            local earliest_offset=$(echo "$line" | cut -d: -f3)
            local latest_line=$(echo "$latest_offsets" | grep ":$partition:")
            local latest_offset=$(echo "$latest_line" | cut -d: -f3)
            
            log_detail "Partition $partition:"
            echo "    Premier offset: $earliest_offset"
            echo "    Dernier offset: $latest_offset"
            echo "    Nombre de messages: $((latest_offset - earliest_offset))"
            
            # Essayer d'obtenir le timestamp du premier message
            if [ "$earliest_offset" != "$latest_offset" ]; then
                local first_timestamp=$(kafka-console-consumer \
                    --topic "$topic" \
                    --partition "$partition" \
                    --offset "$earliest_offset" \
                    --max-messages 1 \
                    --bootstrap-server "$KAFKA_SERVER" \
                    --property print.timestamp=true \
                    --timeout-ms 5000 2>/dev/null | head -n1 | cut -d$'\t' -f1)
                
                if [ -n "$first_timestamp" ] && [ "$first_timestamp" != "null" ]; then
                    local readable_time=$(date -d "@$(echo "$first_timestamp" | sed 's/CreateTime://' | cut -c1-10)" 2>/dev/null || echo "Format non supporté")
                    echo "    Premier timestamp: $first_timestamp ($readable_time)"
                fi
            fi
            echo ""
        fi
    done
}

analyze_offsets() {
    local topic=$1
    
    if ! check_topic_exists "$topic"; then
        return 1
    fi
    
    log_title "Analyse des offsets pour le topic: $topic"
    
    # Informations de base sur les offsets
    log_section "Informations sur les offsets"
    
    kafka-run-class kafka.tools.GetOffsetShell \
        --broker-list "$KAFKA_SERVER" \
        --topic "$topic" \
        --time -2 > /tmp/earliest_offsets.txt 2>/dev/null
    
    kafka-run-class kafka.tools.GetOffsetShell \
        --broker-list "$KAFKA_SERVER" \
        --topic "$topic" \
        --time -1 > /tmp/latest_offsets.txt 2>/dev/null
    
    paste /tmp/earliest_offsets.txt /tmp/latest_offsets.txt | while read earliest latest; do
        if [ -n "$earliest" ] && [ -n "$latest" ]; then
            local partition_e=$(echo "$earliest" | cut -d: -f2)
            local offset_e=$(echo "$earliest" | cut -d: -f3)
            local offset_l=$(echo "$latest" | cut -d: -f3)
            
            log_detail "Partition $partition_e:"
            echo "    Range: $offset_e → $offset_l"
            echo "    Messages: $((offset_l - offset_e))"
        fi
    done
    
    rm -f /tmp/earliest_offsets.txt /tmp/latest_offsets.txt
    
    # Groupes de consommateurs sur ce topic
    log_section "Groupes de consommateurs actifs"
    
    kafka-consumer-groups --list --bootstrap-server "$KAFKA_SERVER" 2>/dev/null | while read group; do
        if [ -n "$group" ]; then
            local group_info=$(kafka-consumer-groups \
                --describe \
                --group "$group" \
                --bootstrap-server "$KAFKA_SERVER" 2>/dev/null | grep "$topic")
            
            if [ -n "$group_info" ]; then
                log_detail "Groupe: $group"
                echo "$group_info" | awk '{printf "    Partition %s: Offset %s, Lag %s\n", $2, $3, $5}'
                echo ""
            fi
        fi
    done
}

analyze_size() {
    local topic=$1
    
    if ! check_topic_exists "$topic"; then
        return 1
    fi
    
    log_title "Analyse de la taille pour le topic: $topic"
    
    local total_size=0
    local file_count=0
    
    log_section "Taille par partition"
    
    for dir in "$KAFKA_LOGS"/$topic-*; do
        if [ -d "$dir" ]; then
            local partition=$(basename "$dir" | sed "s/$topic-//")
            local partition_size=$(du -sh "$dir" 2>/dev/null | cut -f1)
            local partition_bytes=$(du -sb "$dir" 2>/dev/null | cut -f1)
            local files=$(find "$dir" -name "*.log" | wc -l)
            
            log_detail "Partition $partition: $partition_size ($files segments)"
            
            total_size=$((total_size + partition_bytes))
            file_count=$((file_count + files))
        fi
    done
    
    log_section "Résumé total"
    local total_size_human=$(echo "$total_size" | awk '{
        if ($1 >= 1073741824) printf "%.2f GB", $1/1073741824
        else if ($1 >= 1048576) printf "%.2f MB", $1/1048576
        else if ($1 >= 1024) printf "%.2f KB", $1/1024
        else printf "%d bytes", $1
    }')
    
    log_detail "Taille totale: $total_size_human"
    log_detail "Nombre total de segments: $file_count"
    
    if [ $file_count -gt 0 ]; then
        local avg_size=$((total_size / file_count))
        local avg_size_human=$(echo "$avg_size" | awk '{
            if ($1 >= 1048576) printf "%.2f MB", $1/1048576
            else if ($1 >= 1024) printf "%.2f KB", $1/1024
            else printf "%d bytes", $1
        }')
        log_detail "Taille moyenne par segment: $avg_size_human"
    fi
}

check_health() {
    local topic=$1
    
    if ! check_topic_exists "$topic"; then
        return 1
    fi
    
    log_title "Vérification de la santé pour le topic: $topic"
    
    # Informations de base
    log_section "Informations générales"
    kafka-topics --describe --topic "$topic" --bootstrap-server "$KAFKA_SERVER"
    
    echo ""
    
    # Partitions sous-répliquées
    log_section "Vérifications de santé"
    
    local under_replicated=$(kafka-topics --describe \
        --bootstrap-server "$KAFKA_SERVER" \
        --under-replicated-partitions \
        --topic "$topic" 2>/dev/null)
    
    if [ -n "$under_replicated" ]; then
        log_warn "Partitions sous-répliquées détectées:"
        echo "$under_replicated"
    else
        log_info "✅ Toutes les partitions sont correctement répliquées"
    fi
    
    # Partitions sans leader
    local unavailable=$(kafka-topics --describe \
        --bootstrap-server "$KAFKA_SERVER" \
        --unavailable-partitions \
        --topic "$topic" 2>/dev/null)
    
    if [ -n "$unavailable" ]; then
        log_error "Partitions indisponibles détectées:"
        echo "$unavailable"
    else
        log_info "✅ Toutes les partitions ont un leader"
    fi
    
    # Configuration du topic
    log_section "Configuration"
    kafka-configs --describe \
        --entity-type topics \
        --entity-name "$topic" \
        --bootstrap-server "$KAFKA_SERVER"
}

full_analysis() {
    local topic=$1
    
    log_title "Analyse complète du topic: $topic"
    
    analyze_segments "$topic"
    echo ""
    analyze_timestamps "$topic"
    echo ""
    analyze_offsets "$topic"
    echo ""
    analyze_size "$topic"
    echo ""
    check_health "$topic"
}

compare_topics() {
    log_title "Comparaison de topics"
    
    if [ $# -lt 2 ]; then
        log_error "Au moins 2 topics sont requis pour la comparaison"
        echo "Usage: $0 compare topic1 topic2 [topic3...]"
        return 1
    fi
    
    echo "Topic | Partitions | Messages | Taille | Groupes"
    echo "------|------------|----------|--------|--------"
    
    for topic in "$@"; do
        if check_topic_exists "$topic"; then
            local partitions=$(kafka-topics --describe --topic "$topic" --bootstrap-server "$KAFKA_SERVER" | grep -o 'PartitionCount: [0-9]*' | cut -d' ' -f2)
            
            # Compter les messages
            local total_messages=0
            local earliest=$(kafka-run-class kafka.tools.GetOffsetShell --broker-list "$KAFKA_SERVER" --topic "$topic" --time -2 2>/dev/null)
            local latest=$(kafka-run-class kafka.tools.GetOffsetShell --broker-list "$KAFKA_SERVER" --topic "$topic" --time -1 2>/dev/null)
            
            while read line; do
                if [ -n "$line" ]; then
                    local earliest_offset=$(echo "$line" | cut -d: -f3)
                    local partition=$(echo "$line" | cut -d: -f2)
                    local latest_line=$(echo "$latest" | grep ":$partition:")
                    local latest_offset=$(echo "$latest_line" | cut -d: -f3)
                    total_messages=$((total_messages + latest_offset - earliest_offset))
                fi
            done <<< "$earliest"
            
            # Taille
            local total_size=0
            for dir in "$KAFKA_LOGS"/$topic-*; do
                if [ -d "$dir" ]; then
                    local partition_bytes=$(du -sb "$dir" 2>/dev/null | cut -f1)
                    total_size=$((total_size + partition_bytes))
                fi
            done
            
            local size_human=$(echo "$total_size" | awk '{
                if ($1 >= 1073741824) printf "%.1fGB", $1/1073741824
                else if ($1 >= 1048576) printf "%.1fMB", $1/1048576
                else if ($1 >= 1024) printf "%.1fKB", $1/1024
                else printf "%dB", $1
            }')
            
            # Groupes de consommateurs
            local groups=$(kafka-consumer-groups --list --bootstrap-server "$KAFKA_SERVER" 2>/dev/null | while read group; do
                if [ -n "$group" ]; then
                    kafka-consumer-groups --describe --group "$group" --bootstrap-server "$KAFKA_SERVER" 2>/dev/null | grep -q "$topic" && echo "$group"
                fi
            done | wc -l)
            
            printf "%-15s | %-10s | %-8s | %-6s | %s\n" "$topic" "$partitions" "$total_messages" "$size_human" "$groups"
        fi
    done
}

# Main function
case "$1" in
    segments)
        if [ -z "$2" ]; then
            log_error "Nom du topic requis"
            show_help
            exit 1
        fi
        analyze_segments "$2"
        ;;
    timestamps)
        if [ -z "$2" ]; then
            log_error "Nom du topic requis"
            show_help
            exit 1
        fi
        analyze_timestamps "$2"
        ;;
    offsets)
        if [ -z "$2" ]; then
            log_error "Nom du topic requis"
            show_help
            exit 1
        fi
        analyze_offsets "$2"
        ;;
    size)
        if [ -z "$2" ]; then
            log_error "Nom du topic requis"
            show_help
            exit 1
        fi
        analyze_size "$2"
        ;;
    health)
        if [ -z "$2" ]; then
            log_error "Nom du topic requis"
            show_help
            exit 1
        fi
        check_health "$2"
        ;;
    full)
        if [ -z "$2" ]; then
            log_error "Nom du topic requis"
            show_help
            exit 1
        fi
        full_analysis "$2"
        ;;
    compare)
        shift
        compare_topics "$@"
        ;;
    -h|--help|help)
        show_help
        ;;
    *)
        log_error "Commande inconnue: $1"
        show_help
        exit 1
        ;;
esac 