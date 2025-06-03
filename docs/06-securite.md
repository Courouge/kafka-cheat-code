# Sécurité et Gouvernance

## Vue d'Ensemble de la Sécurité Kafka

### Modèle de Sécurité
Apache Kafka implémente un modèle de sécurité **multicouche** couvrant :
- **Authentification** : Qui peut se connecter
- **Autorisation** : Qui peut faire quoi  
- **Chiffrement** : Protection des données en transit et au repos
- **Audit** : Traçabilité des actions

### Architecture Sécurisée
```
┌─────────────────────────────────────────┐
│              Clients                    │
│  ┌─────────────┐ ┌─────────────────────┐ │
│  │ Producers   │ │    Consumers        │ │
│  │ (SASL/SSL)  │ │   (SASL/SSL)        │ │
│  └─────────────┘ └─────────────────────┘ │
└─────────────────┬───────────────────────┘
                  │ TLS/SSL
                  ▼
┌─────────────────────────────────────────┐
│           Kafka Brokers                 │
│  ┌─────────────┐ ┌─────────────────────┐ │
│  │    ACLs     │ │    Audit Logs       │ │
│  │ (RBAC/ABAC) │ │                     │ │
│  └─────────────┘ └─────────────────────┘ │
└─────────────────────────────────────────┘
```

## Authentification

### SASL (Simple Authentication and Security Layer)

#### SASL/PLAIN
```properties
# Configuration broker
listeners=SASL_PLAINTEXT://localhost:9092
security.inter.broker.protocol=SASL_PLAINTEXT
sasl.mechanism.inter.broker.protocol=PLAIN
sasl.enabled.mechanisms=PLAIN

# JAAS configuration
listener.name.sasl_plaintext.plain.sasl.jaas.config=org.apache.kafka.common.security.plain.PlainLoginModule required \
   username="admin" \
   password="admin-secret" \
   user_admin="admin-secret" \
   user_alice="alice-secret";
```

#### Configuration Client SASL/PLAIN
```properties
# Producer/Consumer configuration
bootstrap.servers=localhost:9092
security.protocol=SASL_PLAINTEXT
sasl.mechanism=PLAIN
sasl.jaas.config=org.apache.kafka.common.security.plain.PlainLoginModule required \
   username="alice" \
   password="alice-secret";
```

#### SASL/SCRAM-SHA-256
```bash
# Créer des utilisateurs SCRAM
kafka-configs.sh --bootstrap-server localhost:9092 \
  --alter --add-config 'SCRAM-SHA-256=[password=alice-secret]' \
  --entity-type users --entity-name alice

kafka-configs.sh --bootstrap-server localhost:9092 \
  --alter --add-config 'SCRAM-SHA-256=[password=admin-secret]' \
  --entity-type users --entity-name admin
```

```properties
# Configuration broker SCRAM
sasl.enabled.mechanisms=SCRAM-SHA-256
listener.name.sasl_plaintext.scram-sha-256.sasl.jaas.config=org.apache.kafka.common.security.scram.ScramLoginModule required;

# Configuration client SCRAM
sasl.mechanism=SCRAM-SHA-256
sasl.jaas.config=org.apache.kafka.common.security.scram.ScramLoginModule required \
   username="alice" \
   password="alice-secret";
```

### SSL/TLS

#### Génération des Certificats
```bash
# 1. Créer CA (Certificate Authority)
openssl req -new -x509 -keyout ca-key -out ca-cert -days 365

# 2. Créer truststore
keytool -keystore kafka.server.truststore.jks -alias CARoot -import -file ca-cert

# 3. Créer keystore pour chaque broker
keytool -keystore kafka.server.keystore.jks -alias localhost -validity 365 -genkey -keyalg RSA

# 4. Créer certificate signing request
keytool -keystore kafka.server.keystore.jks -alias localhost -certreq -file cert-file

# 5. Signer le certificat avec CA
openssl x509 -req -CA ca-cert -CAkey ca-key -in cert-file -out cert-signed -days 365 -CAcreateserial

# 6. Importer CA dans keystore
keytool -keystore kafka.server.keystore.jks -alias CARoot -import -file ca-cert

# 7. Importer certificat signé
keytool -keystore kafka.server.keystore.jks -alias localhost -import -file cert-signed
```

#### Configuration SSL Broker
```properties
# SSL Listeners
listeners=SSL://localhost:9093
security.inter.broker.protocol=SSL

# SSL Keystore
ssl.keystore.location=/var/ssl/private/kafka.server.keystore.jks
ssl.keystore.password=test1234
ssl.key.password=test1234

# SSL Truststore  
ssl.truststore.location=/var/ssl/private/kafka.server.truststore.jks
ssl.truststore.password=test1234

# SSL Protocol
ssl.enabled.protocols=TLSv1.2,TLSv1.1,TLSv1
ssl.client.auth=required
```

