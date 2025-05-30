# 📝 Commandes Kafka Essentielles

## 🏗️ Gestion des Topics

### Créer un topic
```bash
# Topic simple
kafka-topics --create --topic mon-topic --bootstrap-server localhost:9092

# Topic avec configuration spécifique
kafka-topics --create \
  --topic mon-topic \
  --bootstrap-server localhost:9092 \
  --partitions 3 \
  --replication-factor 1 \
  --config retention.ms=604800000

# Topic compacté (pour logs)
kafka-topics --create \
  --topic mon-topic-compacte \
  --bootstrap-server localhost:9092 \
  --config cleanup.policy=compact
```

### Lister les topics
```bash
# Tous les topics
kafka-topics --list --bootstrap-server localhost:9092

# Détails d'un topic
kafka-topics --describe --topic mon-topic --bootstrap-server localhost:9092

# Topics avec détails
kafka-topics --list --bootstrap-server localhost:9092 --describe
```

### Modifier un topic
```bash
# Ajouter des partitions
kafka-topics --alter \
  --topic mon-topic \
  --partitions 5 \
  --bootstrap-server localhost:9092

# Modifier la configuration
kafka-configs --alter \
  --entity-type topics \
  --entity-name mon-topic \
  --add-config retention.ms=86400000 \
  --bootstrap-server localhost:9092
```

### Supprimer un topic
```bash
kafka-topics --delete --topic mon-topic --bootstrap-server localhost:9092
```

### 🔬 Informations avancées sur les topics
```bash
# Afficher les segments et leurs dates de début
kafka-dump-log \
  --files /var/kafka-logs/mon-topic-0/00000000000000000000.log \
  --print-data-log | head -10

# Date du premier message d'un segment
kafka-run-class kafka.tools.GetOffsetShell \
  --broker-list localhost:9092 \
  --topic mon-topic \
  --time -2 \
  --partitions 0

# Timestamp du premier offset
kafka-consumer-groups \
  --bootstrap-server localhost:9092 \
  --group temp-group \
  --reset-offsets \
  --to-earliest \
  --topic mon-topic \
  --dry-run

# Informations détaillées sur les segments
ls -la /var/kafka-logs/mon-topic-0/ | grep -E '\.(log|index|timeindex)$'

# Taille des segments par partition
du -sh /var/kafka-logs/mon-topic-*

# Dernier timestamp du topic
kafka-run-class kafka.tools.GetOffsetShell \
  --broker-list localhost:9092 \
  --topic mon-topic \
  --time -1
```

## 📤 Producteur

### Envoyer des messages
```bash
# Producteur console simple
kafka-console-producer --topic mon-topic --bootstrap-server localhost:9092

# Avec clé-valeur
kafka-console-producer \
  --topic mon-topic \
  --bootstrap-server localhost:9092 \
  --property "key.separator=:" \
  --property "parse.key=true"

# Avec fichier de configuration
kafka-console-producer \
  --topic mon-topic \
  --bootstrap-server localhost:9092 \
  --producer.config kafka/configs/producer.properties

# Depuis un fichier
cat messages.txt | kafka-console-producer --topic mon-topic --bootstrap-server localhost:9092
```

### Tests de performance avancés
```bash
# Test de base
kafka-producer-perf-test \
  --topic mon-topic \
  --num-records 100000 \
  --record-size 1000 \
  --throughput 10000 \
  --producer-props bootstrap.servers=localhost:9092

# Test avec linger.ms optimisé (attendre plus pour batching)
kafka-producer-perf-test \
  --topic perf-topic \
  --num-records 100000 \
  --record-size 1000 \
  --throughput -1 \
  --producer-props \
    bootstrap.servers=localhost:9092 \
    linger.ms=50 \
    batch.size=65536 \
    compression.type=snappy

# Test avec différents batch.size
kafka-producer-perf-test \
  --topic perf-topic \
  --num-records 50000 \
  --record-size 1000 \
  --throughput -1 \
  --producer-props \
    bootstrap.servers=localhost:9092 \
    batch.size=16384 \
    linger.ms=5

# Comparaison des configurations
echo "=== Test batch.size=16KB, linger.ms=5 ==="
kafka-producer-perf-test \
  --topic perf-small-batch \
  --num-records 50000 \
  --record-size 1000 \
  --throughput -1 \
  --producer-props \
    bootstrap.servers=localhost:9092 \
    batch.size=16384 \
    linger.ms=5

echo "=== Test batch.size=64KB, linger.ms=50 ==="
kafka-producer-perf-test \
  --topic perf-large-batch \
  --num-records 50000 \
  --record-size 1000 \
  --throughput -1 \
  --producer-props \
    bootstrap.servers=localhost:9092 \
    batch.size=65536 \
    linger.ms=50

# Test de latence vs throughput
kafka-producer-perf-test \
  --topic latency-test \
  --num-records 10000 \
  --record-size 100 \
  --throughput 1000 \
  --producer-props \
    bootstrap.servers=localhost:9092 \
    linger.ms=0 \
    batch.size=1 \
    acks=1

# Test avec idempotence
kafka-producer-perf-test \
  --topic idempotent-test \
  --num-records 100000 \
  --record-size 1000 \
  --throughput -1 \
  --producer-props \
    bootstrap.servers=localhost:9092 \
    enable.idempotence=true \
    acks=all \
    max.in.flight.requests.per.connection=5

# Test avec différents types de compression
for compression in none gzip snappy lz4; do
  echo "=== Test compression: $compression ==="
  kafka-producer-perf-test \
    --topic compression-$compression \
    --num-records 50000 \
    --record-size 1000 \
    --throughput -1 \
    --producer-props \
      bootstrap.servers=localhost:9092 \
      compression.type=$compression \
      batch.size=65536 \
      linger.ms=10
done
```

