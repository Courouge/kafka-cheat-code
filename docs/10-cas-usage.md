# Cas d'Usage et Architectures

## Event-Driven Microservices

### Architecture Event-Driven

#### Pattern Traditionnel vs Event-Driven
```
┌─── Architecture Traditionnelle ───┐
│                                   │
│  ┌────────────┐   ┌─────────────┐ │
│  │  Service   │──►│   Service   │ │
│  │     A      │   │      B      │ │
│  └────────────┘   └─────────────┘ │
│         │                        │
│         ▼                        │
│  ┌─────────────┐                 │
│  │   Service   │                 │
│  │      C      │                 │
│  └─────────────┘                 │
└───────────────────────────────────┘

┌─── Architecture Event-Driven ────┐
│                                   │
│  ┌────────────┐   ┌─────────────┐ │
│  │  Service   │   │   Service   │ │
│  │     A      │   │      B      │ │
│  └──────┬─────┘   └─────┬───────┘ │
│         │               │         │
│         ▼               ▼         │
│  ┌─────────────────────────────── │
│  │        Kafka Event Bus        │ │
│  └─────────────────────────────── │
│                 │                 │
│                 ▼                 │
│  ┌─────────────┐                 │
│  │   Service   │                 │
│  │      C      │                 │
│  └─────────────┘                 │
└───────────────────────────────────┘
```

### Implémentation E-Commerce

#### Services et Topics
```yaml
# Architecture e-commerce event-driven
services:
  order-service:
    produces:
      - order-created
      - order-cancelled
      - order-updated
    consumes:
      - payment-completed
      - inventory-reserved
      - shipping-confirmed

  payment-service:
    produces:
      - payment-initiated
      - payment-completed
      - payment-failed
    consumes:
      - order-created

  inventory-service:
    produces:
      - inventory-reserved
      - inventory-released
      - stock-updated
    consumes:
      - order-created
      - order-cancelled

  shipping-service:
    produces:
      - shipping-scheduled
      - shipping-confirmed
      - delivery-completed
    consumes:
      - payment-completed
      - inventory-reserved

  notification-service:
    consumes:
      - order-created
      - payment-completed
      - shipping-confirmed
      - delivery-completed
```

#### Saga Pattern avec Kafka
```java
// Order Saga Coordinator
@Component
public class OrderSagaCoordinator {
    
    @KafkaListener(topics = "order-created")
    public void handleOrderCreated(OrderCreatedEvent event) {
        // Step 1: Reserve inventory
        inventoryService.reserveInventory(event.getOrderId(), event.getItems());
    }
    
    @KafkaListener(topics = "inventory-reserved")
    public void handleInventoryReserved(InventoryReservedEvent event) {
        // Step 2: Process payment
        paymentService.processPayment(event.getOrderId(), event.getAmount());
    }
    
    @KafkaListener(topics = "payment-completed")
    public void handlePaymentCompleted(PaymentCompletedEvent event) {
        // Step 3: Schedule shipping
        shippingService.scheduleShipping(event.getOrderId());
    }
    
    // Compensation handlers
    @KafkaListener(topics = "payment-failed")
    public void handlePaymentFailed(PaymentFailedEvent event) {
        // Compensate: Release inventory
        inventoryService.releaseInventory(event.getOrderId());
    }
}
```

### Domain Events Design

#### Event Schema Design
```json
{
  "eventType": "OrderCreated",
  "eventId": "12345678-1234-1234-1234-123456789012",
  "aggregateId": "order-98765",
  "aggregateType": "Order",
  "eventVersion": "1.0",
  "timestamp": "2024-01-20T10:30:00Z",
  "metadata": {
    "correlationId": "user-session-123",
    "causationId": "web-request-456",
    "userId": "user-789"
  },
  "data": {
    "orderId": "order-98765",
    "customerId": "customer-123",
    "items": [
      {
        "productId": "product-456",
        "quantity": 2,
        "price": 29.99
      }
    ],
    "totalAmount": 59.98,
    "currency": "EUR"
  }
}
```

## Real-Time Analytics

