# 🚀 Kafka Cheat Code

Un guide pratique et simplifié pour toutes les commandes Kafka essentielles avec des configurations prêtes à l'emploi.

## 📋 Table des matières

- [Installation rapide](#installation-rapide)
- [Configurations](#configurations)
- [Scripts utiles](#scripts-utiles)
- [Exemples de code](#exemples-de-code)
- [Tests de performance](#tests-de-performance)
- [Analyse avancée](#analyse-avancée)
- [Gestion des consumer groups](#gestion-des-consumer-groups)
- [Commandes Zookeeper](#commandes-zookeeper)
- [Monitoring](#monitoring)
- [Sécurité](#sécurité)
- [Troubleshooting](#troubleshooting)

## ⚡ Installation rapide

```bash
# Télécharger Kafka
wget https://downloads.apache.org/kafka/2.13-3.6.0/kafka_2.13-3.6.0.tgz
tar -xzf kafka_2.13-3.6.0.tgz
cd kafka_2.13-3.6.0

# Démarrer Zookeeper
bin/zookeeper-server-start.sh config/zookeeper.properties

# Démarrer Kafka
bin/kafka-server-start.sh config/server.properties
```

## 📁 Structure du projet

```
kafka/
├── configs/           # Configurations simplifiées
│   ├── local.properties      # Configuration locale
│   ├── producer.properties   # Configuration producteur
│   ├── consumer.properties   # Configuration consommateur
│   ├── admin.plain.properties # SASL PLAIN
│   └── admin.scram.properties # SASL SCRAM
├── scripts/          # Scripts utiles
│   ├── quick-start.sh        # Démarrage/arrêt Kafka
│   ├── topic-manager.sh      # Gestion des topics
│   ├── performance-tests.sh  # Tests de performance
│   └── topic-analyzer.sh     # Analyse avancée des topics
└── examples/         # Exemples d'utilisation
    ├── producer-example.py   # Producteur Python
    └── consumer-example.py   # Consommateur Python
```

## 🎯 Objectif

Ce projet vise à simplifier l'utilisation d'Apache Kafka en fournissant :
- Des configurations prêtes à l'emploi
- Toutes les commandes essentielles avec des exemples
- Des scripts automatisés pour les tâches courantes
- Une documentation claire et accessible
- Des outils d'analyse avancée

## ⚙️ Configurations

### Configuration locale (développement)
```bash
# Utiliser la configuration locale simplifiée
kafka-console-producer --topic test --bootstrap-server localhost:9092 \
  --producer.config kafka/configs/local.properties
```

### Configuration producteur optimisée
- Fiabilité maximale (`acks=all`, `enable.idempotence=true`)
- Performance avec compression (`compression.type=snappy`)
- Retry automatique avec `retries=2147483647`

### Configuration consommateur optimisée
- Groupes de consommateurs configurés
- Auto-commit intelligent
- Gestion des timeouts et heartbeats

## 🚀 Scripts utiles

### Script de démarrage rapide
```bash
# Démarrer Kafka et Zookeeper
./kafka/scripts/quick-start.sh start

# Vérifier le statut
./kafka/scripts/quick-start.sh status

# Arrêter les services
./kafka/scripts/quick-start.sh stop

# Redémarrer
./kafka/scripts/quick-start.sh restart
```

### Gestionnaire de topics
```bash
# Créer un topic
./kafka/scripts/topic-manager.sh create -t mon-topic -p 3 -r 1

# Lister tous les topics
./kafka/scripts/topic-manager.sh list

# Décrire un topic
./kafka/scripts/topic-manager.sh describe -t mon-topic

# Supprimer un topic
./kafka/scripts/topic-manager.sh delete -t mon-topic

# Reset des offsets
./kafka/scripts/topic-manager.sh reset -t mon-topic -g mon-groupe --to-earliest
```

## 🧪 Tests de performance

### Script de tests automatisés
```bash
# Tests complets de performance
./kafka/scripts/performance-tests.sh full

# Tests de batching (linger.ms et batch.size)
./kafka/scripts/performance-tests.sh batch

# Tests de compression
./kafka/scripts/performance-tests.sh compression

# Tests de latence
./kafka/scripts/performance-tests.sh latency

# Nettoyer les topics de test
./kafka/scripts/performance-tests.sh cleanup
```

### Optimisation des paramètres
- **batch.size** : 16KB (défaut) vs 64KB vs 128KB
- **linger.ms** : 0ms (défaut) vs 5ms vs 50ms vs 100ms
- **compression.type** : none vs gzip vs snappy vs lz4

**Exemple de résultats typiques :**
- Configuration haute latence : `batch.size=1, linger.ms=0` → latence ~1ms
- Configuration haut débit : `batch.size=128KB, linger.ms=100` → 100K+ msg/sec

## 🔬 Analyse avancée

### Analyseur de topics
```bash
# Analyse complète d'un topic
./kafka/scripts/topic-analyzer.sh full mon-topic

# Analyser les segments et timestamps
./kafka/scripts/topic-analyzer.sh segments mon-topic
./kafka/scripts/topic-analyzer.sh timestamps mon-topic

# Vérifier la santé d'un topic
./kafka/scripts/topic-analyzer.sh health mon-topic

# Calculer la taille d'un topic
./kafka/scripts/topic-analyzer.sh size mon-topic

# Comparer plusieurs topics
./kafka/scripts/topic-analyzer.sh compare topic1 topic2 topic3
```

### Informations sur les segments
```bash
# Date de début d'un segment
kafka-dump-log --files /var/kafka-logs/mon-topic-0/00000000000000000000.log \
  --print-data-log | head -5

# Premiers et derniers offsets avec timestamps
kafka-run-class kafka.tools.GetOffsetShell \
  --broker-list localhost:9092 \
  --topic mon-topic \
  --time -2  # Premier offset

kafka-run-class kafka.tools.GetOffsetShell \
  --broker-list localhost:9092 \
  --topic mon-topic \
  --time -1  # Dernier offset
```

## 👥 Gestion des consumer groups

### Nombre de membres dans un groupe
```bash
# Compter les membres d'un groupe spécifique
kafka-consumer-groups \
  --bootstrap-server localhost:9092 \
  --describe \
  --group mon-groupe \
  --members | grep -c "CONSUMER-ID"

# Script pour tous les groupes
kafka-consumer-groups --bootstrap-server localhost:9092 --list | while read group; do
  members=$(kafka-consumer-groups --bootstrap-server localhost:9092 \
    --describe --group $group --members 2>/dev/null | grep -c "CONSUMER-ID")
  if [ $members -gt 0 ]; then
    echo "$group: $members membres"
  fi
done
```

### Détails des membres
```bash
# Membres avec leurs partitions assignées
kafka-consumer-groups \
  --bootstrap-server localhost:9092 \
  --describe \
  --group mon-groupe \
  --members \
  --verbose

# État de tous les groupes
kafka-consumer-groups \
  --bootstrap-server localhost:9092 \
  --describe \
  --all-groups \
  --state
```

## 🐘 Commandes Zookeeper

### Navigation dans Zookeeper
```bash
# Se connecter au shell Zookeeper
zkCli.sh -server localhost:2181

# Voir la structure Kafka
zkCli.sh -server localhost:2181 <<< "ls /kafka"

# Informations sur les brokers
zkCli.sh -server localhost:2181 <<< "ls /kafka/brokers/ids"
zkCli.sh -server localhost:2181 <<< "get /kafka/brokers/ids/0"

# Controller actuel
zkCli.sh -server localhost:2181 <<< "get /kafka/controller"
```

### Monitoring Zookeeper
```bash
# Statut de Zookeeper
echo "stat" | nc localhost 2181

# Configuration
echo "conf" | nc localhost 2181

# Connexions actives
echo "cons" | nc localhost 2181

# Logs en temps réel
tail -f $KAFKA_HOME/logs/zookeeper.out
```

## 🐍 Exemples Python

### Installation des dépendances
```bash
pip install -r requirements.txt
```

### Producteur simplifié
```python
from kafka.examples.producer_example import SimpleKafkaProducer

producer = SimpleKafkaProducer()
producer.send_message("test-topic", "Hello Kafka!")
producer.close()
```

### Consommateur simplifié
```python
from kafka.examples.consumer_example import SimpleKafkaConsumer

consumer = SimpleKafkaConsumer("test-topic", group_id="my-group")
consumer.consume_messages(max_messages=10)
```

## 📝 Commandes essentielles

Pour toutes les commandes détaillées, consultez [COMMANDES.md](COMMANDES.md)

### Topics les plus utilisés
```bash
# Créer un topic
kafka-topics --create --topic test --bootstrap-server localhost:9092

# Lister les topics
kafka-topics --list --bootstrap-server localhost:9092

# Producteur console
kafka-console-producer --topic test --bootstrap-server localhost:9092

# Consommateur console
kafka-console-consumer --topic test --from-beginning --bootstrap-server localhost:9092
```

### Gestion des groupes
```bash
# Lister les groupes
kafka-consumer-groups --list --bootstrap-server localhost:9092

# Détails d'un groupe
kafka-consumer-groups --describe --group mon-groupe --bootstrap-server localhost:9092

# Reset des offsets
kafka-consumer-groups --group mon-groupe --reset-offsets --to-earliest \
  --topic mon-topic --execute --bootstrap-server localhost:9092
```

## 🔒 Sécurité

### SASL PLAIN
Utilisez le fichier `kafka/admin.plain.properties` pour l'authentification PLAIN.

### SASL SCRAM
Utilisez le fichier `kafka/admin.scram.properties` pour l'authentification SCRAM-SHA-256.

```bash
# Créer un utilisateur SCRAM
kafka-configs --zookeeper localhost:2181 --alter \
  --add-config 'SCRAM-SHA-256=[password=secret]' \
  --entity-type users --entity-name alice
```

## 🔧 Troubleshooting

### Vérifications rapides
```bash
# Vérifier si Kafka fonctionne
kafka-broker-api-versions --bootstrap-server localhost:9092

# Vérifier les ports
netstat -tlnp | grep :9092

# Logs d'erreur
tail -f /opt/kafka/logs/server.log
```

### Nettoyage
```bash
# Supprimer tous les topics
kafka-topics --list --bootstrap-server localhost:9092 | \
  xargs -I {} kafka-topics --delete --topic {} --bootstrap-server localhost:9092

# Nettoyer les données
rm -rf /tmp/kafka-logs/* /tmp/zookeeper/*
```

## 📊 Monitoring

### Métriques importantes
```bash
# Partitions sous-répliquées
kafka-topics --describe --bootstrap-server localhost:9092 --under-replicated-partitions

# Groupes de consommateurs en lag
kafka-consumer-groups --bootstrap-server localhost:9092 --describe --all-groups

# Taille des logs
du -sh /var/kafka-logs/*
```

### Surveillance des performances
```bash
# Test de performance producteur
kafka-producer-perf-test \
  --topic test-topic \
  --num-records 100000 \
  --record-size 1000 \
  --throughput -1 \
  --producer-props bootstrap.servers=localhost:9092

# Test de performance consommateur
kafka-consumer-perf-test \
  --topic test-topic \
  --bootstrap-server localhost:9092 \
  --messages 100000 \
  --threads 1
```

## 🤝 Contribution

Ce projet est ouvert aux contributions ! N'hésitez pas à :
- Ajouter de nouvelles configurations
- Améliorer les scripts existants
- Proposer de nouveaux exemples
- Corriger la documentation

## 📚 Ressources utiles

- [Documentation officielle Kafka](https://kafka.apache.org/documentation/)
- [Kafka Python Client](https://kafka-python.readthedocs.io/)
- [Confluent Platform](https://docs.confluent.io/)
- [Kafka Streams](https://kafka.apache.org/documentation/streams/)
- [Optimisation des performances Kafka](https://kafka.apache.org/documentation/#producerconfigs)

## 🎯 Cas d'usage avancés

### Analyse de segments en temps réel
```bash
# Surveiller la création de nouveaux segments
watch -n 5 'ls -la /var/kafka-logs/mon-topic-*/*.log'

# Analyser l'évolution de la taille
./kafka/scripts/topic-analyzer.sh size mon-topic
```

### Optimisation des performances
```bash
# Tester différentes configurations
./kafka/scripts/performance-tests.sh batch mon-test

# Analyser les résultats
./kafka/scripts/topic-analyzer.sh compare \
  mon-test-batch-small mon-test-batch-large
```

---

🎉 **Félicitations !** Vous avez maintenant tous les outils pour maîtriser Kafka facilement !