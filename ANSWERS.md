# Part 5 — Written Question

## Q1. Migrating 40 ingress-nginx Ingress objects to Gateway API without downtime

I would use a gradual migration strategy rather than replacing all 40 Ingress objects at once.

**1. Inventory and compatibility assessment**

- List all 40 Ingress resources, hosts, paths, TLS settings, annotations and backend services.
- Identify ingress-nginx-specific annotations and features that need Gateway API equivalents.
- Group routes by application and migration complexity.

**2. Prepare Gateway API**

- Install the Gateway API CRDs and a compatible Gateway controller.
- Configure GatewayClass, Gateway listeners, TLS certificates and required policies.
- Validate controller health before moving application traffic.

**3. Migrate incrementally**

- Create HTTPRoute resources corresponding to existing Ingress rules.
- Initially keep the existing ingress-nginx routes active.
- Validate routing, authentication, headers, redirects, TLS and backend connectivity using test requests.
- Migrate a small application group first, then progressively move the remaining routes.

**4. Monitor and validate**

- Compare HTTP response codes, latency, error rates and application logs.
- Verify external access and critical application workflows.
- Gradually shift traffic to the Gateway implementation.

**5. Rollback and completion**

- Keep the original Ingress resources and controller available during migration.
- If issues occur, route traffic back to ingress-nginx.
- Remove old Ingress resources only after all routes have passed validation and the rollback window has closed.

This approach minimizes risk by keeping the existing routing path available until the replacement is proven stable.