### Architecture Lambda
```
┌─────────────────────────────────────────┐
│            Data Sources                 │
│  ┌─────────┐ ┌─────────┐ ┌─────────────┐ │
│  │   Web   │ │  Mobile │ │    IoT      │ │
│  │   App   │ │   App   │ │  Sensors    │ │
│  └─────────┘ └─────────┘ └─────────────┘ │
└─────────────────┬───────────────────────┘
                  │
                  ▼
┌─────────────────────────────────────────┐
│             Kafka Streams               │
├─────────────────────────────────────────┤
│  Speed Layer        │  Batch Layer       │
│ ┌─────────────────┐ │ ┌─────────────────┐ │
│ │ Real-time       │ │ │ Historical      │ │
│ │ Processing      │ │ │ Processing      │ │
│ │ (Kafka Streams) │ │ │ (Spark/Flink)   │ │
│ └─────────────────┘ │ └─────────────────┘ │
├─────────────────────────────────────────┤
│            Serving Layer                │
│ ┌─────────────────────────────────────┐ │
│ │     Analytics Dashboard             │ │
│ │     (Real-time + Historical)        │ │
│ └─────────────────────────────────────┘ │
└─────────────────────────────────────────┘
```

### Stream Processing avec Kafka Streams

#### Exemple Analytics E-commerce
```java
@Component
public class EcommerceAnalytics {
    
    @Bean
    public KStream<String, OrderEvent> orderAnalytics() {
        StreamsBuilder builder = new StreamsBuilder();
        
        // Stream des commandes
        KStream<String, OrderEvent> orders = builder.stream("orders");
        
        // Calcul du CA par fenêtre temporelle
        orders
            .groupBy((key, order) -> "total")
            .windowedBy(TimeWindows.of(Duration.ofMinutes(5)))
            .aggregate(
                () -> 0.0,
                (key, order, aggregate) -> aggregate + order.getAmount(),
                Materialized.as("revenue-store")
            )
            .toStream()
            .to("revenue-by-window");
        
        // Top produits par heure
        orders
            .flatMapValues(order -> order.getItems())
            .groupBy((key, item) -> item.getProductId())
            .windowedBy(TimeWindows.of(Duration.ofHours(1)))
            .count(Materialized.as("product-count-store"))
            .toStream()
            .to("top-products-hourly");
        
        // Détection d'anomalies (commandes > 1000€)
        orders
            .filter((key, order) -> order.getAmount() > 1000.0)
            .to("high-value-orders");
        
        return orders;
    }
}
```

#### Agrégations Complexes
```java
// Calcul de métriques business en temps réel
public class BusinessMetricsProcessor {
    
    public void processMetrics(StreamsBuilder builder) {
        KStream<String, OrderEvent> orders = builder.stream("orders");
        KStream<String, UserEvent> users = builder.stream("user-events");
        
        // Customer Lifetime Value en temps réel
        orders
            .groupBy((key, order) -> order.getCustomerId())
            .aggregate(
                CustomerMetrics::new,
                (customerId, order, metrics) -> {
                    metrics.addOrder(order);
                    return metrics;
                },
                Materialized.<String, CustomerMetrics, KeyValueStore<Bytes, byte[]>>as("customer-clv")
                    .withValueSerde(customerMetricsSerde)
            );
        
        // Conversion funnel
        users
            .filter((key, event) -> "page_view".equals(event.getEventType()))
            .groupBy((key, event) -> event.getSessionId())
            .windowedBy(SessionWindows.with(Duration.ofMinutes(30)))
            .aggregate(
                FunnelMetrics::new,
                (sessionId, event, funnel) -> {
                    funnel.addEvent(event);
                    return funnel;
                },
                (sessionId, funnel1, funnel2) -> funnel1.merge(funnel2),
                Materialized.as("conversion-funnel")
            );
    }
}
```

## Data Pipelines ETL/ELT

