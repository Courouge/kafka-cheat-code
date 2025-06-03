# Concepts Techniques Avancés

## Architecture Interne de Kafka

### Le Modèle de Données

#### Topics et Partitions
```
Topic: user-events
├── Partition 0: [msg0] [msg3] [msg6] [msg9]
├── Partition 1: [msg1] [msg4] [msg7] [msg10]
└── Partition 2: [msg2] [msg5] [msg8] [msg11]
```

**Caractéristiques des Partitions :**
- **Ordonnancement** : Messages ordonnés au sein d'une partition
- **Immutabilité** : Les messages ne peuvent être modifiés
- **Distribution** : Réparties sur différents brokers
- **Parallélisme** : Permettent la consommation parallèle

#### Structure des Messages
```json
{
  "offset": 12345,
  "timestamp": 1642681200000,
  "key": "user-123",
  "value": {
    "userId": "user-123",
    "action": "login",
    "timestamp": "2022-01-20T10:00:00Z"
  },
  "headers": {
    "source": "web-app",
    "version": "1.0"
  }
}
```

### Réplication et Haute Disponibilité

#### Mécanisme de Réplication
```
Topic: orders (replication-factor=3)

Broker 1 (Leader):   [msg1] [msg2] [msg3] [msg4]
Broker 2 (Follower): [msg1] [msg2] [msg3] [msg4]
Broker 3 (Follower): [msg1] [msg2] [msg3] ----
```

**Concepts Clés :**
- **Leader** : Seul broker qui gère les lectures/écritures
- **Followers** : Répliques qui synchronisent avec le leader
- **ISR (In-Sync Replicas)** : Répliques synchronisées
- **min.insync.replicas** : Nombre minimum de répliques synchrones

#### Élection de Leader
```bash
# Voir les leaders et ISR
kafka-topics.sh --describe --topic orders \
  --bootstrap-server localhost:9092

# Résultat exemple
Topic: orders  Partition: 0  Leader: 1  Replicas: 1,2,3  Isr: 1,2,3
```

## Producers - Architecture et Optimisations

### Cycle de Vie d'un Message

#### 1. Sérialisation
```java
// Exemple avec sérialisation JSON
Properties props = new Properties();
props.put("key.serializer", "org.apache.kafka.common.serialization.StringSerializer");
props.put("value.serializer", "org.apache.kafka.common.serialization.StringSerializer");

KafkaProducer<String, String> producer = new KafkaProducer<>(props);
```

#### 2. Partitioning
```java
// Stratégies de partitioning
public class CustomPartitioner implements Partitioner {
    public int partition(String topic, Object key, byte[] keyBytes, 
                        Object value, byte[] valueBytes, Cluster cluster) {
        // Logique de partitioning personnalisée
        return Math.abs(key.hashCode()) % cluster.partitionCountForTopic(topic);
    }
}
```

#### 3. Batching et Compression
```properties
# Configuration optimisée pour le throughput
batch.size=65536
linger.ms=10
compression.type=lz4
buffer.memory=67108864
```

### Garanties de Livraison

#### Levels d'Acknowledgment
```properties
# acks=0 : Pas d'attente (fire-and-forget)
acks=0

# acks=1 : Attendre l'ACK du leader uniquement
acks=1

# acks=all : Attendre l'ACK de toutes les ISR
acks=all
min.insync.replicas=2
```

#### Idempotence
```properties
# Producer idempotent (évite les doublons)
enable.idempotence=true
retries=Integer.MAX_VALUE
max.in.flight.requests.per.connection=5
```

### Optimisations Performance

#### Configuration Haute Performance
```properties
# Optimisations réseau
send.buffer.bytes=131072
receive.buffer.bytes=131072

# Optimisations mémoire
batch.size=65536
linger.ms=10
buffer.memory=134217728

# Compression
compression.type=lz4

# Parallélisme
max.in.flight.requests.per.connection=5
```

## Consumers - Architecture et Patterns

### Consumer Groups

#### Répartition des Partitions
```
Topic: orders (3 partitions)
Consumer Group: order-processors

Consumer 1: Partition 0
Consumer 2: Partition 1
Consumer 3: Partition 2
```