## 📥 Consommateur

### Lire des messages
```bash
# Depuis le début
kafka-console-consumer \
  --topic mon-topic \
  --from-beginning \
  --bootstrap-server localhost:9092

# Avec groupe de consommateurs
kafka-console-consumer \
  --topic mon-topic \
  --group mon-groupe \
  --bootstrap-server localhost:9092

# Avec clé-valeur
kafka-console-consumer \
  --topic mon-topic \
  --from-beginning \
  --bootstrap-server localhost:9092 \
  --property print.key=true \
  --property key.separator=":"

# Avec fichier de configuration
kafka-console-consumer \
  --topic mon-topic \
  --bootstrap-server localhost:9092 \
  --consumer.config kafka/configs/consumer.properties

# Nombre limité de messages
kafka-console-consumer \
  --topic mon-topic \
  --max-messages 10 \
  --from-beginning \
  --bootstrap-server localhost:9092
```

### Tests de performance
```bash
# Test de performance consommateur
kafka-consumer-perf-test \
  --topic mon-topic \
  --bootstrap-server localhost:9092 \
  --messages 100000 \
  --threads 1

# Test avec plusieurs threads
kafka-consumer-perf-test \
  --topic mon-topic \
  --bootstrap-server localhost:9092 \
  --messages 100000 \
  --threads 4

# Test avec configuration optimisée
kafka-consumer-perf-test \
  --topic mon-topic \
  --bootstrap-server localhost:9092 \
  --messages 100000 \
  --threads 1 \
  --consumer.config kafka/configs/consumer.properties
```

## 🎛️ Gestion des Groupes de Consommateurs

### Lister les groupes
```bash
kafka-consumer-groups --list --bootstrap-server localhost:9092
```

### Détails d'un groupe
```bash
kafka-consumer-groups \
  --describe \
  --group mon-groupe \
  --bootstrap-server localhost:9092
```

### 👥 Informations sur les membres du groupe
```bash
# Nombre de membres dans un groupe
kafka-consumer-groups \
  --bootstrap-server localhost:9092 \
  --describe \
  --group mon-groupe \
  --members | wc -l

# Détails des membres avec leurs partitions
kafka-consumer-groups \
  --bootstrap-server localhost:9092 \
  --describe \
  --group mon-groupe \
  --members \
  --verbose

# Lister tous les membres de tous les groupes
kafka-consumer-groups \
  --bootstrap-server localhost:9092 \
  --describe \
  --all-groups \
  --members

# Compter les membres par groupe
kafka-consumer-groups \
  --bootstrap-server localhost:9092 \
  --describe \
  --all-groups \
  --members | \
  awk '/GROUP/{group=$1} /CONSUMER-ID/{count++} END{print group ": " count " membres"}'

# Script pour afficher le nombre de membres par groupe
kafka-consumer-groups --bootstrap-server localhost:9092 --list | while read group; do
  members=$(kafka-consumer-groups --bootstrap-server localhost:9092 \
    --describe --group $group --members 2>/dev/null | grep -c "CONSUMER-ID")
  if [ $members -gt 0 ]; then
    echo "$group: $members membres"
  fi
done

# État détaillé des groupes avec membres
kafka-consumer-groups \
  --bootstrap-server localhost:9092 \
  --describe \
  --all-groups \
  --state

# Groupes actifs avec leurs membres
kafka-consumer-groups \
  --bootstrap-server localhost:9092 \
  --list \
  --state | grep Stable
```

### Reset des offsets
```bash
# Reset au début
kafka-consumer-groups \
  --bootstrap-server localhost:9092 \
  --group mon-groupe \
  --reset-offsets \
  --to-earliest \
  --topic mon-topic \
  --execute

# Reset à une date
kafka-consumer-groups \
  --bootstrap-server localhost:9092 \
  --group mon-groupe \
  --reset-offsets \
  --to-datetime 2023-01-01T00:00:00.000 \
  --topic mon-topic \
  --execute

# Reset d'un offset spécifique
kafka-consumer-groups \
  --bootstrap-server localhost:9092 \
  --group mon-groupe \
  --reset-offsets \
  --to-offset 100 \
  --topic mon-topic:0 \
  --execute
```

### Supprimer un groupe
```bash
kafka-consumer-groups \
  --delete \
  --group mon-groupe \
  --bootstrap-server localhost:9092
```

## 🔐 Gestion des ACLs (Access Control Lists)

### Activer les ACLs
```bash
# Dans server.properties
authorizer.class.name=kafka.security.authorizer.AclAuthorizer
super.users=User:admin

# Redémarrer Kafka après modification
```