#### Configuration SSL Client
```properties
# Client SSL configuration
bootstrap.servers=localhost:9093
security.protocol=SSL

ssl.truststore.location=/var/ssl/private/kafka.client.truststore.jks
ssl.truststore.password=test1234
ssl.keystore.location=/var/ssl/private/kafka.client.keystore.jks
ssl.keystore.password=test1234
ssl.key.password=test1234
```

### SASL + SSL (Recommandé pour Production)
```properties
# Configuration combinée SASL + SSL
listeners=SASL_SSL://localhost:9094
security.inter.broker.protocol=SASL_SSL
sasl.mechanism.inter.broker.protocol=SCRAM-SHA-256
sasl.enabled.mechanisms=SCRAM-SHA-256

# SSL settings
ssl.keystore.location=/var/ssl/private/kafka.server.keystore.jks
ssl.keystore.password=test1234
ssl.key.password=test1234
ssl.truststore.location=/var/ssl/private/kafka.server.truststore.jks
ssl.truststore.password=test1234

# SASL settings
listener.name.sasl_ssl.scram-sha-256.sasl.jaas.config=org.apache.kafka.common.security.scram.ScramLoginModule required;
```

## Autorisation

### ACLs (Access Control Lists)

#### Activation des ACLs
```properties
# Configuration broker pour ACLs
authorizer.class.name=kafka.security.authorizer.AclAuthorizer
super.users=User:admin
allow.everyone.if.no.acl.found=false
```

#### Gestion des ACLs
```bash
# Donner accès en lecture à un topic
kafka-acls.sh --bootstrap-server localhost:9092 \
  --add --allow-principal User:alice \
  --operation Read --topic test-topic

# Donner accès en écriture à un topic
kafka-acls.sh --bootstrap-server localhost:9092 \
  --add --allow-principal User:bob \
  --operation Write --topic test-topic

# Donner accès à un consumer group
kafka-acls.sh --bootstrap-server localhost:9092 \
  --add --allow-principal User:alice \
  --operation Read --group test-group

# Lister les ACLs
kafka-acls.sh --bootstrap-server localhost:9092 --list

# Supprimer une ACL
kafka-acls.sh --bootstrap-server localhost:9092 \
  --remove --allow-principal User:alice \
  --operation Read --topic test-topic
```

#### Types d'Opérations ACL
```bash
# Opérations disponibles :
# - Read : Lire des messages
# - Write : Écrire des messages  
# - Create : Créer des topics
# - Delete : Supprimer des topics
# - Alter : Modifier la configuration
# - Describe : Voir les métadonnées
# - ClusterAction : Actions sur le cluster
# - DescribeConfigs : Voir la configuration
# - AlterConfigs : Modifier la configuration
# - IdempotentWrite : Écriture idempotente
# - All : Toutes les opérations
```

### RBAC avec Confluent Platform

#### Définition des Rôles
```bash
# Créer un rôle personnalisé
confluent iam rbac role create DataEngineer \
  --description "Data Engineer role for analytics team"

# Assigner des permissions au rôle
confluent iam rbac role-binding create \
  --principal User:alice \
  --role DataEngineer \
  --resource Topic:analytics-

# Rôles prédéfinis Confluent
# - SystemAdmin : Administration complète
# - SecurityAdmin : Gestion sécurité
# - UserAdmin : Gestion utilisateurs
# - ClusterAdmin : Administration cluster
# - DeveloperRead : Lecture pour développeurs
# - DeveloperWrite : Écriture pour développeurs
```

#### Policies Granulaires
```yaml
# Exemple de politique RBAC
rbac_policy:
  principals:
    - name: "data-engineers"
      type: "group"
      permissions:
        - resource: "Topic:raw-*"
          operations: ["Write", "Read"]
        - resource: "Topic:processed-*"
          operations: ["Write", "Read"]
        - resource: "ConsumerGroup:processing-*"
          operations: ["Read"]
    
    - name: "data-analysts"
      type: "group"
      permissions:
        - resource: "Topic:analytics-*"
          operations: ["Read"]
        - resource: "Topic:reports-*"
          operations: ["Read"]
```

## Chiffrement

### Chiffrement en Transit

#### TLS Configuration Avancée
```properties
# Protocoles SSL supportés
ssl.enabled.protocols=TLSv1.3,TLSv1.2

# Cipher suites sécurisées
ssl.cipher.suites=TLS_ECDHE_RSA_WITH_AES_256_GCM_SHA384,TLS_ECDHE_RSA_WITH_AES_128_GCM_SHA256

# Validation hostname
ssl.endpoint.identification.algorithm=https

# Mutual TLS (mTLS)
ssl.client.auth=required
```

### Chiffrement au Repos

