# Makefile pour kafka-cheat-code
# Simplifie l'utilisation des scripts et commandes Kafka

.PHONY: help install start stop restart status logs \
        topic-create topic-list topic-describe topic-delete \
        groups group reset \
        test-producer test-consumer test-full test-cleanup \
        analyze-full analyze-health \
        producer consumer \
        check clean

# Variables
KAFKA_HOME ?= /opt/kafka
KAFKA_SERVER ?= localhost:9092
SCRIPTS_DIR = kafka/scripts
EXAMPLES_DIR = kafka/examples

# Couleurs pour l'affichage
BLUE = \033[0;34m
GREEN = \033[0;32m
YELLOW = \033[1;33m
NC = \033[0m

#==============================================================================
# Aide
#==============================================================================

help:
	@echo "$(BLUE)=== Kafka Cheat Code - Makefile ===$(NC)"
	@echo ""
	@echo "$(GREEN)Installation:$(NC)"
	@echo "  make install          - Installer les dépendances Python"
	@echo "  make check            - Vérifier les prérequis"
	@echo ""
	@echo "$(GREEN)Gestion Kafka:$(NC)"
	@echo "  make start            - Démarrer Zookeeper et Kafka"
	@echo "  make stop             - Arrêter Kafka et Zookeeper"
	@echo "  make restart          - Redémarrer les services"
	@echo "  make status           - Afficher le statut des services"
	@echo "  make logs             - Afficher les logs Kafka"
	@echo ""
	@echo "$(GREEN)Gestion des Topics:$(NC)"
	@echo "  make topic-create TOPIC=nom [PARTITIONS=3] [REPLICATION=1]"
	@echo "  make topic-list       - Lister tous les topics"
	@echo "  make topic-describe TOPIC=nom"
	@echo "  make topic-delete TOPIC=nom"
	@echo ""
	@echo "$(GREEN)Consumer Groups:$(NC)"
	@echo "  make groups           - Lister les groupes de consommateurs"
	@echo "  make group GROUP=nom  - Décrire un groupe"
	@echo "  make reset TOPIC=nom GROUP=groupe [TO=earliest|latest]"
	@echo ""
	@echo "$(GREEN)Tests de Performance:$(NC)"
	@echo "  make test-producer [TOPIC=nom]"
	@echo "  make test-consumer [TOPIC=nom]"
	@echo "  make test-full [TOPIC=nom]"
	@echo "  make test-cleanup     - Nettoyer les topics de test"
	@echo ""
	@echo "$(GREEN)Analyse des Topics:$(NC)"
	@echo "  make analyze-full TOPIC=nom"
	@echo "  make analyze-health TOPIC=nom"
	@echo ""
	@echo "$(GREEN)Exemples Python:$(NC)"
	@echo "  make producer         - Lancer l'exemple producteur"
	@echo "  make consumer         - Lancer l'exemple consommateur"
	@echo ""
	@echo "$(GREEN)Variables d'environnement:$(NC)"
	@echo "  KAFKA_HOME=$(KAFKA_HOME)"
	@echo "  KAFKA_SERVER=$(KAFKA_SERVER)"

#==============================================================================
# Installation et vérification
#==============================================================================

install:
	@echo "$(BLUE)Installation des dépendances Python...$(NC)"
	pip install -r requirements.txt
	@echo "$(GREEN)Installation terminée$(NC)"

check:
	@echo "$(BLUE)Vérification des prérequis...$(NC)"
	@echo ""
	@echo "Java:"
	@command -v java >/dev/null 2>&1 && java -version 2>&1 | head -1 || echo "  [MANQUANT] Java n'est pas installé"
	@echo ""
	@echo "Kafka:"
	@if [ -d "$(KAFKA_HOME)" ]; then \
		echo "  [OK] KAFKA_HOME=$(KAFKA_HOME)"; \
	else \
		echo "  [MANQUANT] KAFKA_HOME=$(KAFKA_HOME) n'existe pas"; \
	fi
	@command -v kafka-topics >/dev/null 2>&1 && echo "  [OK] kafka-topics disponible" || echo "  [MANQUANT] kafka-topics non trouvé dans PATH"
	@echo ""
	@echo "Python:"
	@command -v python3 >/dev/null 2>&1 && python3 --version || echo "  [MANQUANT] Python3 n'est pas installé"
	@python3 -c "import kafka" 2>/dev/null && echo "  [OK] kafka-python installé" || echo "  [MANQUANT] kafka-python (pip install kafka-python)"
	@echo ""

#==============================================================================
# Gestion Kafka
#==============================================================================

start:
	@KAFKA_HOME=$(KAFKA_HOME) $(SCRIPTS_DIR)/quick-start.sh start

stop:
	@KAFKA_HOME=$(KAFKA_HOME) $(SCRIPTS_DIR)/quick-start.sh stop

restart:
	@KAFKA_HOME=$(KAFKA_HOME) $(SCRIPTS_DIR)/quick-start.sh restart

status:
	@KAFKA_HOME=$(KAFKA_HOME) $(SCRIPTS_DIR)/quick-start.sh status

logs:
	@KAFKA_HOME=$(KAFKA_HOME) $(SCRIPTS_DIR)/quick-start.sh logs

#==============================================================================
# Gestion des Topics
#==============================================================================

topic-create:
ifndef TOPIC
	$(error TOPIC est requis. Usage: make topic-create TOPIC=mon-topic)
endif
	@KAFKA_SERVER=$(KAFKA_SERVER) $(SCRIPTS_DIR)/topic-manager.sh create \
		-t $(TOPIC) \
		-p $(or $(PARTITIONS),3) \
		-r $(or $(REPLICATION),1)

topic-list:
	@KAFKA_SERVER=$(KAFKA_SERVER) $(SCRIPTS_DIR)/topic-manager.sh list

topic-describe:
ifndef TOPIC
	$(error TOPIC est requis. Usage: make topic-describe TOPIC=mon-topic)
endif
	@KAFKA_SERVER=$(KAFKA_SERVER) $(SCRIPTS_DIR)/topic-manager.sh describe -t $(TOPIC)

topic-delete:
ifndef TOPIC
	$(error TOPIC est requis. Usage: make topic-delete TOPIC=mon-topic)
endif
	@KAFKA_SERVER=$(KAFKA_SERVER) $(SCRIPTS_DIR)/topic-manager.sh delete -t $(TOPIC)

#==============================================================================
# Consumer Groups
#==============================================================================

groups:
	@KAFKA_SERVER=$(KAFKA_SERVER) $(SCRIPTS_DIR)/topic-manager.sh groups

group:
ifndef GROUP
	$(error GROUP est requis. Usage: make group GROUP=mon-groupe)
endif
	@KAFKA_SERVER=$(KAFKA_SERVER) $(SCRIPTS_DIR)/topic-manager.sh group -g $(GROUP)

reset:
ifndef TOPIC
	$(error TOPIC est requis)
endif
ifndef GROUP
	$(error GROUP est requis)
endif
	@KAFKA_SERVER=$(KAFKA_SERVER) $(SCRIPTS_DIR)/topic-manager.sh reset \
		-t $(TOPIC) \
		-g $(GROUP) \
		--to-$(or $(TO),earliest)

#==============================================================================
# Tests de Performance
#==============================================================================

test-producer:
	@KAFKA_SERVER=$(KAFKA_SERVER) $(SCRIPTS_DIR)/performance-tests.sh producer $(or $(TOPIC),perf-test)

test-consumer:
	@KAFKA_SERVER=$(KAFKA_SERVER) $(SCRIPTS_DIR)/performance-tests.sh consumer $(or $(TOPIC),perf-test)

test-full:
	@KAFKA_SERVER=$(KAFKA_SERVER) $(SCRIPTS_DIR)/performance-tests.sh full $(or $(TOPIC),perf-test)

test-batch:
	@KAFKA_SERVER=$(KAFKA_SERVER) $(SCRIPTS_DIR)/performance-tests.sh batch $(or $(TOPIC),perf-test)

test-compression:
	@KAFKA_SERVER=$(KAFKA_SERVER) $(SCRIPTS_DIR)/performance-tests.sh compression $(or $(TOPIC),perf-test)

test-cleanup:
	@KAFKA_SERVER=$(KAFKA_SERVER) $(SCRIPTS_DIR)/performance-tests.sh cleanup

#==============================================================================
# Analyse des Topics
#==============================================================================

analyze-full:
ifndef TOPIC
	$(error TOPIC est requis. Usage: make analyze-full TOPIC=mon-topic)
endif
	@KAFKA_SERVER=$(KAFKA_SERVER) $(SCRIPTS_DIR)/topic-analyzer.sh full $(TOPIC)

analyze-health:
ifndef TOPIC
	$(error TOPIC est requis. Usage: make analyze-health TOPIC=mon-topic)
endif
	@KAFKA_SERVER=$(KAFKA_SERVER) $(SCRIPTS_DIR)/topic-analyzer.sh health $(TOPIC)

analyze-offsets:
ifndef TOPIC
	$(error TOPIC est requis. Usage: make analyze-offsets TOPIC=mon-topic)
endif
	@KAFKA_SERVER=$(KAFKA_SERVER) $(SCRIPTS_DIR)/topic-analyzer.sh offsets $(TOPIC)

analyze-size:
ifndef TOPIC
	$(error TOPIC est requis. Usage: make analyze-size TOPIC=mon-topic)
endif
	@KAFKA_SERVER=$(KAFKA_SERVER) $(SCRIPTS_DIR)/topic-analyzer.sh size $(TOPIC)

#==============================================================================
# Exemples Python
#==============================================================================

producer:
	@echo "$(BLUE)Lancement de l'exemple producteur...$(NC)"
	@KAFKA_BOOTSTRAP_SERVERS=$(KAFKA_SERVER) python3 $(EXAMPLES_DIR)/producer-example.py

consumer:
	@echo "$(BLUE)Lancement de l'exemple consommateur...$(NC)"
	@KAFKA_BOOTSTRAP_SERVERS=$(KAFKA_SERVER) python3 $(EXAMPLES_DIR)/consumer-example.py

#==============================================================================
# Nettoyage
#==============================================================================

clean:
	@echo "$(BLUE)Nettoyage...$(NC)"
	@find . -type f -name "*.pyc" -delete
	@find . -type d -name "__pycache__" -delete
	@echo "$(GREEN)Nettoyage terminé$(NC)"