### Créer des ACLs
```bash
# ACL pour permettre à un utilisateur de produire sur un topic
kafka-acls --authorizer-properties zookeeper.connect=localhost:2181 \
  --add \
  --allow-principal User:alice \
  --operation Write \
  --topic mon-topic

# ACL pour permettre à un utilisateur de consommer un topic
kafka-acls --authorizer-properties zookeeper.connect=localhost:2181 \
  --add \
  --allow-principal User:bob \
  --operation Read \
  --topic mon-topic \
  --group mon-groupe

# ACL pour tous les topics (wildcard)
kafka-acls --authorizer-properties zookeeper.connect=localhost:2181 \
  --add \
  --allow-principal User:admin \
  --operation All \
  --topic "*"

# ACL pour créer des topics
kafka-acls --authorizer-properties zookeeper.connect=localhost:2181 \
  --add \
  --allow-principal User:alice \
  --operation Create \
  --topic "*"

# ACL pour décrire des topics
kafka-acls --authorizer-properties zookeeper.connect=localhost:2181 \
  --add \
  --allow-principal User:alice \
  --operation Describe \
  --topic "*"

# ACL pour gérer les groupes de consommateurs
kafka-acls --authorizer-properties zookeeper.connect=localhost:2181 \
  --add \
  --allow-principal User:bob \
  --operation Read \
  --group "*"

# ACL pour l'administration du cluster
kafka-acls --authorizer-properties zookeeper.connect=localhost:2181 \
  --add \
  --allow-principal User:admin \
  --operation ClusterAction \
  --cluster
```

### Lister les ACLs
```bash
# Toutes les ACLs
kafka-acls --authorizer-properties zookeeper.connect=localhost:2181 \
  --list

# ACLs pour un principal spécifique
kafka-acls --authorizer-properties zookeeper.connect=localhost:2181 \
  --list \
  --principal User:alice

# ACLs pour un topic spécifique
kafka-acls --authorizer-properties zookeeper.connect=localhost:2181 \
  --list \
  --topic mon-topic

# ACLs pour un groupe spécifique
kafka-acls --authorizer-properties zookeeper.connect=localhost:2181 \
  --list \
  --group mon-groupe
```

### Supprimer des ACLs
```bash
# Supprimer une ACL spécifique
kafka-acls --authorizer-properties zookeeper.connect=localhost:2181 \
  --remove \
  --allow-principal User:alice \
  --operation Write \
  --topic mon-topic

# Supprimer toutes les ACLs d'un utilisateur
kafka-acls --authorizer-properties zookeeper.connect=localhost:2181 \
  --remove \
  --principal User:alice

# Supprimer toutes les ACLs d'un topic
kafka-acls --authorizer-properties zookeeper.connect=localhost:2181 \
  --remove \
  --topic mon-topic
```

## 📊 Gestion des Quotas

### Quotas de production
```bash
# Définir un quota de production (bytes/sec)
kafka-configs --zookeeper localhost:2181 \
  --alter \
  --add-config 'producer_byte_rate=1024000' \
  --entity-type users \
  --entity-name alice

# Quota de production par client-id
kafka-configs --zookeeper localhost:2181 \
  --alter \
  --add-config 'producer_byte_rate=2048000' \
  --entity-type clients \
  --entity-name my-producer-app

# Quota combiné utilisateur + client
kafka-configs --zookeeper localhost:2181 \
  --alter \
  --add-config 'producer_byte_rate=512000' \
  --entity-type users \
  --entity-name alice \
  --entity-type clients \
  --entity-name my-app
```

### Quotas de consommation
```bash
# Définir un quota de consommation (bytes/sec)
kafka-configs --zookeeper localhost:2181 \
  --alter \
  --add-config 'consumer_byte_rate=1024000' \
  --entity-type users \
  --entity-name bob

# Quota de fetch (nombre de requêtes/sec)
kafka-configs --zookeeper localhost:2181 \
  --alter \
  --add-config 'request_rate=100' \
  --entity-type users \
  --entity-name bob
```

### Quotas par défaut
```bash
# Quota par défaut pour tous les utilisateurs
kafka-configs --zookeeper localhost:2181 \
  --alter \
  --add-config 'producer_byte_rate=1048576,consumer_byte_rate=2097152' \
  --entity-type users \
  --entity-default

# Quota par défaut pour tous les clients
kafka-configs --zookeeper localhost:2181 \
  --alter \
  --add-config 'producer_byte_rate=2097152' \
  --entity-type clients \
  --entity-default
```

### Lister et supprimer des quotas
```bash
# Lister tous les quotas
kafka-configs --zookeeper localhost:2181 \
  --describe \
  --entity-type users

kafka-configs --zookeeper localhost:2181 \
  --describe \
  --entity-type clients

# Quotas d'un utilisateur spécifique
kafka-configs --zookeeper localhost:2181 \
  --describe \
  --entity-type users \
  --entity-name alice

# Supprimer un quota
kafka-configs --zookeeper localhost:2181 \
  --alter \
  --delete-config 'producer_byte_rate' \
  --entity-type users \
  --entity-name alice
```

### Monitoring des quotas
```bash
# Métriques de quota via JMX
# kafka.server:type=ClientQuotaManager,user=alice,quota-type=producer-byte-rate
# kafka.server:type=ClientQuotaManager,user=bob,quota-type=consumer-byte-rate

# Logs de throttling
tail -f /opt/kafka/logs/server.log | grep -i quota

# Vérifier les violations de quota
kafka-run-class kafka.tools.JmxTool \
  --object-name kafka.server:type=ClientQuotaManager,* \
  --attributes throttle-time \
  --jmx-url service:jmx:rmi:///jndi/rmi://localhost:9999/jmxrmi
```

## 🎛️ Controller et Leadership

