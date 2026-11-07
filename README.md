# Enterprise Bot — DevOps Take-Home Assignment

## Overview

This repository contains a containerized Python HTTP service, a configurable Helm chart, an automated Kubernetes setup script, and a Kubernetes troubleshooting lab.

The project demonstrates Docker multi-stage builds, Kubernetes deployments, Helm templating, ConfigMap-based configuration, health checks, container security and infrastructure troubleshooting.

## Repository Structure

```text
enterprisebot-devops/
├── setup.sh
├── README.md
├── ANSWERS.md
├── service/
│   ├── app.py
│   ├── Dockerfile
│   ├── requirements.txt
│   └── .dockerignore
├── chart/
│   ├── Chart.yaml
│   ├── values.yaml
│   └── templates/
└── lab/
    ├── scenario.sh
    ├── cluster-state/
    ├── broken-chart/
    ├── FINDINGS.md
    └── part4-session.log
```

## Prerequisites

The following tools are required:

- Docker
- kind
- kubectl
- Helm

The setup script checks that all required commands are available before execution.

## Part 1 — Containerized Service

The application is implemented in Python using the standard-library HTTP server.

### Endpoints

| Endpoint | Behaviour |
|---|---|
| `GET /` | Returns application name, version and pod hostname as JSON |
| `GET /healthz` | Returns HTTP 200 when the service is healthy |

### Application configuration

The application uses two configurable values:

- `APP_NAME`
- `VERSION`

These values are supplied through a Kubernetes ConfigMap. The application reads the mounted ConfigMap files and uses environment variables as fallback values.

### Docker design

The Dockerfile uses a multi-stage build with the pinned base image:

`python:3.12.12-slim-bookworm`

The runtime stage:
- Runs as a non-root user named `appuser`.
- Uses an isolated Python virtual environment.
- Exposes port `8080`.
- Runs Python with unbuffered output for container logging.

The `.dockerignore` excludes Python caches, virtual environments, environment files, Git metadata and log files from the Docker build context.

## Part 2 — Helm Chart

The Helm chart deploys the application with two replicas by default.

### Features

- Configurable image repository, tag and pull policy.
- ConfigMap for `APP_NAME` and `VERSION`.
- Kubernetes ClusterIP Service.
- Ingress configured for `demo.local`.
- Liveness and readiness probes using `/healthz`.
- CPU and memory requests and limits.
- Non-root container execution.
- Read-only root filesystem.
- Privilege escalation disabled.
- Linux capabilities dropped.
- RuntimeDefault seccomp profile.

### Resource allocation

| Resource | Request | Limit |
|---|---:|---:|
| CPU | 100m | 500m |
| Memory | 64Mi | 128Mi |

These values provide a modest resource baseline for a lightweight Python HTTP service.

The CPU limit allows temporary processing bursts while preventing unlimited CPU consumption. The memory limit bounds container memory usage, while the request provides a baseline for Kubernetes scheduling.

These values are initial estimates for the demonstration workload. Production values should be validated using load testing, actual utilization, application latency and restart metrics.

## Part 3 — Local Kubernetes Setup

Run the following commands from the repository root:

```bash
chmod +x setup.sh
./setup.sh
```

The setup script performs the following operations:

1. Checks Docker, kind, kubectl and Helm availability.
2. Creates or reuses a kind cluster named `demo`.
3. Configures host port mappings for HTTP and HTTPS ingress traffic.
4. Installs ingress-nginx using Helm.
5. Builds the application Docker image.
6. Loads the image into the kind cluster.
7. Installs or upgrades Helm release `demo` in namespace `demo`.
8. Displays the resulting Kubernetes resources.

The script uses `helm upgrade --install` and checks whether the kind cluster already exists, allowing it to be executed repeatedly.

### Verify the deployment

Check the Kubernetes resources:

```bash
kubectl get pods -n demo
kubectl get services -n demo
kubectl get ingress -n demo
```

Check the application health endpoint:

```bash
curl -i -H 'Host: demo.local' http://127.0.0.1/healthz
```

Check the application response:

```bash
curl -H 'Host: demo.local' http://127.0.0.1/
```

Expected JSON structure:

```json
{
  "app": "enterprisebot-demo",
  "version": "1.0.0",
  "pod": "<pod-hostname>"
}
```

Alternatively, add the following entry to `/etc/hosts`:

```text
127.0.0.1 demo.local
```

Then access the application using:

