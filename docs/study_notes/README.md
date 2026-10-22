# Data Engineering Study Notes

These notes are a durable revision guide for the NYC taxi project and the analytics-engineering role you shared. Start with the current project map, then revise the tool notes alongside the code.

## Recommended Study Order

1. [Bronze, Silver, and Gold in this project](layers_and_project.md)
2. [SQL](sql.md) and [PostgreSQL](postgresql.md)
3. [Python ingestion](python_ingestion.md)
4. [Docker and Compose](docker.md), then [Bash](bash.md)
5. [Dimensional modeling and data quality](modeling_and_quality.md)
6. [Orchestration, lakehouse, BI, and governance](orchestration_lakehouse_governance.md)
7. [Kafka](kafka.md) as a separate streaming topic
8. [Role-focused interview questions](interview_questions.md)

Existing material: [Module 1 interview Q&A](../module1_interview_qa.md), [interview playbook](../interview_playbook.md), [data-quality workflow](../data_quality_workflow.md), and [session checkpoint](../session_checkpoint.md).

## How to Use These Notes

- Explain each idea in your own words before memorizing a model answer.
- Tie claims about hands-on work to code or results you can show.
- Label a tool as implemented, studied, or planned. Kafka and Databricks are not part of the current taxi pipeline.
- Practice the questions aloud, then verify details against this repository.

## Project Status at a Glance

| Layer / capability | Current project status |
| --- | --- |
| Bronze | Local TLC source files and ingested raw PostgreSQL tables are present. |
| Silver | yellow_taxi_trips_2025_01_clean is built by SQL while the raw table is retained. |
| Quality review | yellow_taxi_trips_2025_01_flagged is a non-destructive view. Vendor 2 Flex Fare findings are documented as unresolved. |
| Gold | The daily-demand view is built; trip, review-flag, negative-fare, and negative-total counts reconcile to Silver/review views. A trip-level PostgreSQL star schema is scripted, and the Power BI Gold aggregate has date and role-playing location dimensions. |
| Orchestration | The user runs the Python CLI and SQL scripts manually; no workflow scheduler is configured here. |
| Kafka / Databricks | Study topics or future extensions, not implemented in this repository. |
