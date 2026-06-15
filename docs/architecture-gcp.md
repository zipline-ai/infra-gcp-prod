# Zipline on GCP — What Gets Installed

This document describes what the Zipline platform installs into **your own GCP project**.
Zipline is deployed **BYOC (Bring Your Own Cloud)**: every component below runs inside your
project and your VPC, and your data never leaves your environment. The platform is two things:

1. A **GKE cluster** that runs the Zipline application and your Spark/Flink compute, and
2. A set of **GCP managed services** (Cloud Storage, BigQuery, Bigtable, etc.) that Zipline
   uses for storage, serving, and credentials.

Access from your users is fronted by an **Identity-Aware Proxy (IAP)**, so only people you
authorize can reach the UI.

## Diagram

```
                              Your users
                                  │
                       Identity-Aware Proxy (SSO)
                                  │
                          HTTPS Load Balancer
                                  │
╔═════════════════════════════════╪══════════════ YOUR GCP PROJECT  (your VPC) ═══════════════╗
║                                  ▼                                                           ║
║  ┌──────────────────────── GKE cluster — the Zipline platform ───────────────────────────┐  ║
║  │  namespace: zipline-system   (control plane & tooling)                                 │  ║
║  │  ┌────────┐    ┌───────────────┐    ┌────────────────────────┐                         │  ║
║  │  │   UI   │───▶│ Orchestration │───▶│    Crucible Gateway     │                         │  ║
║  │  └────────┘    │     Hub       │    │  submits & monitors jobs│                         │  ║
║  │                └───────┬───────┘    └────────────┬───────────┘                         │  ║
║  │  ┌───────────────┐     │                         │ creates                             │  ║
║  │  │ Spark History │     │             ┌───────────▼───────────┐                          │  ║
║  │  │ Server        │     │             │ Spark & Flink Operators│                         │  ║
║  │  │ Loki+promtail │     │             └───────────┬───────────┘                          │  ║
║  │  │ Eval          │     │                         │ launches                            │  ║
║  │  └───────────────┘     │   namespace: zipline-default (compute)                        │  ║
║  │                        │   ┌─────────────────────▼──────────────────────┐             │  ║
║  │                        │   │  Spark jobs (batch)  ·  Flink jobs (stream) │             │  ║
║  │                        │   └──────────────────┬──────────────────────────┘            │  ║
║  └────────────────────────┼──────────────────────┼────────────────┬──────────────────────┘  ║
║         reads DB creds ┌───┘   stores metadata    │ read/write data │ pull container images    ║
║                        ▼          │               ▼                 ▼                          ║
║  ┌──────────────┐  ┌───────────┐  │  ┌──────────────────────────────────────┐  ┌────────────┐ ║
║  │   Secret     │◀─┤  Cloud    │◀─┘  │ Cloud   │ BigQuery│ Bigtable│ Pub/Sub │  │  Artifact  │ ║
║  │   Manager    │  │   SQL     │     │ Storage │ offline │ online  │ feature │  │  Registry  │ ║
║  │  credentials │  │ platform  │     │ data/   │ store   │ serving │ logging │  │ container  │ ║
║  └──────▲───────┘  │ metadata  │     │ logs/   │         │         │  → BQ   │  │  images    │ ║
║         │          └───────────┘     │ ckpts   │         │         │         │  └─────┬──────┘ ║
║         │ upstream Docker Hub token  └──────────────────────────────────────┘        │        ║
║         └─────────────────────────────────────────────────────────────────────────────┘        ║
║                                              (Artifact Registry pulls upstream images using     ║
║                                               a token stored in Secret Manager)                 ║
║                                                                                              ║
║  Networking: private VPC + subnet · Cloud NAT (egress only) · Private Services Access        ║
║             (private Cloud SQL / Bigtable) · Workload Identity (no static service-account keys)║
╚══════════════════════════════════════════════════════════════════════════════════════════════╝
```

