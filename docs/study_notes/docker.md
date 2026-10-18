# Docker and Docker Compose Study Notes

Docker packages a process and its filesystem/dependencies into an image and runs that image as a container. Compose describes related services and their networks, ports, storage, and configuration.

## This Repository

docker-compose.yaml starts PostgreSQL 16 (pgdatabase) and pgAdmin (pgadmin) on the pg-network bridge. PostgreSQL publishes host port 5432; pgAdmin publishes host port 8080. Database data is mounted from ./pg_data into PostgreSQL's data path.

    Host tools -> localhost:5432 -> PostgreSQL container
    Browser -> localhost:8080 -> pgAdmin container
    pgAdmin -> pgdatabase:5432 -> PostgreSQL on pg-network

Inside a container, localhost means that container. Compose service names resolve through Docker DNS on the shared network.

## Useful Commands (Git Bash or PowerShell)

    docker compose up -d
    docker compose ps
    docker compose logs -f pgdatabase
    docker compose exec pgdatabase pg_isready -U root -d ny_taxi
    docker compose down

docker compose down stops/removes containers and the network while the bind-mounted pg_data remains. A health check is stronger than depends_on alone: startup order does not prove the database is ready for SQL connections.

## Concepts to Explain

- Image vs container: blueprint vs running instance.
- Port mapping: host-to-container access; separate from container-to-container networking.
- Bind mount vs named volume: explicit host path vs Docker-managed storage.
- Network: isolated connectivity and service-name discovery among containers.
- Compose: local multi-container configuration; not a production workflow orchestrator.
- Container vs VM: containers isolate processes while sharing the host kernel; VMs virtualize a full operating system.

## Interview Questions

1. Why did pgAdmin fail to connect to localhost:5432? Its localhost is the pgAdmin container; use pgdatabase:5432 on the Compose network.
2. Does depends_on mean Postgres is ready? Not by itself. Add a health check or retry logic.
3. What persists when a container is recreated? Data on a persistent mount/volume, not the container writable layer.
4. Why containerize an ingestion job? To package runtime and dependencies reproducibly; this repository has not yet added an ingestion Dockerfile.
