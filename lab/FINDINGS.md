# Part 4 — Kubernetes Debug Lab Findings

## Investigation Environment

- Kubernetes: kind
- Namespace: `debug-lab`
- Helm chart: `lab/broken-chart`
- Required image: `docker.io/ebinterview/eb-debug-app:1.0.1`
- Investigation recording: `lab/part4-session.log`

The original `scenario.sh` and `cluster-state/` files were preserved.

---

## Defect 1 — Migration Job restart policy

**Symptom**

The initial deployment failed while creating the migration Job:

```text
Job.batch "migrate" is invalid:
spec.template.spec.restartPolicy: Required value:
valid values: "OnFailure", "Never"
```

**Cause**

The Job template used `restartPolicy: Always`. Kubernetes Jobs support only `Never` or `OnFailure`.

**Fix**

Changed the migration Job restart policy to:

```yaml
restartPolicy: Never
```

**How I found it**

Inspected the output of `./scenario.sh up`, identified the Job validation error and inspected `migrate-job.yaml`. After correcting the restart policy, another container security error exposed the missing numeric user ID, which was corrected with `runAsUser: 10001`.

**Verification**

The migration Job subsequently completed successfully with `1/1` completion.

---

## Defect 2 — Non-numeric container user with runAsNonRoot

**Symptom**

Kubernetes reported:

```text
container has runAsNonRoot and image has non-numeric user (nonroot),
cannot verify user is non-root
```

The affected application containers entered `CreateContainerConfigError`.

**Cause**

The Deployment templates enabled `runAsNonRoot: true`, but did not specify a numeric `runAsUser`. Kubernetes could not verify the image's named user as non-root.

**Fix**

Added the numeric user ID to the affected application Deployment security contexts:

```yaml
runAsNonRoot: true
runAsUser: 10001
```

The same numeric user was also configured for the migration Job.

**How I found it**

Used `kubectl describe pod` to inspect container events and searched all Deployment templates for `runAsNonRoot`.

**Verification**

The application Pods progressed from `CreateContainerConfigError` to Running after the numeric UID was configured.

---

## Defect 3 — Worker cache and port configuration

**Symptom**

Worker logs reported:

```text
FATAL: worker could not initialise its cache:
mkdir /var/cache/app: read-only file system
```

The worker readiness probe also failed because it checked port `8080`, while the application listened on `8081`.

**Cause**

The worker used `readOnlyRootFilesystem: true` without a writable cache directory. Its configured container and readiness ports also did not match the application's listening port.

**Fix**

Added an `emptyDir` volume mounted at `/var/cache/app` and configured the worker port as `8081` in `values.yaml`. Updated the container port and readiness probe to use `.Values.worker.port`.

**How I found it**

Inspected worker logs and used `kubectl describe pod` to identify the filesystem and readiness failures. Compared the application's listening port with the chart configuration.

**Verification**

The worker Pod reached `1/1 Running` with zero restarts, a writable cache mount and a readiness probe on port `8081`.

---

## Defect 4 — Backend port mismatch

**Symptom**

Backend logs showed that the application listened on port `8081`, while the Deployment readiness probe and Service target were configured for port `8080`.

The readiness check failed with connection refused.

**Cause**

The chart's backend port configuration did not match the port used by the supplied application image.

**Fix**

Added `backend.port: 8081` to `values.yaml` and updated the backend container port, readiness probe and Service targetPort to use `.Values.backend.port`. Kept the Service-facing port at `8080`.

**How I found it**

Compared backend application logs with the rendered Deployment and Service configuration. Used Kubernetes endpoint inspection to validate the resulting Service target.

**Verification**

The backend reached `1/1 Ready`, and the Service endpoint pointed to port `8081`.

---

## Defect 5 — Gateway port and backend URL configuration

**Symptom**

The gateway initially failed readiness because its configured port did not match the application listening port.

After correcting the port, gateway logs showed:

```text
readiness failed: backend not reachable:
GET http://backend.default.svc:8080/healthz
lookup backend.default.svc on 10.96.0.10:
no such host
```

**Cause**

There were two configuration mismatches:
- Gateway was configured for port `8080`, while the application listened on `8081`.
- `BACKEND_URL` referenced the wrong namespace.

**Fix**

Configured `gateway.port: 8081` and updated the gateway container port, readiness probe and Service targetPort.

Corrected `BACKEND_URL` to:

```text
http://backend.debug-lab.svc.cluster.local:8080
```

**How I found it**

Inspected gateway logs, compared the listening port with the chart configuration and used the DNS error to identify the incorrect backend namespace.

**Verification**

The gateway reached `1/1 Ready`. Its logs showed successful readiness requests returning HTTP 200.

---

## Defect 6 — Reporter ServiceAccount binding and API response limitation

**Symptom**

Reporter initially failed to list Pods. Its Deployment referenced the `reporter` ServiceAccount, while the original RoleBinding referred to the `default` ServiceAccount.

After correcting the binding, Reporter continued returning:

```text
pod list failed: parse pod list: unexpected end of JSON input
GET /healthz -> 503
```

**Cause**

The original RBAC binding referred to the wrong ServiceAccount.

Further investigation also identified an apparent response-size limitation in the supplied Reporter binary. The namespace-scoped Kubernetes API response measured 48,048 bytes, while binary inspection indicated a possible 32,768-byte response-reading limit.

**Fix**

Corrected the RBAC subject to reference the `reporter` ServiceAccount. The RBAC configuration was subsequently changed to ClusterRole and ClusterRoleBinding during investigation.

The supplied binary was not rebuilt or replaced. No compliant Helm-only workaround for the apparent response-size limitation was established.

**How I found it**

Used `kubectl describe pod`, Reporter logs, `kubectl auth can-i`, Kubernetes API requests and static inspection of the extracted application binary.

A separate diagnostic Pod using the Reporter ServiceAccount successfully retrieved valid PodList JSON over HTTPS. The full response measured 48,048 bytes. Truncating it at 32,768 bytes produced invalid JSON.

**Verification**

RBAC permission checks returned `yes`. However, Reporter remained unready and its `/report` endpoint continued returning HTTP 503.

This defect is therefore **partially corrected but not fully resolved**. The apparent binary response-size limitation remains unresolved.

---

## Final Investigation Status

Five application configuration/security fixes were implemented and verified through Kubernetes behaviour.

The Reporter ServiceAccount binding was corrected, but Reporter verification remained unsuccessful because of the apparent response-reading limitation in the supplied binary.

The required image repository and tag were preserved. No application workloads were deleted or disabled to hide failures.

The final `./scenario.sh verify` result must be recorded separately using its actual output. No claim of complete verification is made while Reporter remains unhealthy.


PASS migrate Job completed
PASS deployment backend: 1/1 ready
PASS deployment gateway: 1/1 ready
PASS deployment worker: 1/1 ready
FAIL deployment reporter: 0/1 ready
PASS deployment metrics: 1/1 ready
PASS no pods in CrashLoopBackOff
PASS ServiceAccount debug-lab/reporter can list pods
PASS backend answers on http://backend:8080/healthz
PASS gateway /status reports backend=ok
FAIL reporter /report does not return a pod count

Result: 9 passing, 2 failing.
