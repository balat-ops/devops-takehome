# Operations Answers

## 1. EKS upgrade from 1.33 to 1.35 with zero downtime

I would use a staged, one-minor-version-at-a-time upgrade: 1.33 → 1.34 → 1.35.

For each version:

1. Review deprecated APIs, workload compatibility, add-on compatibility and release notes. Back up critical cluster configuration and validate the upgrade in staging.
2. Upgrade the EKS control plane to the next minor version.
3. Update VPC CNI, CoreDNS, kube-proxy, EBS CSI and EFS CSI to compatible versions. Verify add-on health.
4. Upgrade managed node groups or Karpenter-managed nodes using rolling replacement. Maintain sufficient spare capacity, use PodDisruptionBudgets and verify workloads become Ready before removing old nodes.
5. Run application, networking, storage and DNS smoke tests before proceeding to the next minor version.

**Top three risks:**
- Deprecated APIs or incompatible controllers/operators causing workload failures.
- Add-on or CNI incompatibility causing networking, DNS or storage disruption.
- Insufficient capacity or restrictive PDBs preventing safe node replacement.

Zero downtime depends on application-level redundancy, readiness probes, graceful termination and sufficient capacity; the upgrade procedure alone cannot guarantee it.

## 2. Spot reclaims causing 3 AM KubeNodeUnreachable alert storms

I would use event-aware alerting rather than suppressing all node-unreachable alerts.

- Consume EC2 Spot interruption warnings through EventBridge and use AWS Node Termination Handler or Karpenter interruption handling to cordon and drain affected nodes.
- Correlate interruption events with node lifecycle and Kubernetes events. Group related alerts by cluster and node to prevent duplicate paging.
- Inhibit or temporarily downgrade a node-unreachable alert only when a matching spot interruption is confirmed and workloads are rescheduling successfully.
- Continue monitoring service availability, replica readiness, PDB health and failed evictions.
- Page immediately for customer-impacting service degradation, failed replacement capacity, PDB violations or unexpected unreachable on-demand nodes.
- Retain a sustained node-unreachable alert for nodes without a matching interruption event.

This avoids false-positive pages during expected spot reclamation without masking genuine infrastructure failures.

## 3. Cloudflare mobile LCP is 5 seconds; HTML caching may not work

I would diagnose this in the following order:

1. Measure mobile Real User Monitoring and synthetic performance. Identify the LCP element and separate DNS, connection, TTFB, resource-load and render delays.
2. Inspect response headers using browser DevTools and `curl -I`. Check `CF-Cache-Status`, `Age`, `Cache-Control`, `ETag` and `Vary`.
3. If HTML consistently returns `DYNAMIC` or `BYPASS`, inspect Cloudflare Cache Rules, their order, cookies, query strings and origin cache headers. Check whether an earlier rule or application session cookie prevents caching.
4. Compare cache behavior for HTML, static assets and authenticated pages. Review origin logs and response times to identify slow backend requests.
5. Cache eligible public HTML with an appropriate edge TTL and purge strategy. Bypass personalized or authenticated content. Cache versioned CSS, JavaScript and images aggressively.
6. Optimize the actual LCP element: compress and resize images, use modern formats, preload the hero image where appropriate, and reduce render-blocking resources.

Validate changes using repeated mobile tests and response headers, not just a single Lighthouse score.

## 4. EKS application secrets: compare two approaches and choose one

**Option A — External Secrets Operator (ESO):** Retrieves secrets from AWS Secrets Manager and synchronizes them into Kubernetes Secrets. It supports centralized secret storage, IAM-based access and automated refresh. The trade-off is that secrets exist as Kubernetes Secret objects and require appropriate encryption and RBAC protection.

**Option B — Secrets Store CSI Driver:** Mounts secrets from an external provider such as AWS Secrets Manager into pods as files. This reduces reliance on Kubernetes Secret objects, but requires CSI driver/provider operations and application support for file-based secrets.

**My choice:** For a startup operating multiple production EKS clusters, I would choose ESO backed by AWS Secrets Manager, KMS encryption and IRSA.

I would use least-privilege IAM roles per workload, restrict namespace access through RBAC, enable audit logging and secret rotation, and avoid static AWS credentials. This provides centralized management and a consistent integration pattern across clusters.
