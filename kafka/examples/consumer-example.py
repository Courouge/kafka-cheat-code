#!/usr/bin/env python3
"""
Exemple de consommateur Kafka avec configuration simplifiée
"""

import json
import signal
import sys
from datetime import datetime
from kafka import KafkaConsumer
from kafka.errors import KafkaError

class SimpleKafkaConsumer:
    def __init__(self, topics, group_id='default-group', bootstrap_servers='localhost:9092', **kwargs):
        """
        Initialise le consommateur Kafka avec une configuration simplifiée
        
        Args:
            topics: Topic(s) à consommer (string ou liste)
            group_id: ID du groupe de consommateurs
            bootstrap_servers: Liste des serveurs Kafka
            **kwargs: Paramètres additionnels pour le consommateur
        """
        if isinstance(topics, str):
            topics = [topics]
        
        self.topics = topics
        self.running = True
        
        default_config = {
            'bootstrap_servers': bootstrap_servers,
            'group_id': group_id,
            'key_deserializer': lambda k: k.decode('utf-8') if k else None,
            'value_deserializer': lambda v: json.loads(v.decode('utf-8')),
            'auto_offset_reset': 'earliest',  # Commencer au début si pas d'offset
            'enable_auto_commit': True,
            'auto_commit_interval_ms': 1000,
            'max_poll_records': 500,
            'session_timeout_ms': 30000,
            'heartbeat_interval_ms': 3000
        }
        
        # Merger la configuration par défaut avec les paramètres utilisateur
        config = {**default_config, **kwargs}
        
        try:
            self.consumer = KafkaConsumer(*topics, **config)
            print(f"✅ Consommateur connecté - Topics: {topics}, Groupe: {group_id}")
            
            # Gestionnaire de signal pour arrêt propre
            signal.signal(signal.SIGINT, self._signal_handler)
            signal.signal(signal.SIGTERM, self._signal_handler)
            
        except Exception as e:
            print(f"❌ Erreur de connexion: {e}")
            raise

    def _signal_handler(self, signum, frame):
        """Gestionnaire pour arrêt propre"""
        print(f"\n🛑 Signal {signum} reçu, arrêt en cours...")
        self.running = False

    def consume_messages(self, message_handler=None, max_messages=None):
        """
        Consomme les messages du topic
        
        Args:
            message_handler: Fonction pour traiter chaque message
            max_messages: Nombre maximum de messages à consommer
        """
        message_count = 0
        
        try:
            print(f"🎧 Écoute des messages sur {self.topics}...")
            
            for message in self.consumer:
                if not self.running:
                    break
                
                # Traitement par défaut si pas de handler personnalisé
                if message_handler:
                    try:
                        message_handler(message)
                    except Exception as e:
                        print(f"❌ Erreur dans le handler: {e}")
                else:
                    self._default_message_handler(message)
                
                message_count += 1
                
                # Arrêter si limite atteinte
                if max_messages and message_count >= max_messages:
                    print(f"🎯 Limite de {max_messages} messages atteinte")
                    break
                    
        except KafkaError as e:
            print(f"❌ Erreur Kafka: {e}")
        except Exception as e:
            print(f"❌ Erreur: {e}")
        finally:
            print(f"📊 Total messages traités: {message_count}")
            self.close()

    def _default_message_handler(self, message):
        """Handler par défaut pour afficher les messages"""
        print(f"📥 Message reçu:")
        print(f"   Topic: {message.topic}")
        print(f"   Partition: {message.partition}")
        print(f"   Offset: {message.offset}")
        print(f"   Clé: {message.key}")
        print(f"   Valeur: {message.value}")
        print(f"   Timestamp: {datetime.fromtimestamp(message.timestamp/1000) if message.timestamp else 'N/A'}")
        print("---")

    def consume_batch(self, batch_size=10, timeout_ms=1000):
        """
        Consomme les messages par batch
        
        Args:
            batch_size: Taille du batch
            timeout_ms: Timeout pour récupérer un batch
        """
        try:
            while self.running:
                # Récupérer un batch de messages
                message_batch = self.consumer.poll(timeout_ms=timeout_ms, max_records=batch_size)
                
                if not message_batch:
                    print("⏳ Aucun message reçu, attente...")
                    continue
                
                # Traiter chaque partition dans le batch
                for topic_partition, messages in message_batch.items():
                    print(f"📦 Batch reçu - Topic: {topic_partition.topic}, "
                          f"Partition: {topic_partition.partition}, "
                          f"Messages: {len(messages)}")
                    
                    for message in messages:
                        self._default_message_handler(message)
                
                # Commit manuel des offsets
                self.consumer.commit()
                
        except Exception as e:
            print(f"❌ Erreur dans consume_batch: {e}")
        finally:
            self.close()

    def get_current_offsets(self):
        """Récupère les offsets actuels"""
        try:
            partitions = self.consumer.assignment()
            if not partitions:
                print("❌ Aucune partition assignée")
                return {}
            
            offsets = {}
            for partition in partitions:
                position = self.consumer.position(partition)
                committed = self.consumer.committed(partition)
                offsets[partition] = {
                    'position': position,
                    'committed': committed
                }
            
            return offsets
        except Exception as e:
            print(f"❌ Erreur lors de la récupération des offsets: {e}")
            return {}

    def close(self):
        """Ferme proprement le consommateur"""
        if hasattr(self, 'consumer'):
            self.consumer.close()
            print("🔒 Consommateur fermé")