#### Rebalancing
```java
// Configuration du rebalancing
Properties props = new Properties();
props.put("partition.assignment.strategy", 
    "org.apache.kafka.clients.consumer.RangeAssignor");
props.put("session.timeout.ms", 30000);
props.put("heartbeat.interval.ms", 3000);
```

### Offset Management

#### Stratégies de Commit
```java
// Auto-commit (par défaut)
props.put("enable.auto.commit", true);
props.put("auto.commit.interval.ms", 5000);

// Commit manuel synchrone
consumer.commitSync();

// Commit manuel asynchrone
consumer.commitAsync((offsets, exception) -> {
    if (exception != null) {
        logger.error("Commit failed", exception);
    }
});
```

#### Gestion des Offsets
```bash
# Voir les offsets d'un consumer group
kafka-consumer-groups.sh --bootstrap-server localhost:9092 \
  --group my-group --describe

# Reset des offsets
kafka-consumer-groups.sh --bootstrap-server localhost:9092 \
  --group my-group --topic my-topic --reset-offsets \
  --to-earliest --execute
```

### Patterns de Consommation

#### At-Least-Once Processing
```java
// Pattern standard
while (true) {
    ConsumerRecords<String, String> records = consumer.poll(Duration.ofMillis(100));
    for (ConsumerRecord<String, String> record : records) {
        processRecord(record);  // Traitement idempotent requis
    }
    consumer.commitSync();
}
```

#### At-Most-Once Processing
```java
// Commit avant traitement
while (true) {
    ConsumerRecords<String, String> records = consumer.poll(Duration.ofMillis(100));
    consumer.commitSync();  // Commit d'abord
    for (ConsumerRecord<String, String> record : records) {
        processRecord(record);  // Risque de perte si erreur
    }
}
```

#### Exactly-Once Processing
```java
// Avec transactions (Kafka Streams ou manuel)
Properties props = new Properties();
props.put("isolation.level", "read_committed");
props.put("enable.auto.commit", false);

// Traitement transactionnel requis
```

## Stockage et Persistance

### Architecture de Stockage

#### Structure des Fichiers de Log
```
/tmp/kafka-logs/my-topic-0/
├── 00000000000000000000.log     # Segment actif
├── 00000000000000000000.index   # Index des offsets
├── 00000000000000000000.timeindex # Index temporel
├── 00000000000000012345.log     # Segment ancien
├── 00000000000000012345.index
└── leader-epoch-checkpoint      # Metadata d'époque
```

#### Segments et Indexation
```properties
# Configuration des segments
log.segment.bytes=1073741824      # 1GB par segment
log.segment.ms=604800000          # 7 jours max par segment
log.index.interval.bytes=4096     # Intervalles d'index
```

### Politiques de Rétention

#### Rétention par Temps
```properties
# Rétention de 7 jours
log.retention.hours=168
log.retention.minutes=10080
log.retention.ms=604800000
```

#### Rétention par Taille
```properties
# Rétention de 100GB par topic
log.retention.bytes=107374182400

# Par partition
log.segment.bytes=1073741824
```

#### Compaction des Logs
```properties
# Activation de la compaction
log.cleanup.policy=compact

# Configuration de la compaction
log.cleaner.enable=true
log.cleaner.threads=2
min.cleanable.dirty.ratio=0.5
```

## Performance et Optimisations

### Métriques Clés

#### Throughput
```bash
# Test de performance producer
kafka-producer-perf-test.sh --topic test-topic \
  --num-records 1000000 \
  --record-size 1024 \
  --throughput 10000 \
  --producer-props bootstrap.servers=localhost:9092

# Test de performance consumer
kafka-consumer-perf-test.sh --topic test-topic \
  --messages 1000000 \
  --bootstrap-server localhost:9092
```

#### Latence
```properties
# Configuration basse latence
batch.size=16384
linger.ms=0
compression.type=none
acks=1
```

### Tuning du Système

