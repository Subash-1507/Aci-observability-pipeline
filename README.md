# Observability Pipeline on Azure Container Instances

**One instrumented API, two observability vendors, and an incident I cause on purpose, to prove I can find the root cause in minutes.**

> 🚧 **Status: in progress.** This README tells the plan as a story; each chapter is ticked off as it is built, with evidence.
> An observability engineering project: OpenTelemetry instrumentation, export to two vendors, SLOs, alerting and incident response.

---

## The story

It is 2 a.m. and customers say orders are failing. Without observability, the team guesses: restart things, read random logs, hope. With it, the story is different:

1. An **alert** fires: P95 latency is above 800 ms.
2. The **SLO** dashboard shows the error budget burning.
3. A **trace** of a failed request shows exactly which step was slow.
4. The **log line linked to that trace** says "payment gateway timeout".
5. Root cause found in **minutes, not hours**.

This project builds that chain end to end, then triggers the incident on purpose and measures how fast it is detected.

## What I am building

- **One API, instrumented once:** a FastAPI order service with Redis, instrumented with **OpenTelemetry**, the vendor-neutral standard.
- **Two vendors, one pipeline:** an OpenTelemetry Collector sends the same traces, metrics and logs to **Datadog** and **New Relic**, so there is no lock-in to either.
- **Serverless containers:** the API, Redis and the Collector run together in one **Azure Container Instances** group, sharing `localhost` like a Kubernetes pod, with no cluster to manage.
- **Secure delivery:** Terraform with remote state, GitHub Actions with OIDC (no stored Azure passwords), image scanning and an approval-gated deploy.
- **Reliability practice:** dashboards, an availability **SLO**, a latency **alert**, and an **incident drill**.

## The plan, chapter by chapter

| | Chapter | What happens | Evidence I will capture |
|---|---|---|---|
| ✅ | **0. Foundations** | Repo, dev container, region decision, CI security gates | Green pipeline |
| ✅ | **1. Run it locally** | API, Redis and the Collector with Docker Compose; telemetry printed locally | Trace in the Collector output |
| ✅ | **2. Instrumentation** | Traces, a business metric, logs linked to trace IDs, and a fault switch | Span, metric and log samples |
| ⬜ | **3. Two vendors, one pipeline** | Export to New Relic and Datadog at the same time | The same trace in both tools |
| ⬜ | **4. Azure with Terraform** | Budget alert, remote state, registry, managed identity, Container Instances group | Resource configuration |
| ⬜ | **5. CI/CD** | Build, scan and deploy with OIDC and an approval gate | Pipeline run |
| ⬜ | **6. Dashboards, SLO and alerts** | Traffic, a 99% availability SLO, a P95 latency alert | Dashboard and alert screenshots |
| ⬜ | **7. Incident drill** | Inject faults, measure time to detect, follow alert to trace to log | Timeline of the drill |
| ⬜ | **8. Cost and teardown** | Cost report, then delete everything | Cost report, empty resource group |

## Run it yourself

Everything runs locally with Docker Compose: the API, Redis and the OpenTelemetry Collector, with only the API published, on loopback.

```bash
docker compose up -d --build
curl -X POST http://127.0.0.1:8000/order/laptop-1
curl -X POST "http://127.0.0.1:8000/order/laptop-fault?simulate_fault=true"   # a slow, failing payment call
docker compose logs otel-collector                                             # traces, metrics and logs
```

Following one failed order from its error log to its spans: [evidence 01](docs/evidence/01-local-pipeline.txt).

The Collector also reports on itself, on loopback only:

```bash
curl http://127.0.0.1:13133/                                          # health
curl -s http://127.0.0.1:8888/metrics | grep otelcol_exporter_sent    # telemetry sent, per signal
```

Chapter 2 adds the build version to every signal, stable HTTP metric names (`http.server.request.duration`, in seconds), removal of client IPs before export, and Collector health: [evidence 02](docs/evidence/02-instrumentation.txt).

## Decisions

- [0001: Deploy to Korea Central](docs/decisions/0001-region-koreacentral.md)

---

## Author

**Subash Chandra Bose**: DevOps, Cloud & Security Engineer · Microsoft Certified (SC-500, AZ-104, SC-200)
[Portfolio](https://subash-1507.github.io) · [LinkedIn](https://www.linkedin.com/in/subash-chandra-bose-014bb21b5) · [GitHub](https://github.com/Subash-1507)