### Architecture Data Lake
```
┌─── Sources ───┐    ┌─── Streaming ───┐    ┌─── Storage ───┐
│               │    │                 │    │               │
│ ┌───────────┐ │    │ ┌─────────────┐ │    │ ┌───────────┐ │
│ │ Database  │─┼───►│ │    Kafka    │─┼───►│ │   Data    │ │
│ │   MySQL   │ │    │ │   Connect   │ │    │ │   Lake    │ │
│ └───────────┘ │    │ └─────────────┘ │    │ │   (S3)    │ │
│               │    │                 │    │ └───────────┘ │
│ ┌───────────┐ │    │ ┌─────────────┐ │    │               │
│ │    API    │─┼───►│ │   Schema    │─┼───►│ ┌───────────┐ │
│ │   REST    │ │    │ │  Registry   │ │    │ │ Analytics │ │
│ └───────────┘ │    │ └─────────────┘ │    │ │ Warehouse │ │
│               │    │                 │    │ │(Snowflake)│ │
│ ┌───────────┐ │    │ ┌─────────────┐ │    │ └───────────┘ │
│ │   Files   │─┼───►│ │ ksqlDB/Flink│─┼───►│               │
│ │   SFTP    │ │    │ │ Processing  │ │    │ ┌───────────┐ │
│ └───────────┘ │    │ └─────────────┘ │    │ │   Search  │ │
└───────────────┘    └─────────────────┘    │ │(Elastic)  │ │
                                            │ └───────────┘ │
                                            └───────────────┘
```

### Kafka Connect Configurations

#### Source Connector - MySQL CDC
```json
{
  "name": "mysql-source-connector",
  "config": {
    "connector.class": "io.debezium.connector.mysql.MySqlConnector",
    "database.hostname": "mysql-server",
    "database.port": "3306",
    "database.user": "kafka-connect",
    "database.password": "password",
    "database.server.id": "12345",
    "database.server.name": "mysql-server",
    "database.include.list": "ecommerce",
    "table.include.list": "ecommerce.orders,ecommerce.customers,ecommerce.products",
    "database.history.kafka.bootstrap.servers": "kafka:9092",
    "database.history.kafka.topic": "mysql-schema-changes",
    "include.schema.changes": "true",
    "transforms": "route",
    "transforms.route.type": "org.apache.kafka.connect.transforms.RegexRouter",
    "transforms.route.regex": "mysql-server.ecommerce.(.*)",
    "transforms.route.replacement": "ecommerce.$1"
  }
}
```

#### Sink Connector - S3
```json
{
  "name": "s3-sink-connector",
  "config": {
    "connector.class": "io.confluent.connect.s3.S3SinkConnector",
    "s3.region": "us-east-1",
    "s3.bucket.name": "data-lake-raw",
    "s3.part.size": "5242880",
    "flush.size": "10000",
    "rotate.interval.ms": "3600000",
    "rotate.schedule.interval.ms": "86400000",
    "timezone": "UTC",
    "topics": "ecommerce.orders,ecommerce.customers",
    "tasks.max": "3",
    "key.converter": "org.apache.kafka.connect.storage.StringConverter",
    "value.converter": "io.confluent.connect.avro.AvroConverter",
    "value.converter.schema.registry.url": "http://schema-registry:8081",
    "format.class": "io.confluent.connect.s3.format.avro.AvroFormat",
    "partitioner.class": "io.confluent.connect.storage.partitioner.TimeBasedPartitioner",
    "partition.duration.ms": "3600000",
    "path.format": "YYYY/MM/dd/HH",
    "locale": "en-US",
    "timestamp.extractor": "Record"
  }
}
```

### Stream Processing pour Data Quality

#### Validation et Enrichissement
```java
@Component
public class DataQualityProcessor {
    
    public void processDataQuality(StreamsBuilder builder) {
        KStream<String, CustomerEvent> customers = builder.stream("raw-customers");
        
        // Validation des données
        KStream<String, CustomerEvent>[] branches = customers
            .branch(
                (key, customer) -> isValidCustomer(customer),  // Valid
                (key, customer) -> true                        // Invalid
            );
        
        KStream<String, CustomerEvent> validCustomers = branches[0];
        KStream<String, CustomerEvent> invalidCustomers = branches[1];
        
        // Enrichissement avec données externes
        validCustomers
            .mapValues(customer -> enrichWithLocationData(customer))
            .mapValues(customer -> enrichWithCreditScore(customer))
            .to("enriched-customers");
        
        // Gestion des données invalides
        invalidCustomers
            .mapValues(customer -> createDataQualityReport(customer))
            .to("data-quality-issues");
    }
    
    private boolean isValidCustomer(CustomerEvent customer) {
        return customer.getEmail() != null && 
               customer.getEmail().matches("^[\\w-\\.]+@([\\w-]+\\.)+[\\w-]{2,4}$") &&
               customer.getPhoneNumber() != null &&
               customer.getPhoneNumber().matches("^\\+?[1-9]\\d{1,14}$");
    }
}
```