```bash
curl http://demo.local/
curl http://demo.local/healthz
```

### Helm validation

Run Helm lint:

```bash
helm lint chart
```

Render the chart:

```bash
helm template demo chart -n demo
```

Test configurable values:

```bash
helm template demo chart \
  --set replicaCount=3 \
  --set config.appName=test-app \
  --set config.version=2.0.0
```

The rendered Deployment and ConfigMap should reflect the supplied overrides.

## Part 4 — Kubernetes Troubleshooting Lab

The lab deploys a gateway, backend, worker, reporter, metrics service and a one-shot migration Job.

The supplied application image is:

`docker.io/ebinterview/eb-debug-app:1.0.1`

The investigation and implemented fixes are documented in:

`lab/FINDINGS.md`

The terminal investigation recording is available at:

`lab/part4-session.log`

Run the verification command from the lab directory:

```bash
cd lab
./scenario.sh verify
```

### Known limitation

During investigation, the Reporter application consistently returned:

`parse pod list: unexpected end of JSON input`

The Kubernetes API returned valid PodList JSON, but the response measured 48,048 bytes. Binary inspection indicated an apparent 32,768-byte response-reading limit in the supplied Reporter executable.

Truncating the API response at 32,768 bytes produced invalid JSON.

The supplied image repository and tag were preserved. The binary was not rebuilt or replaced, and no compliant Helm-only workaround was demonstrated.

This issue remains documented as unresolved rather than being represented as a successful chart fix.

## Deliberately skipped items and associated risks

The following items were not implemented as part of this local demonstration:

### TLS and certificate management

The local application is exposed over HTTP through the kind ingress controller.

Production deployments should use TLS, certificate management and an approved certificate issuer. Without TLS, application traffic is not encrypted in transit.

### Horizontal Pod Autoscaling

The chart uses a configurable static replica count and does not include HPA.

Production scaling should be based on CPU, memory and application-specific metrics. Without autoscaling, the service may not respond optimally to traffic spikes.

### CI/CD pipeline

A CI/CD pipeline was not included.

Production workflows should automate tests, Docker builds, Helm validation, vulnerability scanning and controlled deployment.

### Image vulnerability scanning

Trivy or an equivalent container image scanner was not integrated.

Production pipelines should scan images and enforce vulnerability policies before deployment.

### External secrets management

The demonstration application does not require application secrets, so an external secrets manager was not integrated.

Production applications requiring credentials should use an approved secrets-management solution rather than embedding secrets in images or source code.

### Persistent storage

Persistent volumes were not configured because the demonstration service is stateless.

Applications that maintain persistent data would require an appropriate storage design, backup policy and recovery procedure.

### Reporter binary limitation

The supplied lab image appears to have a hardcoded response-reading limitation. The issue remains unresolved because the required image must be preserved and no compliant Helm-only workaround was established.

## Production-readiness improvements

Before using this design in production, I would:

1. Add CI/CD automation for application tests, Docker builds and Helm validation.
2. Integrate Trivy image scanning and fail pipelines according to HIGH and CRITICAL vulnerability policies.
3. Push images to a private registry and use immutable image digests.
4. Configure TLS using cert-manager and an approved certificate issuer.
5. Configure HPA and PodDisruptionBudgets according to workload requirements.
6. Integrate centralized logging, Prometheus metrics and Grafana dashboards.
7. Define alerts for availability, latency, pod restarts and resource saturation.
8. Apply Kubernetes NetworkPolicies and least-privilege RBAC.
9. Use GitOps for controlled deployment, version tracking and rollback.
10. Validate resource requests and limits through load testing.
11. Add automated application tests and deployment smoke tests.
12. Establish backup, disaster recovery and operational runbooks where applicable.

## How I used AI

I used ChatGPT and Kiro with Claude Sonnet 4.5 as AI assistants during this assignment.

AI assistance was used for:
- Understanding Kubernetes and Helm errors.
- Exploring troubleshooting approaches.
- Reviewing configuration and deployment manifests.
- Interpreting application logs and command output.
- Structuring technical explanations and documentation.

I manually executed the commands, inspected Kubernetes resources, reviewed the configuration and validated the resulting behaviour.

I also reviewed AI-generated troubleshooting suggestions against actual command output and rejected hypotheses that were not supported by evidence.

The Reporter binary investigation identified an apparent response-reading limitation. This has been documented as unresolved rather than presented as a successful Helm fix.

I am responsible for understanding, validating and explaining the submitted implementation.