### Controller Kafka
```bash
# Identifier le controller actuel
kafka-broker-api-versions --bootstrap-server localhost:9092 | grep controller

# Via Zookeeper
zkCli.sh -server localhost:2181 <<< "get /kafka/controller"

# Information détaillée du controller
zkCli.sh -server localhost:2181 <<< "get /kafka/controller" | jq .

# Historique des controllers
zkCli.sh -server localhost:2181 <<< "get /kafka/controller_epoch"

# Forcer une élection de controller (attention!)
zkCli.sh -server localhost:2181 <<< "delete /kafka/controller"

# Surveiller les changements de controller
zkCli.sh -server localhost:2181 <<< "stat /kafka/controller true"
```

### Leadership des partitions
```bash
# Leaders de toutes les partitions
kafka-topics --describe --bootstrap-server localhost:9092

# Leader d'un topic spécifique
kafka-topics --describe --topic mon-topic --bootstrap-server localhost:9092

# Partitions sans leader (problème!)
kafka-topics --describe \
  --bootstrap-server localhost:9092 \
  --unavailable-partitions

# Forcer une élection de leader (si nécessaire)
kafka-leader-election --bootstrap-server localhost:9092 \
  --election-type preferred \
  --all-topic-partitions

# Élection pour un topic spécifique
kafka-leader-election --bootstrap-server localhost:9092 \
  --election-type preferred \
  --topic mon-topic \
  --partition 0

# Réassigner les partitions
kafka-reassign-partitions --bootstrap-server localhost:9092 \
  --reassignment-json-file reassignment.json \
  --execute
```

## 🐘 Commandes Zookeeper Essentielles

### Gestion de base de Zookeeper
```bash
# Se connecter au shell Zookeeper
kafka-run-class org.apache.zookeeper.ZooKeeperMain -server localhost:2181

# Lister les nœuds racine
zkCli.sh -server localhost:2181 <<< "ls /"

# Voir la structure Kafka dans Zookeeper
zkCli.sh -server localhost:2181 <<< "ls /kafka"

# Informations sur les brokers
zkCli.sh -server localhost:2181 <<< "ls /kafka/brokers/ids"
zkCli.sh -server localhost:2181 <<< "get /kafka/brokers/ids/0"

# Topics dans Zookeeper
zkCli.sh -server localhost:2181 <<< "ls /kafka/topics"

# Configuration d'un topic
zkCli.sh -server localhost:2181 <<< "get /kafka/topics/mon-topic"

# Groupes de consommateurs (legacy)
zkCli.sh -server localhost:2181 <<< "ls /kafka/consumers"

# Controller Kafka
zkCli.sh -server localhost:2181 <<< "get /kafka/controller"

# ISR (In-Sync Replicas) pour un topic
zkCli.sh -server localhost:2181 <<< "get /kafka/topics/mon-topic/partitions/0/state"
```

### Leader Zookeeper
```bash
# Identifier le leader Zookeeper
echo "stat" | nc localhost:2181 | grep Mode

# Information détaillée sur le statut
echo "srvr" | nc localhost:2181

# Leader dans un cluster Zookeeper
for server in zk1:2181 zk2:2181 zk3:2181; do
  echo "=== $server ==="
  echo "stat" | nc ${server/:/ } | grep Mode
done

# Configuration du quorum
echo "conf" | nc localhost:2181 | grep -E "(server\.|clientPort)"

# Ensemble Zookeeper et état des connexions
echo "cons" | nc localhost:2181

# Dumper la base de données Zookeeper
zkCli.sh -server localhost:2181 <<< "ls -R /" > zk-dump.txt
```

### Surveillance et debugging Zookeeper
```bash
# Statut de Zookeeper
echo "stat" | nc localhost:2181

# Configuration de Zookeeper
echo "conf" | nc localhost:2181

# Environnement Zookeeper
echo "envi" | nc localhost:2181

# Connexions actives
echo "cons" | nc localhost:2181

# Surveiller les logs Zookeeper
tail -f $KAFKA_HOME/logs/zookeeper.out

# Vérifier l'espace disque Zookeeper
du -sh /tmp/zookeeper/

# Nettoyer les snapshots Zookeeper (attention!)
zkCleanup.sh -n 3
```

### Zookeeper en mode sécurisé

#### Configuration SSL/TLS
```bash
# Configuration dans zookeeper.properties
secureClientPort=2182
serverCnxnFactory=org.apache.zookeeper.server.NettyServerCnxnFactory
ssl.keyStore.location=/path/to/zk-keystore.jks
ssl.keyStore.password=password
ssl.trustStore.location=/path/to/zk-truststore.jks
ssl.trustStore.password=password
ssl.clientAuth=need

# Connexion sécurisée
zkCli.sh -server localhost:2182 \
  -Dzookeeper.client.secure=true \
  -Dzookeeper.ssl.keyStore.location=/path/to/client-keystore.jks \
  -Dzookeeper.ssl.keyStore.password=password \
  -Dzookeeper.ssl.trustStore.location=/path/to/client-truststore.jks \
  -Dzookeeper.ssl.trustStore.password=password
```