## Internet des Objets (IoT)

### Architecture IoT avec Kafka
```
┌─── Edge Devices ───┐    ┌─── Ingestion ───┐    ┌─── Processing ───┐
│                    │    │                 │    │                  │
│ ┌────────────────┐ │    │ ┌─────────────┐ │    │ ┌──────────────┐ │
│ │   Sensors      │─┼───►│ │    Kafka    │─┼───►│ │ Real-time    │ │
│ │ (Temperature,  │ │    │ │   Brokers   │ │    │ │ Analytics    │ │
│ │  Humidity,     │ │    │ └─────────────┘ │    │ │ (Kafka       │ │
│ │  Pressure)     │ │    │                 │    │ │  Streams)    │ │
│ └────────────────┘ │    │ ┌─────────────┐ │    │ └──────────────┘ │
│                    │    │ │   Schema    │ │    │                  │
│ ┌────────────────┐ │    │ │  Registry   │ │    │ ┌──────────────┐ │
│ │   Gateways     │─┼───►│ └─────────────┘ │    │ │   Alerting   │ │
│ │ (Protocol      │ │    │                 │    │ │   System     │ │
│ │  Translation)  │ │    │ ┌─────────────┐ │    │ └──────────────┘ │
│ └────────────────┘ │    │ │ Kafka       │─┼───►│                  │
│                    │    │ │ Connect     │ │    │ ┌──────────────┐ │
│ ┌────────────────┐ │    │ │ (MQTT, OPC) │ │    │ │ Time Series  │ │
│ │   Mobile       │─┼───►│ └─────────────┘ │    │ │ Database     │ │
│ │   Apps         │ │    │                 │    │ │ (InfluxDB)   │ │
│ └────────────────┘ │    └─────────────────┘    │ └──────────────┘ │
└────────────────────┘                           └──────────────────┘
```

### Telemetry Data Processing

#### Schema de Données IoT
```json
{
  "deviceId": "sensor-001",
  "deviceType": "temperature_sensor",
  "timestamp": "2024-01-20T10:30:00Z",
  "location": {
    "building": "Factory-A",
    "floor": 2,
    "room": "Production-Line-1"
  },
  "readings": {
    "temperature": 23.5,
    "humidity": 45.2,
    "pressure": 1013.25
  },
  "metadata": {
    "firmware_version": "1.2.3",
    "battery_level": 85,
    "signal_strength": -45
  }
}
```

#### Traitement des Données IoT
```java
@Component
public class IoTDataProcessor {
    
    @Bean
    public KStream<String, SensorReading> processIoTData() {
        StreamsBuilder builder = new StreamsBuilder();
        
        KStream<String, SensorReading> sensorData = builder.stream("iot-sensors");
        
        // Détection d'anomalies
        sensorData
            .filter((deviceId, reading) -> 
                reading.getTemperature() > 30.0 || reading.getTemperature() < 10.0)
            .mapValues(reading -> createTemperatureAlert(reading))
            .to("temperature-alerts");
        
        // Agrégation par fenêtre temporelle
        sensorData
            .groupBy((deviceId, reading) -> reading.getLocation().getBuilding())
            .windowedBy(TimeWindows.of(Duration.ofMinutes(5)))
            .aggregate(
                BuildingMetrics::new,
                (building, reading, metrics) -> {
                    metrics.addReading(reading);
                    return metrics;
                },
                Materialized.as("building-metrics")
            )
            .toStream()
            .to("building-aggregates");
        
        // Prédiction de maintenance
        sensorData
            .groupByKey()
            .windowedBy(TimeWindows.of(Duration.ofHours(1)))
            .aggregate(
                MaintenancePredictor::new,
                (deviceId, reading, predictor) -> {
                    predictor.addReading(reading);
                    return predictor;
                },
                Materialized.as("maintenance-predictors")
            )
            .toStream()
            .filter((deviceId, predictor) -> predictor.needsMaintenance())
            .mapValues(predictor -> createMaintenanceRequest(predictor))
            .to("maintenance-requests");
        
        return sensorData;
    }
}
```

## Financial Services

