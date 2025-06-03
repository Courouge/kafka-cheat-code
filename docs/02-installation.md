# Installation et Configuration

## Installation d'Apache Kafka

### Prérequis
- **Java 8+** (OpenJDK ou Oracle JDK)
- **Minimum 4GB RAM** pour environnement de développement
- **10GB d'espace disque** disponible
- **Ports réseau** : 2181 (ZooKeeper), 9092 (Kafka)

### Installation Traditionnelle (avec ZooKeeper)

#### 1. Téléchargement
```bash
# Télécharger Apache Kafka
wget https://downloads.apache.org/kafka/2.8.0/kafka_2.13-2.8.0.tgz
tar -xzf kafka_2.13-2.8.0.tgz
cd kafka_2.13-2.8.0
```

#### 2. Démarrage de ZooKeeper
```bash
# Démarrer ZooKeeper
bin/zookeeper-server-start.sh config/zookeeper.properties
```

#### 3. Démarrage de Kafka
```bash
# Démarrer Kafka Broker
bin/kafka-server-start.sh config/server.properties
```

### Installation KRaft (sans ZooKeeper)

#### 1. Configuration KRaft
```bash
# Générer un UUID cluster
KAFKA_CLUSTER_ID="$(bin/kafka-storage.sh random-uuid)"

# Formater le répertoire de logs
bin/kafka-storage.sh format -t $KAFKA_CLUSTER_ID -c config/kraft/server.properties
```

#### 2. Démarrage en mode KRaft
```bash
# Démarrer Kafka en mode KRaft
bin/kafka-server-start.sh config/kraft/server.properties
```

## Déploiement avec Docker

### Docker Compose Simple

#### docker-compose.yml (avec ZooKeeper)
```yaml
version: '3.8'
services:
  zookeeper:
    image: confluentinc/cp-zookeeper:7.4.0
    hostname: zookeeper
    container_name: zookeeper
    ports:
      - "2181:2181"
    environment:
      ZOOKEEPER_CLIENT_PORT: 2181
      ZOOKEEPER_TICK_TIME: 2000

  kafka:
    image: confluentinc/cp-kafka:7.4.0
    hostname: kafka
    container_name: kafka
    depends_on:
      - zookeeper
    ports:
      - "9092:9092"
      - "9101:9101"
    environment:
      KAFKA_BROKER_ID: 1
      KAFKA_ZOOKEEPER_CONNECT: 'zookeeper:2181'
      KAFKA_LISTENER_SECURITY_PROTOCOL_MAP: PLAINTEXT:PLAINTEXT,PLAINTEXT_HOST:PLAINTEXT
      KAFKA_ADVERTISED_LISTENERS: PLAINTEXT://kafka:29092,PLAINTEXT_HOST://localhost:9092
      KAFKA_OFFSETS_TOPIC_REPLICATION_FACTOR: 1
      KAFKA_TRANSACTION_STATE_LOG_MIN_ISR: 1
      KAFKA_TRANSACTION_STATE_LOG_REPLICATION_FACTOR: 1
      KAFKA_GROUP_INITIAL_REBALANCE_DELAY_MS: 0
      KAFKA_JMX_PORT: 9101
      KAFKA_JMX_HOSTNAME: localhost
```

#### Démarrage
```bash
docker-compose up -d
```

### Configuration Avancée avec Conduktor

#### Docker Compose avec Conduktor Console
```yaml
version: '3.8'
services:
  zookeeper:
    image: confluentinc/cp-zookeeper:7.4.0
    environment:
      ZOOKEEPER_CLIENT_PORT: 2181

  kafka:
    image: confluentinc/cp-kafka:7.4.0
    depends_on:
      - zookeeper
    ports:
      - "9092:9092"
    environment:
      KAFKA_BROKER_ID: 1
      KAFKA_ZOOKEEPER_CONNECT: zookeeper:2181
      KAFKA_ADVERTISED_LISTENERS: PLAINTEXT://localhost:9092
      KAFKA_OFFSETS_TOPIC_REPLICATION_FACTOR: 1

  postgresql:
    image: postgres:14
    environment:
      POSTGRES_DB: "conduktor-console"
      POSTGRES_USER: "conduktor"
      POSTGRES_PASSWORD: "conduktor123"

  conduktor-console:
    image: conduktor/conduktor-console:1.30.0
    depends_on:
      - postgresql
      - kafka
    ports:
      - "8080:8080"
    environment:
      CDK_DATABASE_URL: "postgresql://conduktor:conduktor123@postgresql:5432/conduktor-console"
      CDK_ADMIN_EMAIL: "admin@conduktor.io"
      CDK_ADMIN_PASSWORD: "admin"
```

