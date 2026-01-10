#!/usr/bin/env python3
"""
Exemple de producteur Kafka avec configuration simplifiée

Usage:
    python producer-example.py

Variables d'environnement:
    KAFKA_BOOTSTRAP_SERVERS: Serveurs Kafka (défaut: localhost:9092)
"""

import json
import os
import sys
import time
from datetime import datetime

try:
    from kafka import KafkaProducer
    from kafka.errors import KafkaError
except ImportError:
    print("Erreur: kafka-python n'est pas installé.")
    print("Installez-le avec: pip install kafka-python")
    sys.exit(1)

# Configuration par défaut depuis les variables d'environnement
DEFAULT_BOOTSTRAP_SERVERS = os.environ.get('KAFKA_BOOTSTRAP_SERVERS', 'localhost:9092')


class SimpleKafkaProducer:
    def __init__(self, bootstrap_servers=None, **kwargs):
        """
        Initialise le producteur Kafka avec une configuration simplifiée

        Args:
            bootstrap_servers: Liste des serveurs Kafka (défaut: $KAFKA_BOOTSTRAP_SERVERS ou localhost:9092)
            **kwargs: Paramètres additionnels pour le producteur
        """
        if bootstrap_servers is None:
            bootstrap_servers = DEFAULT_BOOTSTRAP_SERVERS

        default_config = {
            'bootstrap_servers': bootstrap_servers,
            'key_serializer': lambda k: k.encode('utf-8') if k else None,
            'value_serializer': lambda v: json.dumps(v).encode('utf-8'),
            'acks': 'all',  # Attendre toutes les répliques
            'retries': 3,
            'batch_size': 16384,
            'linger_ms': 5,
            'compression_type': 'snappy'
        }
        
        # Merger la configuration par défaut avec les paramètres utilisateur
        config = {**default_config, **kwargs}
        
        try:
            self.producer = KafkaProducer(**config)
            print(f"✅ Producteur connecté à {bootstrap_servers}")
        except Exception as e:
            print(f"❌ Erreur de connexion: {e}")
            raise

    def send_message(self, topic, message, key=None):
        """
        Envoie un message simple
        
        Args:
            topic: Nom du topic
            message: Message à envoyer (dict ou string)
            key: Clé optionnelle pour le partitioning
        """
        try:
            # Convertir le message en dict si c'est une string
            if isinstance(message, str):
                message = {"content": message, "timestamp": datetime.now().isoformat()}
            
            future = self.producer.send(topic, value=message, key=key)
            record_metadata = future.get(timeout=10)
            
            print(f"📤 Message envoyé - Topic: {record_metadata.topic}, "
                  f"Partition: {record_metadata.partition}, "
                  f"Offset: {record_metadata.offset}")
            
            return record_metadata
            
        except KafkaError as e:
            print(f"❌ Erreur Kafka: {e}")
            raise
        except Exception as e:
            print(f"❌ Erreur: {e}")
            raise

    def send_batch(self, topic, messages, keys=None):
        """
        Envoie plusieurs messages en batch
        
        Args:
            topic: Nom du topic
            messages: Liste de messages
            keys: Liste de clés (optionnel)
        """
        if keys and len(keys) != len(messages):
            raise ValueError("Le nombre de clés doit correspondre au nombre de messages")
        
        futures = []
        for i, message in enumerate(messages):
            key = keys[i] if keys else None
            future = self.producer.send(topic, value=message, key=key)
            futures.append(future)
        
        # Attendre tous les envois
        successful = 0
        failed = 0
        
        for future in futures:
            try:
                future.get(timeout=10)
                successful += 1
            except Exception as e:
                print(f"❌ Échec d'envoi: {e}")
                failed += 1
        
        print(f"📊 Batch terminé - Succès: {successful}, Échecs: {failed}")
        return successful, failed

    def close(self):
        """Ferme proprement le producteur"""
        if hasattr(self, 'producer') and self.producer:
            self.producer.flush()  # S'assurer que tous les messages sont envoyés
            self.producer.close()
            self.producer = None
            print("[OK] Producteur ferme")

    def __enter__(self):
        """Support du context manager (with statement)"""
        return self

    def __exit__(self, exc_type, exc_val, exc_tb):
        """Fermeture automatique avec le context manager"""
        self.close()
        return False


def example_simple_messages():
    """Exemple d'envoi de messages simples"""
    print("\n=== Exemple: Messages simples ===")
    
    producer = SimpleKafkaProducer()
    
    try:
        # Messages simples
        producer.send_message("test-topic", "Hello Kafka!")
        producer.send_message("test-topic", "Message avec timestamp")
        
        # Message avec clé
        producer.send_message("test-topic", "Message avec clé", key="user-123")
        
        # Message structuré
        message = {
            "user_id": 123,
            "action": "login",
            "timestamp": datetime.now().isoformat(),
            "ip": "192.168.1.100"
        }
        producer.send_message("user-events", message, key="user-123")
        
    finally:
        producer.close()

def example_batch_messages():
    """Exemple d'envoi en batch"""
    print("\n=== Exemple: Messages en batch ===")
    
    producer = SimpleKafkaProducer()
    
    try:
        # Générer des messages de test
        messages = []
        keys = []
        
        for i in range(10):
            message = {
                "id": i,
                "content": f"Message batch {i}",
                "timestamp": datetime.now().isoformat()
            }
            messages.append(message)
            keys.append(f"key-{i}")
        
        # Envoyer en batch
        producer.send_batch("batch-topic", messages, keys)
        
    finally:
        producer.close()

def example_monitoring():
    """Exemple avec monitoring des métriques"""
    print("\n=== Exemple: Monitoring ===")
    
    producer = SimpleKafkaProducer()
    
    try:
        start_time = time.time()
        message_count = 100
        
        for i in range(message_count):
            message = {
                "id": i,
                "data": f"Performance test {i}",
                "timestamp": datetime.now().isoformat()
            }
            producer.send_message("perf-topic", message)
            
            # Afficher le progrès
            if (i + 1) % 20 == 0:
                elapsed = time.time() - start_time
                rate = (i + 1) / elapsed
                print(f"📈 Progrès: {i + 1}/{message_count} messages, "
                      f"Taux: {rate:.2f} msg/sec")
        
        total_time = time.time() - start_time
        print(f"🏁 Terminé: {message_count} messages en {total_time:.2f}s "
              f"({message_count/total_time:.2f} msg/sec)")
        
    finally:
        producer.close()

if __name__ == "__main__":
    print("🚀 Exemples de producteur Kafka")
    
    try:
        # Exemples
        example_simple_messages()
        example_batch_messages()
        example_monitoring()
        
    except KeyboardInterrupt:
        print("\n🛑 Arrêt demandé par l'utilisateur")
    except Exception as e:
        print(f"\n❌ Erreur: {e}")
        import traceback
        traceback.print_exc() 