### Architecture Trading Platform
```
┌─── Market Data ───┐    ┌─── Processing ───┐    ┌─── Execution ───┐
│                   │    │                  │    │                 │
│ ┌───────────────┐ │    │ ┌──────────────┐ │    │ ┌─────────────┐ │
│ │   Reuters     │─┼───►│ │ Risk Engine  │─┼───►│ │ Order       │ │
│ │   Feed        │ │    │ │ (Real-time   │ │    │ │ Management  │ │
│ └───────────────┘ │    │ │  Analysis)   │ │    │ │ System      │ │
│                   │    │ └──────────────┘ │    │ └─────────────┘ │
│ ┌───────────────┐ │    │                  │    │                 │
│ │   Bloomberg   │─┼───►│ ┌──────────────┐ │    │ ┌─────────────┐ │
│ │   Terminal    │ │    │ │ Trading      │─┼───►│ │ Settlement  │ │
│ └───────────────┘ │    │ │ Algorithms   │ │    │ │ System      │ │
│                   │    │ └──────────────┘ │    │ └─────────────┘ │
│ ┌───────────────┐ │    │                  │    │                 │
│ │   Internal    │─┼───►│ ┌──────────────┐ │    │ ┌─────────────┐ │
│ │   Positions   │ │    │ │ Compliance   │─┼───►│ │ Reporting   │ │
│ └───────────────┘ │    │ │ Monitoring   │ │    │ │ System      │ │
└───────────────────┘    │ └──────────────┘ │    │ └─────────────┘ │
                         └──────────────────┘    └─────────────────┘
```

### Fraud Detection en Temps Réel

#### Pattern de Détection
```java
@Component
public class FraudDetectionProcessor {
    
    public void processFraudDetection(StreamsBuilder builder) {
        KStream<String, Transaction> transactions = builder.stream("transactions");
        
        // Détection de transactions suspectes
        transactions
            .groupBy((txId, tx) -> tx.getAccountId())
            .windowedBy(TimeWindows.of(Duration.ofMinutes(5)))
            .aggregate(
                TransactionWindow::new,
                (accountId, tx, window) -> {
                    window.addTransaction(tx);
                    return window;
                },
                Materialized.as("transaction-windows")
            )
            .toStream()
            .filter((accountWindow, window) -> window.isSuspicious())
            .mapValues(window -> createFraudAlert(window))
            .to("fraud-alerts");
        
        // Analyse des patterns géographiques
        transactions
            .filter((txId, tx) -> isInternationalTransaction(tx))
            .groupBy((txId, tx) -> tx.getAccountId())
            .windowedBy(SessionWindows.with(Duration.ofHours(1)))
            .count()
            .toStream()
            .filter((accountWindow, count) -> count > 3)
            .mapValues(count -> createLocationAlert(count))
            .to("location-alerts");
    }
    
    private boolean isInternationalTransaction(Transaction tx) {
        return !tx.getMerchantCountry().equals(tx.getAccountCountry());
    }
}
```

## Customer 360

### Architecture Customer Data Platform
```
┌─── Data Sources ───┐    ┌─── Integration ───┐    ┌─── Customer 360 ───┐
│                    │    │                   │    │                    │
│ ┌────────────────┐ │    │ ┌───────────────┐ │    │ ┌────────────────┐ │
│ │      CRM       │─┼───►│ │     Kafka     │─┼───►│ │   Unified      │ │
│ │   (Salesforce) │ │    │ │   Streams     │ │    │ │   Customer     │ │
│ └────────────────┘ │    │ └───────────────┘ │    │ │   Profile      │ │
│                    │    │                   │    │ └────────────────┘ │
│ ┌────────────────┐ │    │ ┌───────────────┐ │    │                    │
│ │   E-commerce   │─┼───►│ │    Schema     │─┼───►│ ┌────────────────┐ │
│ │    Platform    │ │    │ │   Registry    │ │    │ │   Real-time    │ │
│ └────────────────┘ │    │ └───────────────┘ │    │ │ Personalization│ │
│                    │    │                   │    │ └────────────────┘ │
│ ┌────────────────┐ │    │ ┌───────────────┐ │    │                    │
│ │   Mobile App   │─┼───►│ │ Data Quality  │─┼───►│ ┌────────────────┐ │
│ │   Analytics    │ │    │ │  Validation   │ │    │ │   Marketing    │ │
│ └────────────────┘ │    │ └───────────────┘ │    │ │   Automation   │ │
│                    │    │                   │    │ └────────────────┘ │
│ ┌────────────────┐ │    │ ┌───────────────┐ │    │                    │
│ │  Call Center   │─┼───►│ │   Identity    │─┼───►│ ┌────────────────┐ │
│ │    System      │ │    │ │  Resolution   │ │    │ │   Analytics    │ │
│ └────────────────┘ │    │ └───────────────┘ │    │ │   Dashboard    │ │
└────────────────────┘    │ └──────────────┘ │    │ │   System       │ │
                                                   │ └────────────────┘ │
                                                   └────────────────────┘
```