#### Chiffrement des Logs
```bash
# Configuration système de fichiers chiffré
# Option 1: LUKS/dm-crypt au niveau OS
cryptsetup luksFormat /dev/sdb
cryptsetup open /dev/sdb kafka-logs
mkfs.ext4 /dev/mapper/kafka-logs
mount /dev/mapper/kafka-logs /var/kafka-logs

# Option 2: Chiffrement au niveau application
# Utiliser des sérialiseurs/désérialiseurs chiffrés
```

#### Chiffrement avec Conduktor Gateway
```yaml
# Configuration chiffrement de champs
encryption_policies:
  - name: "encrypt-pii"
    algorithm: "AES-256-GCM"
    key_management: "aws-kms"
    fields:
      - "ssn"
      - "credit_card"
      - "email"
    topics:
      - "user-data"
      - "payment-info"
```

### Gestion des Clés

#### AWS KMS Integration
```yaml
# Configuration KMS
kms_config:
  provider: "aws-kms"
  region: "us-east-1"
  key_id: "arn:aws:kms:us-east-1:123456789012:key/12345678-1234-1234-1234-123456789012"
  
  encryption_context:
    purpose: "kafka-encryption"
    environment: "production"
```

#### HashiCorp Vault Integration
```yaml
# Configuration Vault
vault_config:
  address: "https://vault.company.com:8200"
  auth_method: "aws"
  role: "kafka-encryption"
  mount_path: "kafka-kv"
  key_path: "encryption-keys"
```

## Audit et Compliance

### Audit Logging

#### Configuration Audit Native
```properties
# Activation de l'audit logging
log4j.logger.kafka.authorizer.logger=INFO, authorizerAppender
log4j.additivity.kafka.authorizer.logger=false

# Configuration appender audit
log4j.appender.authorizerAppender=org.apache.log4j.RollingFileAppender
log4j.appender.authorizerAppender.File=/var/log/kafka/kafka-authorizer.log
log4j.appender.authorizerAppender.layout=org.apache.log4j.PatternLayout
log4j.appender.authorizerAppender.layout.ConversionPattern=[%d] %p %m (%c)%n
```

#### Format des Logs d'Audit
```json
{
  "timestamp": "2024-01-20T10:30:00.000Z",
  "correlationId": "12345-67890-abcdef",
  "principal": "User:alice",
  "operation": "Write",
  "resource": "Topic:sensitive-data",
  "resourcePattern": "LITERAL",
  "result": "ALLOWED",
  "clientId": "producer-1",
  "clientAddress": "192.168.1.100"
}
```

### Audit Avancé avec Confluent

#### Activation Audit Logging
```properties
# Confluent audit logging
confluent.security.audit.enable=true
confluent.security.audit.excluded.principals=User:system,User:monitoring

# Destinations audit
confluent.security.audit.logger.class=io.confluent.security.audit.ConfluentAuditLoggerPlugin
confluent.security.audit.routers=confluent_audit_log_router

# Configuration router
confluent.security.audit.router.confluent_audit_log_router.class=io.confluent.security.audit.ConfluentAuditLogRouter
confluent.security.audit.router.confluent_audit_log_router.logger.name=confluent-audit-log
```

#### Streaming des Logs d'Audit
```bash
# Topic d'audit automatique
# Les logs sont automatiquement publiés dans le topic _confluent-audit-log-events

# Consumer des events d'audit
kafka-console-consumer.sh \
  --bootstrap-server localhost:9092 \
  --topic _confluent-audit-log-events \
  --from-beginning
```

### Compliance Frameworks

#### GDPR Compliance
```yaml
# Configuration GDPR
gdpr_config:
  data_retention:
    personal_data_topics: ["user-events", "user-profiles"]
    max_retention_days: 1095  # 3 ans
    auto_delete: true
  
  right_to_be_forgotten:
    enabled: true
    request_topic: "gdpr-deletion-requests"
    processor_group: "gdpr-processor"
  
  data_minimization:
    fields_to_mask: ["email", "phone", "address"]
    anonymization_after_days: 365
```

#### SOX Compliance
```yaml
# Configuration SOX
sox_config:
  audit_requirements:
    - financial_data_access_logging: true
    - segregation_of_duties: true
    - change_management_approval: true
  
  financial_topics:
    - "financial-transactions"
    - "accounting-entries"
    - "audit-trail"
  
  access_controls:
    - role_based_access: true
    - periodic_access_review: true
    - privileged_access_monitoring: true
```

### Data Loss Prevention (DLP)

#### Détection de Données Sensibles
```yaml
# Règles DLP
dlp_rules:
  - name: "credit-card-detection"
    pattern: "\\d{4}[\\s-]?\\d{4}[\\s-]?\\d{4}[\\s-]?\\d{4}"
    action: "mask"
    severity: "high"
  
  - name: "ssn-detection"
    pattern: "\\d{3}-\\d{2}-\\d{4}"
    action: "encrypt"
    severity: "critical"
  
  - name: "email-detection"
    pattern: "[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\\.[a-zA-Z]{2,}"
    action: "tokenize"
    severity: "medium"
```