def custom_message_handler(message):
    """Exemple de handler personnalisé"""
    data = message.value
    
    # Traitement spécifique selon le type de message
    if isinstance(data, dict) and 'user_id' in data:
        print(f"👤 Action utilisateur: {data.get('action')} pour user {data.get('user_id')}")
    elif isinstance(data, dict) and 'content' in data:
        print(f"💬 Message: {data.get('content')}")
    else:
        print(f"📄 Données: {data}")

def example_simple_consumer():
    """Exemple de consommation simple"""
    print("\n=== Exemple: Consommateur simple ===")
    
    consumer = SimpleKafkaConsumer('test-topic', group_id='example-group')
    
    try:
        # Consommer 5 messages maximum
        consumer.consume_messages(max_messages=5)
    except KeyboardInterrupt:
        print("\n🛑 Arrêt demandé par l'utilisateur")

def example_custom_handler():
    """Exemple avec handler personnalisé"""
    print("\n=== Exemple: Handler personnalisé ===")
    
    consumer = SimpleKafkaConsumer(['test-topic', 'user-events'], group_id='custom-group')
    
    try:
        consumer.consume_messages(message_handler=custom_message_handler, max_messages=10)
    except KeyboardInterrupt:
        print("\n🛑 Arrêt demandé par l'utilisateur")

def example_batch_consumer():
    """Exemple de consommation par batch"""
    print("\n=== Exemple: Consommation par batch ===")
    
    # Configuration pour désactiver l'auto-commit
    consumer = SimpleKafkaConsumer(
        'batch-topic',
        group_id='batch-group',
        enable_auto_commit=False
    )
    
    try:
        consumer.consume_batch(batch_size=5, timeout_ms=2000)
    except KeyboardInterrupt:
        print("\n🛑 Arrêt demandé par l'utilisateur")

def example_offset_monitoring():
    """Exemple de monitoring des offsets"""
    print("\n=== Exemple: Monitoring des offsets ===")
    
    consumer = SimpleKafkaConsumer('test-topic', group_id='monitor-group')
    
    try:
        # Laisser le temps au consommateur de s'assigner des partitions
        import time
        time.sleep(2)
        
        # Afficher les offsets actuels
        offsets = consumer.get_current_offsets()
        for partition, info in offsets.items():
            print(f"📍 {partition.topic}:{partition.partition} - "
                  f"Position: {info['position']}, Committed: {info['committed']}")
        
        # Consommer quelques messages
        consumer.consume_messages(max_messages=3)
        
    except KeyboardInterrupt:
        print("\n🛑 Arrêt demandé par l'utilisateur")

if __name__ == "__main__":
    print("🎧 Exemples de consommateur Kafka")
    
    try:
        # Exemples (décommenter celui que vous voulez tester)
        example_simple_consumer()
        # example_custom_handler()
        # example_batch_consumer()
        # example_offset_monitoring()
        
    except KeyboardInterrupt:
        print("\n🛑 Arrêt demandé par l'utilisateur")
    except Exception as e:
        print(f"\n❌ Erreur: {e}")
        import traceback
        traceback.print_exc() 