### Real-time Customer Profiling

#### Unification des Données Client
```java
@Component
public class CustomerProfileProcessor {
    
    public void buildCustomer360(StreamsBuilder builder) {
        // Streams de données client
        KStream<String, CrmEvent> crmEvents = builder.stream("crm-events");
        KStream<String, WebEvent> webEvents = builder.stream("web-events");
        KStream<String, PurchaseEvent> purchases = builder.stream("purchases");
        KStream<String, SupportEvent> supportEvents = builder.stream("support-events");
        
        // Table de profils clients
        KTable<String, CustomerProfile> customerProfiles = builder.table("customer-profiles");
        
        // Enrichissement des événements web avec profil client
        webEvents
            .leftJoin(customerProfiles, 
                (webEvent, profile) -> enrichWebEvent(webEvent, profile))
            .to("enriched-web-events");
        
        // Calcul de scores en temps réel
        purchases
            .groupBy((key, purchase) -> purchase.getCustomerId())
            .aggregate(
                CustomerScore::new,
                (customerId, purchase, score) -> {
                    score.updateWithPurchase(purchase);
                    return score;
                },
                Materialized.as("customer-scores")
            );
        
        // Détection d'événements significatifs
        GlobalKTable<String, CustomerProfile> profileTable = 
            builder.globalTable("customer-profiles");
        
        webEvents
            .join(profileTable, 
                (key, webEvent) -> webEvent.getCustomerId(),
                (webEvent, profile) -> detectSignificantBehavior(webEvent, profile))
            .filter((key, event) -> event != null)
            .to("significant-customer-events");
    }
    
    private EnrichedWebEvent enrichWebEvent(WebEvent webEvent, CustomerProfile profile) {
        return EnrichedWebEvent.builder()
            .webEvent(webEvent)
            .customerSegment(profile != null ? profile.getSegment() : "unknown")
            .lifetimeValue(profile != null ? profile.getLifetimeValue() : 0.0)
            .preferredCategories(profile != null ? profile.getPreferences() : null)
            .build();
    }
}
```

#### Personnalisation en Temps Réel
```java
@Component
public class RealtimePersonalization {
    
    @KafkaListener(topics = "web-events")
    public void handleWebEvent(WebEvent event) {
        // Récupérer le profil client
        CustomerProfile profile = getCustomerProfile(event.getCustomerId());
        
        // Générer recommandations personnalisées
        List<Recommendation> recommendations = 
            recommendationEngine.generateRecommendations(profile, event);
        
        // Publier les recommandations
        PersonalizationEvent personalizationEvent = PersonalizationEvent.builder()
            .customerId(event.getCustomerId())
            .sessionId(event.getSessionId())
            .recommendations(recommendations)
            .timestamp(Instant.now())
            .build();
        
        kafkaTemplate.send("personalization-events", personalizationEvent);
    }
    
    @KafkaListener(topics = "purchase-events")
    public void updateCustomerModel(PurchaseEvent purchase) {
        // Mettre à jour le modèle client en temps réel
        CustomerProfile profile = getCustomerProfile(purchase.getCustomerId());
        profile.updateWithPurchase(purchase);
        
        // Recalculer les segments
        String newSegment = segmentationEngine.calculateSegment(profile);
        profile.setSegment(newSegment);
        
        // Sauvegarder le profil mis à jour
        kafkaTemplate.send("customer-profile-updates", profile);
    }
}
```

---

**Sources :**
- [Event-Driven Architecture Patterns](https://www.confluent.io/blog/event-driven-architecture-patterns/)
- [Kafka Streams Examples](https://github.com/confluentinc/kafka-streams-examples)
- [Real-time Analytics Use Cases](https://www.confluent.io/use-case/real-time-analytics/)
- [IoT Data Streaming](https://www.confluent.io/use-case/internet-of-things/) 