## Sécurité Multi-Cloud

### Cross-Cloud Security

#### Federated Identity
```yaml
# Configuration identité fédérée
federated_identity:
  providers:
    - name: "aws-iam"
      type: "AWS_IAM"
      region: "us-east-1"
      role_arn: "arn:aws:iam::123456789012:role/KafkaAccess"
    
    - name: "azure-ad"
      type: "AZURE_AD"
      tenant_id: "12345678-1234-1234-1234-123456789012"
      client_id: "87654321-4321-4321-4321-210987654321"
    
    - name: "gcp-iam"
      type: "GCP_IAM"
      project_id: "my-project-12345"
      service_account: "kafka-access@my-project-12345.iam.gserviceaccount.com"
```

#### Cross-Region Encryption
```yaml
# Chiffrement inter-régions
cross_region_encryption:
  enabled: true
  key_management: "multi-region-kms"
  
  regions:
    - name: "us-east-1"
      kms_key: "arn:aws:kms:us-east-1:123456789012:key/key-1"
    - name: "eu-west-1"
      kms_key: "arn:aws:kms:eu-west-1:123456789012:key/key-2"
  
  replication_encryption: true
  transit_encryption: true
```

### Network Security

#### VPC Configuration
```bash
# Configuration réseau sécurisée
# Kafka brokers dans subnet privé
# Accès via VPN ou bastion host uniquement
# Security groups restrictifs

# Example AWS Security Group
aws ec2 create-security-group \
  --group-name kafka-brokers \
  --description "Kafka brokers security group"

# Autoriser trafic Kafka inter-brokers
aws ec2 authorize-security-group-ingress \
  --group-id sg-12345678 \
  --protocol tcp \
  --port 9092 \
  --source-group sg-12345678

# Autoriser trafic client depuis subnet spécifique
aws ec2 authorize-security-group-ingress \
  --group-id sg-12345678 \
  --protocol tcp \
  --port 9092 \
  --cidr 10.0.1.0/24
```

## Bonnes Pratiques Sécurité

### Hardening de Configuration

#### Configuration Sécurisée Recommandée
```properties
# Désactiver auto-creation de topics
auto.create.topics.enable=false

# Désactiver unclean leader election
unclean.leader.election.enable=false

# Limiter taille des messages
message.max.bytes=1048576
replica.fetch.max.bytes=1048576

# Configuration logging sécurisée
log.retention.hours=168
log.retention.bytes=1073741824

# Désactiver JMX non sécurisé
# Ne pas utiliser -Dcom.sun.management.jmxremote sans authentification
```

#### Monitoring de Sécurité
```yaml
# Métriques de sécurité à surveiller
security_metrics:
  authentication:
    - failed_authentication_attempts
    - successful_authentications
    - authentication_rate
  
  authorization:
    - denied_access_attempts
    - acl_violations
    - privilege_escalation_attempts
  
  encryption:
    - ssl_handshake_failures
    - certificate_expiry_warnings
    - encryption_errors
```

### Rotation des Credentials

#### Rotation Automatisée
```bash
#!/bin/bash
# Script de rotation des mots de passe SCRAM

NEW_PASSWORD=$(openssl rand -base64 32)

# Mettre à jour le mot de passe
kafka-configs.sh --bootstrap-server localhost:9092 \
  --alter --add-config "SCRAM-SHA-256=[password=$NEW_PASSWORD]" \
  --entity-type users --entity-name alice

# Notifier les applications (webhook, notification, etc.)
curl -X POST https://webhook.company.com/kafka-password-rotated \
  -H "Content-Type: application/json" \
  -d "{\"user\":\"alice\",\"rotated_at\":\"$(date -Iseconds)\"}"
```

#### Rotation des Certificats
```bash
#!/bin/bash
# Script de rotation des certificats SSL

# Générer nouveau certificat
keytool -keystore kafka.server.keystore.new.jks \
  -alias localhost -validity 365 -genkey -keyalg RSA

# Rolling restart avec nouveau certificat
# 1. Mettre à jour un broker à la fois
# 2. Vérifier la santé du cluster
# 3. Continuer avec le broker suivant
```

---

**Sources :**
- [Apache Kafka Security](https://kafka.apache.org/documentation/#security)
- [Confluent Security Features](https://docs.confluent.io/platform/current/security/index.html)
- [Kafka Security Best Practices](https://www.confluent.io/blog/apache-kafka-security-authorization-authentication-encryption/)
- [SASL Authentication](https://kafka.apache.org/documentation/#security_sasl) 