*Source : [Conduktor Docker Documentation](https://docs.conduktor.io/)*

## Configuration de Base

### server.properties (Kafka Broker)
```properties
# Broker ID (unique dans le cluster)
broker.id=1

# Listeners
listeners=PLAINTEXT://localhost:9092
advertised.listeners=PLAINTEXT://localhost:9092

# Répertoires de logs
log.dirs=/tmp/kafka-logs

# Réplication par défaut
default.replication.factor=3
min.insync.replicas=2

# Partitions par défaut
num.partitions=3

# Rétention des logs
log.retention.hours=168
log.retention.bytes=1073741824
log.segment.bytes=1073741824

# ZooKeeper (si utilisé)
zookeeper.connect=localhost:2181
zookeeper.connection.timeout.ms=18000
```

### Configuration KRaft
```properties
# Mode KRaft
process.roles=broker,controller
node.id=1
controller.quorum.voters=1@localhost:9093

# Listeners KRaft
listeners=PLAINTEXT://localhost:9092,CONTROLLER://localhost:9093
inter.broker.listener.name=PLAINTEXT
advertised.listeners=PLAINTEXT://localhost:9092
controller.listener.names=CONTROLLER

# Métadonnées
metadata.log.dir=/tmp/kafka-logs/metadata
```

## Configuration de Clusters

### Cluster Multi-Brokers

#### Broker 1 (server-1.properties)
```properties
broker.id=1
listeners=PLAINTEXT://localhost:9092
log.dirs=/tmp/kafka-logs-1
```

#### Broker 2 (server-2.properties)
```properties
broker.id=2
listeners=PLAINTEXT://localhost:9093
log.dirs=/tmp/kafka-logs-2
```

#### Broker 3 (server-3.properties)
```properties
broker.id=3
listeners=PLAINTEXT://localhost:9094
log.dirs=/tmp/kafka-logs-3
```

### Démarrage du Cluster
```bash
# Démarrer les 3 brokers
bin/kafka-server-start.sh config/server-1.properties &
bin/kafka-server-start.sh config/server-2.properties &
bin/kafka-server-start.sh config/server-3.properties &
```

## Configuration de Production

### Optimisations Performance
```properties
# Taille des segments
log.segment.bytes=536870912

# Flush des données
log.flush.interval.messages=10000
log.flush.interval.ms=1000

# Compression
compression.type=lz4

# Batch size optimisé
batch.size=65536
linger.ms=10

# Mémoire buffer
buffer.memory=67108864
```

### Sécurité de Base
```properties
# SSL/TLS
listeners=SSL://localhost:9093
security.inter.broker.protocol=SSL
ssl.keystore.location=/var/ssl/private/kafka.server.keystore.jks
ssl.keystore.password=test1234
ssl.key.password=test1234
ssl.truststore.location=/var/ssl/private/kafka.server.truststore.jks
ssl.truststore.password=test1234

# SASL
security.inter.broker.protocol=SASL_SSL
sasl.mechanism.inter.broker.protocol=PLAIN
sasl.enabled.mechanisms=PLAIN
```

## Verification de l'Installation

### Tests de Base
```bash
# Créer un topic
bin/kafka-topics.sh --create --topic test-topic \
  --bootstrap-server localhost:9092 \
  --partitions 3 \
  --replication-factor 1

# Lister les topics
bin/kafka-topics.sh --list --bootstrap-server localhost:9092

# Producer de test
echo "Hello Kafka" | bin/kafka-console-producer.sh \
  --topic test-topic --bootstrap-server localhost:9092

# Consumer de test
bin/kafka-console-consumer.sh \
  --topic test-topic --from-beginning \
  --bootstrap-server localhost:9092
```

### Vérification des Métriques
```bash
# Voir les détails d'un topic
bin/kafka-topics.sh --describe --topic test-topic \
  --bootstrap-server localhost:9092

# Consumer groups
bin/kafka-consumer-groups.sh --bootstrap-server localhost:9092 --list

# État du cluster
bin/kafka-broker-api-versions.sh --bootstrap-server localhost:9092
```

## Configuration Confluent Cloud

### Quick Start Confluent Cloud
```bash
# Installation Confluent CLI
curl -sL --http1.1 https://cnfl.io/cli | sh -s -- latest

# Login et setup
confluent login
confluent environment create myenv
confluent environment use <env-id>
confluent kafka cluster create mycluster --cloud gcp --region us-central1
```

### Configuration Client
```properties
# Client properties pour Confluent Cloud
bootstrap.servers=<CLUSTER_ENDPOINT>
security.protocol=SASL_SSL
sasl.jaas.config=org.apache.kafka.common.security.plain.PlainLoginModule required username='<API_KEY>' password='<API_SECRET>';
sasl.mechanism=PLAIN
```

## Bonnes Pratiques de Configuration

### Environnement de Développement
- **1 broker** suffit
- **Réplication factor = 1**
- **Partitions = 1-3** par topic
- **Rétention courte** (24h-7j)

### Environnement de Production
- **Minimum 3 brokers** pour HA
- **Réplication factor = 3**
- **min.insync.replicas = 2**
- **Partitions optimisées** selon charge
- **Monitoring** complet activé

### Paramètres Critiques
```properties
# Durabilité
acks=all
enable.idempotence=true
retries=Integer.MAX_VALUE

# Performance
batch.size=65536
linger.ms=10
compression.type=lz4

# Reliability
min.insync.replicas=2
unclean.leader.election.enable=false
```

---

**Sources :**
- [Apache Kafka Quickstart](https://kafka.apache.org/quickstart)
- [Confluent Platform Installation](https://docs.confluent.io/platform/current/installation/index.html)
- [Conduktor Docker Setup](https://docs.conduktor.io/platform/get-started/installation/get-started/docker/) 