#### Configuration SASL
```bash
# Configuration dans zookeeper.properties
authProvider.sasl=org.apache.zookeeper.server.auth.SASLAuthenticationProvider
requireClientAuthScheme=sasl

# Fichier JAAS (zk-jaas.conf)
Server {
    org.apache.kafka.common.security.plain.PlainLoginModule required
    username="admin"
    password="admin123"
    user_admin="admin123"
    user_alice="alice123";
};

# Démarrer Zookeeper avec SASL
export KAFKA_OPTS="-Djava.security.auth.login.config=/path/to/zk-jaas.conf"
bin/zookeeper-server-start.sh config/zookeeper.properties

# Connexion avec authentification SASL
zkCli.sh -server localhost:2181 \
  -Djava.security.auth.login.config=/path/to/client-jaas.conf

# Client JAAS configuration
Client {
    org.apache.kafka.common.security.plain.PlainLoginModule required
    username="alice"
    password="alice123";
};
```

#### ACLs Zookeeper
```bash
# Se connecter avec authentification
zkCli.sh -server localhost:2181
addauth digest alice:alice123

# Créer un nœud avec ACL
create /secure-node "data" auth:alice:alice123:cdrwa

# Lister les ACLs
getAcl /secure-node

# Modifier les ACLs
setAcl /secure-node auth:alice:alice123:cdrwa,auth:bob:bob123:r

# ACLs par défaut
create /kafka "kafka-data" world:anyone:r,auth:admin:admin123:cdrwa

# Supprimer un nœud sécurisé
delete /secure-node
```

### Commandes administratives Zookeeper
```bash
# Sauvegarder la configuration Zookeeper
zkCli.sh -server localhost:2181 <<< "ls -R /" > zookeeper-backup.txt

# Créer un nœud de test
zkCli.sh -server localhost:2181 <<< "create /test 'données de test'"

# Modifier un nœud
zkCli.sh -server localhost:2181 <<< "set /test 'nouvelles données'"

# Supprimer un nœud
zkCli.sh -server localhost:2181 <<< "delete /test"

# Surveiller les changements
zkCli.sh -server localhost:2181 <<< "stat /kafka/brokers/ids/0 true"

# Vérifier la connectivité des brokers via Zookeeper
for id in $(zkCli.sh -server localhost:2181 <<< "ls /kafka/brokers/ids" | grep -o '[0-9]*'); do
  echo "Broker $id:"
  zkCli.sh -server localhost:2181 <<< "get /kafka/brokers/ids/$id"
done
```

## ⚙️ Administration

### Informations sur le cluster
```bash
# Métadonnées du cluster
kafka-metadata-shell --snapshot /var/kafka-logs/__cluster_metadata-0/00000000000000000000.log

# Informations broker
kafka-broker-api-versions --bootstrap-server localhost:9092

# Logs de segments
kafka-dump-log --files /var/kafka-logs/mon-topic-0/00000000000000000000.log --print-data-log
```

### Gestion des configurations
```bash
# Lister les configurations
kafka-configs --describe --entity-type brokers --bootstrap-server localhost:9092

# Modifier configuration broker
kafka-configs --alter \
  --entity-type brokers \
  --entity-name 0 \
  --add-config log.retention.hours=168 \
  --bootstrap-server localhost:9092

# Configuration topic
kafka-configs --describe \
  --entity-type topics \
  --entity-name mon-topic \
  --bootstrap-server localhost:9092
```

### Monitoring des logs
```bash
# Suivre les logs en temps réel
tail -f /opt/kafka/logs/server.log

# Statistiques des topics
kafka-topics --describe \
  --bootstrap-server localhost:9092 \
  --topics-with-overrides
```

## 🔍 Monitoring et Debugging

### Vérifier la connectivité
```bash
# Test de connectivité
kafka-broker-api-versions --bootstrap-server localhost:9092

# Lister les partitions sous-répliquées
kafka-topics --describe \
  --bootstrap-server localhost:9092 \
  --under-replicated-partitions

# Lister les partitions sans leader
kafka-topics --describe \
  --bootstrap-server localhost:9092 \
  --unavailable-partitions
```

### 🚨 Monitoring Avancé des Partitions

#### Partitions sous-répliquées (Under-replicated)
```bash
# Toutes les partitions sous-répliquées
kafka-topics --describe \
  --bootstrap-server localhost:9092 \
  --under-replicated-partitions

# Partitions sous-répliquées pour un topic spécifique
kafka-topics --describe \
  --topic mon-topic \
  --bootstrap-server localhost:9092 \
  --under-replicated-partitions

# Compter les partitions sous-répliquées
kafka-topics --describe \
  --bootstrap-server localhost:9092 \
  --under-replicated-partitions | wc -l

# Détail avec ISR pour troubleshooting
kafka-topics --describe \
  --bootstrap-server localhost:9092 \
  --under-replicated-partitions | \
  awk '{print "Topic: " $2 " Partition: " $4 " Leader: " $6 " Replicas: " $8 " ISR: " $10}'
```

