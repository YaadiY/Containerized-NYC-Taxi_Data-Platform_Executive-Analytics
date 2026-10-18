# Apache Kafka Study Notes

Kafka is a distributed event log used for streaming data. It is not currently used by the NYC taxi batch pipeline in this repository; treat this as a separate study topic or a future project extension.

## Core Vocabulary

- Broker: Kafka server that stores and serves partition data.
- Topic: named stream of records.
- Partition: ordered append-only log within a topic. Ordering is guaranteed within a partition, not across the whole topic.
- Key: determines partition placement; a stable entity key can preserve per-entity ordering.
- Offset: record position within a partition.
- Producer: publishes events.
- Consumer group: cooperating consumers divide topic partitions; within a group, a partition is assigned to one consumer at a time.
- Consumer lag: distance between latest topic offset and the consumer group's committed/read position.

## Delivery and Failure Handling

- At-most-once: commit/read position before processing; no duplicate processing, but failure can lose work.
- At-least-once: process then commit; a crash between these steps can replay a record, so consumers need idempotency/deduplication.
- Exactly-once: requires carefully defined boundaries and Kafka transactions or idempotent operations; it does not automatically make arbitrary database side effects exactly once.
- Dead-letter topic: stores events that repeatedly fail validation or processing with enough metadata to investigate and replay safely.
- Rebalance: partition assignments change when consumers join/leave or group membership changes; processing and commits must handle it safely.

## Design Questions

Before using Kafka, define event schema, key, partition count, retention, replay policy, failure policy, and what a committed offset means. More partitions can increase parallelism, but a consumer group cannot run more active consumers than partitions for that topic.

## Interview Questions

1. Where is Kafka ordering guaranteed? Within one partition.
2. Why use a message key? To route related events to the same partition and preserve their order.
3. What happens if a consumer commits before writing to the database? A crash after commit but before the write can lose the event from the consumer's perspective.
4. Why is idempotency needed with at-least-once delivery? Replayed events must not create duplicate business effects.
5. How do you scale a consumer group? Add consumers up to the number of partitions, considering workload and downstream capacity.

## Future Taxi Extension (Not Implemented)

A Kafka exercise could publish simulated trip events, validate them in a consumer, and write to a separate PostgreSQL table with an event ID and idempotent upsert. Do not describe this as part of the current project until it is built and documented.