#### Optimisations OS
```bash
# Augmenter les limites de fichiers
echo "* soft nofile 65536" >> /etc/security/limits.conf
echo "* hard nofile 65536" >> /etc/security/limits.conf

# Optimisations réseau
echo 'net.core.rmem_default = 262144' >> /etc/sysctl.conf
echo 'net.core.rmem_max = 16777216' >> /etc/sysctl.conf
echo 'net.core.wmem_default = 262144' >> /etc/sysctl.conf
echo 'net.core.wmem_max = 16777216' >> /etc/sysctl.conf
```

#### JVM Tuning
```bash
# Configuration JVM pour Kafka
export KAFKA_HEAP_OPTS="-Xmx6g -Xms6g"
export KAFKA_JVM_PERFORMANCE_OPTS="-XX:+UseG1GC -XX:MaxGCPauseMillis=20 -XX:InitiatingHeapOccupancyPercent=35"
```

## ZooKeeper vs KRaft

### Architecture ZooKeeper (Legacy)
```
┌─────────────┐    ┌─────────────────┐
│   Client    │    │   ZooKeeper     │
│             │◄──►│   Ensemble      │
│             │    │  (Metadata)     │
└─────────────┘    └─────────────────┘
       │              │
       ▼              ▼
┌─────────────────────────────────────┐
│        Kafka Brokers                │
│  ┌─────────┐ ┌─────────┐ ┌─────────┐│
│  │Broker 1 │ │Broker 2 │ │Broker 3 ││
│  └─────────┘ └─────────┘ └─────────┘│
└─────────────────────────────────────┘
```

### Architecture KRaft (Moderne)
```
┌─────────────┐
│   Client    │
│             │
│             │
└─────────────┘
       │
       ▼
┌─────────────────────────────────────┐
│     Kafka Cluster (KRaft)          │
│  ┌─────────┐ ┌─────────┐ ┌─────────┐│
│  │Controller│ │Broker/  │ │Broker/  ││
│  │   +     │ │Controller│ │Controller││
│  │ Broker  │ │         │ │          ││
│  └─────────┘ └─────────┘ └─────────┘│
└─────────────────────────────────────┘
```

### Avantages KRaft
- **Simplicité** : Moins de composants à gérer
- **Performance** : Moins de latence pour les métadonnées
- **Scalabilité** : Pas de limite ZooKeeper
- **Stabilité** : Élimination du SPOF ZooKeeper

### Migration ZooKeeper → KRaft
```bash
# 1. Sauvegarde des métadonnées ZooKeeper
kafka-metadata-shell.sh --snapshot /tmp/metadata-backup

# 2. Format des données KRaft
kafka-storage.sh format --config config/kraft/server.properties \
  --cluster-id $(kafka-storage.sh random-uuid)

# 3. Démarrage en mode KRaft
kafka-server-start.sh config/kraft/server.properties
```

## Durabilité et Cohérence

### Modèle de Cohérence

#### Cohérence par Partition
- **Ordre strict** dans chaque partition
- **Pas d'ordre global** entre partitions
- **Timestamps** pour l'ordre approximatif

#### Durabilité des Écritures
```properties
# Configuration durabilité maximale
acks=all
min.insync.replicas=2
unclean.leader.election.enable=false
log.flush.interval.messages=1
```

### Transactions

#### Producteurs Transactionnels
```java
Properties props = new Properties();
props.put("transactional.id", "my-transactional-id");
props.put("enable.idempotence", true);

KafkaProducer<String, String> producer = new KafkaProducer<>(props);
producer.initTransactions();

try {
    producer.beginTransaction();
    producer.send(new ProducerRecord<>("topic1", "key", "value"));
    producer.send(new ProducerRecord<>("topic2", "key", "value"));
    producer.commitTransaction();
} catch (Exception e) {
    producer.abortTransaction();
}
```

#### Consumers Transactionnels
```java
Properties props = new Properties();
props.put("isolation.level", "read_committed");
props.put("enable.auto.commit", false);

KafkaConsumer<String, String> consumer = new KafkaConsumer<>(props);
```

---

**Sources :**
- [Apache Kafka Documentation](https://kafka.apache.org/documentation/)
- [Kafka: The Definitive Guide](https://www.confluent.io/resources/kafka-the-definitive-guide/)
- [Confluent Developer Guides](https://developer.confluent.io/) 