#### Partitions sous le minimum ISR (Under Min ISR)
```bash
# Via JMX pour identifier les partitions sous min.insync.replicas
kafka-run-class kafka.tools.JmxTool \
  --object-name kafka.cluster:type=Partition,name=UnderMinIsr,topic=*,partition=* \
  --jmx-url service:jmx:rmi:///jndi/rmi://localhost:9999/jmxrmi

# Vérifier la configuration min.insync.replicas par topic
kafka-configs --describe \
  --entity-type topics \
  --bootstrap-server localhost:9092 | \
  grep -A 2 -B 2 "min.insync.replicas"

# Script pour vérifier les topics sous min ISR
kafka-topics --list --bootstrap-server localhost:9092 | while read topic; do
  min_isr=$(kafka-configs --describe --entity-type topics --entity-name $topic \
    --bootstrap-server localhost:9092 | grep "min.insync.replicas" | cut -d'=' -f2)
  if [ -n "$min_isr" ]; then
    echo "Topic $topic: min.insync.replicas=$min_isr"
    kafka-topics --describe --topic $topic --bootstrap-server localhost:9092 | \
      awk -v min_isr="$min_isr" '/Partition:/ {
        isr_count = split($10, isr_array, ",")
        if (isr_count < min_isr) {
          print "  ⚠️ Partition " $4 ": ISR=" isr_count " < min_isr=" min_isr
        }
      }'
  fi
done

# Alerting pour partitions sous min ISR
kafka-topics --describe --bootstrap-server localhost:9092 | \
  awk '/Partition:/ {
    topic=$2; partition=$4; isr_count=split($10, a, ","); 
    print topic ":" partition " ISR_count=" isr_count
  }' | \
  while read line; do
    topic_partition=$(echo $line | cut -d' ' -f1)
    isr_count=$(echo $line | cut -d'=' -f2)
    topic=$(echo $topic_partition | cut -d':' -f1)
    
    min_isr=$(kafka-configs --describe --entity-type topics --entity-name $topic \
      --bootstrap-server localhost:9092 2>/dev/null | \
      grep "min.insync.replicas" | cut -d'=' -f2)
    
    if [ -n "$min_isr" ] && [ "$isr_count" -lt "$min_isr" ]; then
      echo "🚨 ALERT: $topic_partition has $isr_count ISR < min_isr=$min_isr"
    fi
  done
```

#### Partitions Offline
```bash
# Partitions complètement offline (sans leader)
kafka-topics --describe \
  --bootstrap-server localhost:9092 \
  --unavailable-partitions

# Partitions offline avec détails
kafka-topics --describe \
  --bootstrap-server localhost:9092 \
  --unavailable-partitions | \
  awk '{print "OFFLINE - Topic: " $2 " Partition: " $4 " Replicas: " $8}'

# Vérifier l'état des brokers pour les partitions offline
kafka-topics --describe \
  --bootstrap-server localhost:9092 \
  --unavailable-partitions | \
  while read line; do
    if [[ $line == *"Topic:"* ]]; then
      replicas=$(echo $line | awk '{print $8}' | tr ',' '\n')
      echo "Checking brokers for offline partition:"
      echo "$line"
      for broker in $replicas; do
        echo "  Broker $broker status:"
        kafka-broker-api-versions --bootstrap-server localhost:9092 \
          --timeout 5000 2>/dev/null | grep -q "broker" && \
          echo "    ✅ Broker $broker is reachable" || \
          echo "    ❌ Broker $broker is unreachable"
      done
      echo ""
    fi
  done

# Surveiller en continu les partitions offline
watch -n 30 "kafka-topics --describe --bootstrap-server localhost:9092 --unavailable-partitions | wc -l; echo 'partitions offline'"
```

#### État global des partitions
```bash
# Résumé complet de l'état des partitions
echo "=== ÉTAT DES PARTITIONS ==="
echo "Partitions sous-répliquées: $(kafka-topics --describe --bootstrap-server localhost:9092 --under-replicated-partitions | wc -l)"
echo "Partitions offline: $(kafka-topics --describe --bootstrap-server localhost:9092 --unavailable-partitions | wc -l)"
echo "Total topics: $(kafka-topics --list --bootstrap-server localhost:9092 | wc -l)"

# Rapport détaillé par topic
kafka-topics --list --bootstrap-server localhost:9092 | while read topic; do
  under_rep=$(kafka-topics --describe --topic $topic --bootstrap-server localhost:9092 --under-replicated-partitions | wc -l)
  offline=$(kafka-topics --describe --topic $topic --bootstrap-server localhost:9092 --unavailable-partitions | wc -l)
  total_partitions=$(kafka-topics --describe --topic $topic --bootstrap-server localhost:9092 | grep -c "Partition:")
  
  if [ $under_rep -gt 0 ] || [ $offline -gt 0 ]; then
    echo "⚠️  $topic: $total_partitions partitions, $under_rep sous-répliquées, $offline offline"
  fi
done
```

### 📅 Dates de création dans Zookeeper