```mermaid
flowchart TB
  users([Your users])
  iap[Identity-Aware Proxy<br/>SSO / access control]
  lb[HTTPS Load Balancer]
  users --> iap --> lb

  subgraph project["YOUR GCP PROJECT — your VPC"]
    subgraph GKE["GKE cluster — the Zipline platform"]
      subgraph sys["namespace: zipline-system — control plane & tooling"]
        nginx[nginx proxy]
        ui[Zipline UI]
        hub[Orchestration Hub<br/>schedules & tracks jobs]
        eval[Eval service]
        shs[Spark History Server<br/>job history & logs]
        logs[Loki + promtail<br/>log collection]
        gw[Crucible Gateway<br/>submits & monitors jobs]
        ops[Spark & Flink operators]
      end
      subgraph compute["namespace: zipline-default — compute jobs"]
        spark[Spark jobs<br/>batch feature compute]
        flink[Flink jobs<br/>streaming feature compute]
      end
    end

    subgraph gcp["GCP managed services — in your project"]
      gcs[(Cloud Storage<br/>data · logs · checkpoints)]
      bq[(BigQuery<br/>offline feature store)]
      bt[(Bigtable<br/>online feature serving)]
      ps[(Pub/Sub<br/>feature logging)]
      sql[(Cloud SQL<br/>platform metadata)]
      ar[(Artifact Registry<br/>container images)]
      sm[(Secret Manager<br/>credentials)]
    end
  end

  lb --> nginx
  nginx --> ui --> hub
  hub -->|submit jobs| gw
  gw -->|creates CRDs| ops
  ops -->|launches| spark
  ops -->|launches| flink

  %% platform data & credentials
  hub -->|stores metadata| sql
  hub -->|reads DB credentials| sm
  GKE -. pull container images .-> ar
  ar -. reads upstream token .-> sm

  %% compute data flows
  spark --> gcs
  spark --> bq
  spark --> bt
  flink --> gcs
  flink --> bt
  ps --> bq
```

## What runs in the GKE cluster

The Zipline application and all compute run as Kubernetes workloads, split into two namespaces.

### `zipline-system` — control plane & tooling

| Component | What it does |
|---|---|
| **Zipline UI** | The web interface your team uses to define and monitor features. |
| **Orchestration Hub** | Schedules feature pipelines, tracks job history, and drives the UI. |
| **Crucible Gateway** | Submits and monitors Spark/Flink jobs; proxies the Spark/Flink/History UIs. |
| **Spark History Server** | Post-run Spark UI — inspect completed jobs, stages, and logs. |
| **Eval** | Runs feature evaluation / validation workloads. |
| **Loki + promtail** | Collects and stores job and platform logs inside the cluster. |
| **Spark & Flink operators** | Turn job submissions into running Spark/Flink pods. |

The UI and Hub sit behind a single **nginx proxy**, so there's one entry point for the platform.

### `zipline-default` — compute

| Component | What it does |
|---|---|
| **Spark jobs** | Batch feature computation (driver + autoscaling executors). |
| **Flink jobs** | Streaming feature computation (JobManager + TaskManagers). |

Compute scales elastically — you don't size clusters or pick machine types. Jobs scale up on
demand and release nodes when idle, using spot/preemptible capacity where appropriate.

## GCP managed services Zipline uses

All of these live in **your** project. Zipline accesses them using **Workload Identity** — pods
are granted access through GCP service accounts, so there are **no static keys** to manage.

| Service | What Zipline uses it for |
|---|---|
| **Cloud Storage (GCS)** | Stores your data, Spark event logs, Flink checkpoints, and artifacts. |
| **BigQuery** | Offline feature store / warehouse, and the destination for logged features. |
| **Bigtable** | Low-latency online store for serving features to your applications. |
| **Pub/Sub** | Streams logged feature-serving responses into BigQuery. |
| **Cloud SQL** | Stores platform metadata (the Hub's job index). The Hub reads its DB credentials from Secret Manager. |
| **Artifact Registry** | Hosts the platform's container images. Mirrors upstream images using a token stored in Secret Manager. |
| **Secret Manager** | Holds credentials — the Cloud SQL password and the image-mirror token. |

## Network & security

- **Everything runs in your VPC.** The platform deploys into your GCP project on a private
  VPC and subnet. Your data stays in your project.
- **Private connectivity.** Cloud SQL and Bigtable are reached over **Private Services Access**
  (private IPs), not the public internet.
- **Egress only.** Outbound traffic (e.g., pulling container images) goes through **Cloud NAT**;
  there are no public ingress paths to your data services.
- **Authenticated access.** Your users reach the UI through an **Identity-Aware Proxy**, so
  access is gated by your Google identity / group membership.
- **No static keys.** In-cluster workloads authenticate to GCP services via **Workload
  Identity**, eliminating long-lived service-account keys.