#### Afficher la date de création d'un znode
```bash
# Date de création d'un znode (ctime)
zkCli.sh -server localhost:2181 <<< "stat /kafka/brokers/ids/0" | grep -E "(ctime|Created)"

# Date de création avec format lisible
zkCli.sh -server localhost:2181 <<< "stat /kafka/controller" | \
  awk '/ctime/ {print "Created: " strftime("%Y-%m-%d %H:%M:%S", $3/1000)}'

# Script pour afficher les dates de création de tous les brokers
zkCli.sh -server localhost:2181 <<< "ls /kafka/brokers/ids" | \
  grep -o '[0-9]*' | while read broker; do
    ctime=$(zkCli.sh -server localhost:2181 <<< "stat /kafka/brokers/ids/$broker" | \
      awk '/ctime/ {print $3}')
    if [ -n "$ctime" ]; then
      readable_date=$(date -d "@$(echo $ctime | sed 's/...$//g')" 2>/dev/null || echo "Format non supporté")
      echo "Broker $broker créé le: $readable_date"
    fi
  done

# Date de création des topics
zkCli.sh -server localhost:2181 <<< "ls /kafka/topics" | \
  grep -v "^\[" | grep -v "^$" | while read topic; do
    if [ -n "$topic" ]; then
      ctime=$(zkCli.sh -server localhost:2181 <<< "stat /kafka/topics/$topic" | \
        awk '/ctime/ {print $3}')
      if [ -n "$ctime" ]; then
        readable_date=$(date -d "@$(echo $ctime | sed 's/...$//g')" 2>/dev/null || echo "Inconnu")
        echo "Topic $topic créé le: $readable_date"
      fi
    fi
  done

# Date de dernière modification (mtime)
zkCli.sh -server localhost:2181 <<< "stat /kafka/controller" | \
  awk '/mtime/ {print "Last modified: " strftime("%Y-%m-%d %H:%M:%S", $3/1000)}'

# Historique des changements du controller
zkCli.sh -server localhost:2181 <<< "stat /kafka/controller" | \
  awk '/ctime/ {ctime=$3} /mtime/ {mtime=$3} END {
    print "Controller créé: " strftime("%Y-%m-%d %H:%M:%S", ctime/1000)
    print "Dernière élection: " strftime("%Y-%m-%d %H:%M:%S", mtime/1000)
  }'
```

### 🌐 Vérification de la Topologie par Datacenter

#### Configuration des racks/datacenters
```bash
# Vérifier la configuration des racks des brokers
kafka-broker-api-versions --bootstrap-server localhost:9092 | \
  grep -E "(rack|datacenter)"

# Via Zookeeper - information des brokers avec rack
zkCli.sh -server localhost:2181 <<< "ls /kafka/brokers/ids" | \
  grep -o '[0-9]*' | while read broker; do
    broker_info=$(zkCli.sh -server localhost:2181 <<< "get /kafka/brokers/ids/$broker")
    rack=$(echo "$broker_info" | grep -o '"rack":"[^"]*"' | cut -d'"' -f4)
    host=$(echo "$broker_info" | grep -o '"host":"[^"]*"' | cut -d'"' -f4)
    echo "Broker $broker: Host=$host, Rack=$rack"
  done

# Configuration rack dans server.properties
grep -E "^broker\.rack" /opt/kafka/config/server.properties || echo "Rack non configuré"
```

#### Vérifier la répartition par datacenter
```bash
# Analyser la répartition des répliques par rack
kafka-topics --list --bootstrap-server localhost:9092 | while read topic; do
  echo "=== Topic: $topic ==="
  kafka-topics --describe --topic $topic --bootstrap-server localhost:9092 | \
    grep "Partition:" | while read partition_line; do
    partition=$(echo $partition_line | awk '{print $2}')
    replicas=$(echo $partition_line | awk '{print $6}' | tr ',' ' ')
    
    echo "  Partition $partition:"
    for replica in $replicas; do
      broker_info=$(zkCli.sh -server localhost:2181 <<< "get /kafka/brokers/ids/$replica" 2>/dev/null)
      rack=$(echo "$broker_info" | grep -o '"rack":"[^"]*"' | cut -d'"' -f4)
      echo "    Replica broker $replica: rack=$rack"
    done
  done
  echo ""
done

# Vérifier la conformité à la policy de répartition rack
check_rack_policy() {
  local topic=$1
  echo "=== Vérification policy rack pour $topic ==="
  
  kafka-topics --describe --topic $topic --bootstrap-server localhost:9092 | \
    grep "Partition:" | while read partition_line; do
    partition=$(echo $partition_line | awk '{print $2}')
    replicas=$(echo $partition_line | awk '{print $6}' | tr ',' ' ')
    
    racks=""
    for replica in $replicas; do
      broker_info=$(zkCli.sh -server localhost:2181 <<< "get /kafka/brokers/ids/$replica" 2>/dev/null)
      rack=$(echo "$broker_info" | grep -o '"rack":"[^"]*"' | cut -d'"' -f4)
      racks="$racks $rack"
    done
    
    unique_racks=$(echo $racks | tr ' ' '\n' | sort -u | wc -l)
    total_replicas=$(echo $replicas | wc -w)
    
    if [ $unique_racks -eq $total_replicas ]; then
      echo "  ✅ Partition $partition: Répliques bien réparties ($unique_racks racks différents)"
    else
      echo "  ❌ Partition $partition: Répliques mal réparties ($unique_racks racks pour $total_replicas répliques)"
      echo "     Replicas: $replicas"
      echo "     Racks: $racks"
    fi
  done
}

# Utilisation
# check_rack_policy mon-topic

# Rapport global de conformité rack
kafka-topics --list --bootstrap-server localhost:9092 | while read topic; do
  non_compliant=$(kafka-topics --describe --topic $topic --bootstrap-server localhost:9092 | \
    grep "Partition:" | while read partition_line; do
    replicas=$(echo $partition_line | awk '{print $6}' | tr ',' ' ')
    
    racks=""
    for replica in $replicas; do
      broker_info=$(zkCli.sh -server localhost:2181 <<< "get /kafka/brokers/ids/$replica" 2>/dev/null)
      rack=$(echo "$broker_info" | grep -o '"rack":"[^"]*"' | cut -d'"' -f4)
      racks="$racks $rack"
    done
    
    unique_racks=$(echo $racks | tr ' ' '\n' | sort -u | wc -l)
    total_replicas=$(echo $replicas | wc -w)
    
    if [ $unique_racks -ne $total_replicas ]; then
      echo "NON_COMPLIANT"
    fi
  done | grep -c "NON_COMPLIANT")
  
  if [ $non_compliant -gt 0 ]; then
    echo "⚠️  Topic $topic: $non_compliant partitions non conformes à la policy rack"
  fi
done
```

#### Générer un plan de réassignation pour respecter la topologie
```bash
# Créer un fichier JSON de réassignation pour respecter les racks
generate_rack_compliant_reassignment() {
  local topic=$1
  local output_file="reassignment-$topic.json"
  
  echo "Génération du plan de réassignation pour $topic..."
  
  # Obtenir la liste des brokers par rack
  declare -A rack_brokers
  zkCli.sh -server localhost:2181 <<< "ls /kafka/brokers/ids" | \
    grep -o '[0-9]*' | while read broker; do
    broker_info=$(zkCli.sh -server localhost:2181 <<< "get /kafka/brokers/ids/$broker" 2>/dev/null)
    rack=$(echo "$broker_info" | grep -o '"rack":"[^"]*"' | cut -d'"' -f4)
    echo "$broker:$rack"
  done > /tmp/broker_racks.txt
  
  # Générer le fichier de réassignation
  echo '{"version":1,"partitions":[' > $output_file
  
  kafka-topics --describe --topic $topic --bootstrap-server localhost:9092 | \
    grep "Partition:" | while read partition_line; do
    partition=$(echo $partition_line | awk '{print $2}')
    replication_factor=$(echo $partition_line | awk '{print $6}' | tr ',' ' ' | wc -w)
    
    # Sélectionner des brokers de racks différents
    new_replicas=$(awk -F: '{racks[$2] = racks[$2] " " $1} END {
      count=0
      for (rack in racks) {
        if (count < '$replication_factor') {
          split(racks[rack], brokers, " ")
          for (i=2; i<=length(brokers); i++) {
            if (count < '$replication_factor') {
              printf "%s,", brokers[i]
              count++
            }
          }
        }
      }
    }' /tmp/broker_racks.txt | sed 's/,$//')
    
    echo '{"topic":"'$topic'","partition":'$partition',"replicas":['$new_replicas']},' >> $output_file
  done
  
  # Nettoyer le dernier comma et fermer le JSON
  sed -i '$ s/,$//' $output_file
  echo ']}' >> $output_file
  
  echo "Plan généré dans $output_file"
  rm -f /tmp/broker_racks.txt
}

# Utilisation
# generate_rack_compliant_reassignment mon-topic
```

### Analyse des offsets
```bash
# Derniers offsets
kafka-run-class kafka.tools.GetOffsetShell \
  --broker-list localhost:9092 \
  --topic mon-topic \
  --time -1

# Premiers offsets
kafka-run-class kafka.tools.GetOffsetShell \
  --broker-list localhost:9092 \
  --topic mon-topic \
  --time -2
```

### Vérification des groupes
```bash
# Groupes actifs
kafka-consumer-groups \
  --bootstrap-server localhost:9092 \
  --list \
  --state

# Lag des consommateurs
kafka-consumer-groups \
  --bootstrap-server localhost:9092 \
  --describe \
  --group mon-groupe \
  --members --verbose
```

## 🔒 Sécurité (SASL/SSL)

### Avec SASL_PLAIN
```bash
# Producteur avec authentification
kafka-console-producer \
  --topic mon-topic \
  --bootstrap-server localhost:9093 \
  --producer.config kafka/admin.plain.properties

# Consommateur avec authentification
kafka-console-consumer \
  --topic mon-topic \
  --bootstrap-server localhost:9093 \
  --consumer.config kafka/admin.plain.properties
```

### Avec SASL_SCRAM
```bash
# Utiliser la configuration SCRAM
kafka-console-producer \
  --topic mon-topic \
  --bootstrap-server localhost:9093 \
  --producer.config kafka/admin.scram.properties
```

### Gestion des utilisateurs SCRAM
```bash
# Créer un utilisateur
kafka-configs --zookeeper localhost:2181 \
  --alter \
  --add-config 'SCRAM-SHA-256=[password=secret],SCRAM-SHA-512=[password=secret]' \
  --entity-type users \
  --entity-name alice

# Lister les utilisateurs
kafka-configs --zookeeper localhost:2181 \
  --describe \
  --entity-type users
```

## 🚨 Troubleshooting

### Problèmes courants
```bash
# Vérifier si Kafka est démarré
jps | grep Kafka

# Vérifier les ports
netstat -tlnp | grep :9092

# Espace disque
df -h /var/kafka-logs

# Processus Kafka
ps aux | grep kafka

# Logs d'erreur
grep ERROR /opt/kafka/logs/server.log | tail -20
```

### Nettoyage
```bash
# Supprimer tous les topics
kafka-topics --list --bootstrap-server localhost:9092 | \
  xargs -I {} kafka-topics --delete --topic {} --bootstrap-server localhost:9092

# Nettoyer les logs
rm -rf /tmp/kafka-logs/*
rm -rf /tmp/zookeeper/*
```

### Redémarrage propre
```bash
# Arrêter Kafka
kafka-server-stop.sh

# Arrêter Zookeeper
zookeeper-server-stop.sh

# Redémarrer Zookeeper
zookeeper-server-start.sh config/zookeeper.properties &

# Redémarrer Kafka
kafka-server-start.sh config/server.properties &
``` 