# Kubernetes Troubleshooting Assessment

## 1. Objective and constraints

This document records the diagnosis and remediation of the intentional
faults in `troubleshoot/broken-app.yaml`.

The goal was to restore the web application, its Service connectivity,
and the AI inference workload while preserving the cluster's scheduling
configuration and network security posture.

The assessment constraints were:

-   Keep the `default-deny` NetworkPolicy.
-   Do not remove or change the spot, on-demand, or GPU node labels.
-   Do not remove the GPU node taint.
-   Correct the workloads and policies rather than weakening node or
    network security controls.

## 2. Symptoms, diagnosis, root causes, and fixes

  --------------------------------------------------------------------------------------------------------------------------------------------------------------------
  \#             Symptom / observed   Diagnosis                                                        Root cause                          Remediation
                 failure                                                                                                                   
  -------------- -------------------- ---------------------------------------------------------------- ----------------------------------- ---------------------------
  1              Nginx container      Inspect pod status and events with                               The Deployment specified            Changed the image to
                 cannot be pulled;    `kubectl get pods -n troubleshoot` and                           `nginx:1.25.99`, an                 `nginx:1.27-alpine`.
                 web pods cannot      `kubectl describe pod <pod> -n troubleshoot`.                    invalid/unavailable image tag.      
                 start.                                                                                                                    

  2              Web pods cannot be   Inspect pod events with                                          Each web pod requested and was      Set memory request to
                 scheduled on the     `kubectl describe pod <pod> -n troubleshoot`; inspect requests   limited to `16Gi` of memory.        `128Mi` and memory limit to
                 available worker     and limits in the Deployment.                                                                        `256Mi`; CPU request and
                 capacity.                                                                                                                 limit remain `100m` and
                                                                                                                                           `500m`.

  3              Nginx                Run `kubectl describe pod <pod> -n troubleshoot` and inspect     Both HTTP probes targeted port      Changed both liveness and
                 liveness/readiness   probe events and the container port.                             `8080`, but Nginx listens on port   readiness probe ports to
                 checks fail and pods                                                                  `80`.                               `80`.
                 do not become                                                                                                             
                 healthy.                                                                                                                  

  4              The web pod cannot   Inspect the pod events and compare                               The ConfigMap is named              Changed the volume's
                 mount its HTML       `kubectl get configmap -n troubleshoot` with the Deployment's    `web-config`, but the Deployment    ConfigMap reference to
                 ConfigMap volume.    volume reference.                                                referenced `web-conf`.              `web-config`.

  5              The `web-svc`        Compare `kubectl get pods -n troubleshoot --show-labels` with    The Service selector was            Changed the Service
                 Service has no       `kubectl describe service web-svc -n troubleshoot`.              `app=webapp`; the web pods are      selector to `app=web`.
                 matching endpoints.                                                                   labelled `app=web`.                 

  6              Service traffic      Inspect the Service port mapping and the container's listening   The Service `targetPort` was        Changed `targetPort` to
                 cannot reach the     port using `kubectl describe service web-svc -n troubleshoot`.   `8080`; Nginx listens on port `80`. `80` (Service port remains
                 Nginx container                                                                                                           `80`).
                 port.                                                                                                                     

  7              The AI inference pod Inspect                                                          The pod selector used               Changed the node selector
                 remains Pending      `kubectl describe pod -n troubleshoot -l app=ai-inference`;      `node-type=gpu`, which did not      to
                 instead of running   inspect node labels with `kubectl get nodes --show-labels`.      match the actual label              `acme.io/node-type: gpu`.
                 on the GPU node.                                                                      `acme.io/node-type=gpu`.            

  8              The AI inference pod Inspect the GPU node taints with                                 The GPU node has the taint          Added a toleration with key
                 cannot be scheduled  `kubectl describe node <gpu-node>` and pod scheduling events.    `nvidia.com/gpu=true:NoSchedule`;   `nvidia.com/gpu`, operator
                 onto the GPU node                                                                     the pod had no matching toleration. `Equal`, value `"true"`,
                 even after                                                                                                                and effect `NoSchedule`.
                 correcting its                                                                                                            
                 selector.                                                                                                                 

  9              The in-cluster smoke Inspect policies with                                            The default-deny policy blocks      Retained default-deny and
                 client cannot reach  `kubectl get networkpolicy -n troubleshoot` and                  ingress and egress unless           added the two
                 the web Service      `kubectl describe networkpolicy default-deny -n troubleshoot`;   explicitly allowed. The smoke       least-privilege allow
                 under the            inspect smoke Job logs.                                          client needs DNS egress, egress to  policies described below.
                 default-deny policy.                                                                  the web pods, and corresponding     
                                                                                                       ingress to the web pods.            
  --------------------------------------------------------------------------------------------------------------------------------------------------------------------

## 3. NetworkPolicy remediation

The original `default-deny` NetworkPolicy remains in place. It selects
all pods in the `troubleshoot` namespace and applies both ingress and
egress isolation.

Two additional policies provide only the connectivity required by the
smoke test.

### 3.1 `allow-web-from-smoke`

-   Selects web pods labelled `app=web`.
-   Allows ingress from pods labelled `app=smoke-client`.
-   Restricts allowed application traffic to TCP port `80`.

### 3.2 `allow-smoke-egress`

-   Selects smoke-client pods labelled `app=smoke-client`.
-   Allows egress to web pods labelled `app=web` on TCP port `80`.
-   Allows DNS egress to pods labelled `k8s-app=kube-dns` in the
    `kube-system` namespace on UDP and TCP port `53`.

These rules preserve the default-deny baseline while allowing the smoke
test's required DNS lookup and HTTP request path.

## 4. GPU workload placement

The GPU worker is labelled:

``` text
acme.io/node-type=gpu
```

It carries this taint:

``` text
nvidia.com/gpu=true:NoSchedule
```

The corrected AI inference pod specification uses the matching selector
and toleration:

``` yaml
nodeSelector:
  acme.io/node-type: gpu
tolerations:
  - key: nvidia.com/gpu
    operator: Equal
    value: "true"
    effect: NoSchedule
```

The node labels and taint are not removed or modified. The verifier
checks that the AI inference pod is running on the GPU-labelled node and
that the GPU taint remains present.

## 5. Diagnosis command reference

Run these commands from the toolbox container, or from a shell that has
the correct Kubernetes context.

### 5.1 Pod status, scheduling, and events

``` bash
kubectl get pods -n troubleshoot -o wide
kubectl describe pod <pod-name> -n troubleshoot
kubectl get events -n troubleshoot --sort-by=.lastTimestamp
```

### 5.2 Container logs

``` bash
kubectl logs <pod-name> -n troubleshoot
```

### 5.3 Deployment and resource configuration

``` bash
kubectl get deployment web -n troubleshoot -o yaml
kubectl describe deployment web -n troubleshoot
kubectl get deployment ai-inference -n troubleshoot -o yaml
```

### 5.4 ConfigMap and volume references

``` bash
kubectl get configmap -n troubleshoot
kubectl describe pod <web-pod-name> -n troubleshoot
```

Confirm that the referenced ConfigMap exists in the same namespace and
that the volume and volumeMount names match.

### 5.5 Service selectors and endpoints

``` bash
kubectl get pods -n troubleshoot --show-labels
kubectl describe service web-svc -n troubleshoot
kubectl get endpoints web-svc -n troubleshoot
```

The Service selector must match the web pod labels, and the target port
must match the Nginx container port.

### 5.6 Node labels, taints, and GPU scheduling

``` bash
kubectl get nodes --show-labels
kubectl describe nodes
kubectl describe pod -n troubleshoot -l app=ai-inference
```

Check that the selector matches `acme.io/node-type=gpu` and that the pod
tolerates `nvidia.com/gpu=true:NoSchedule`.

### 5.7 NetworkPolicy and smoke-test diagnosis

``` bash
kubectl get networkpolicy -n troubleshoot
kubectl describe networkpolicy default-deny -n troubleshoot
kubectl describe networkpolicy allow-web-from-smoke -n troubleshoot
kubectl describe networkpolicy allow-smoke-egress -n troubleshoot
kubectl get job smoke-test -n troubleshoot
kubectl logs job/smoke-test -n troubleshoot
```

## 6. Applying the corrected manifest

The corrected resources are maintained in `troubleshoot/fixed-app.yaml`.

From the repository root, with a working Kubernetes context:

``` bash
bash troubleshoot/prepare.sh
kubectl apply -f troubleshoot/fixed-app.yaml
bash troubleshoot/verify.sh
```

The assessment workflow also applies the fixed manifest and invokes the
verifier through:

``` bash
docker compose exec toolbox bash /workspace/scripts/30-troubleshoot.sh
```

## 7. Verification performed

`troubleshoot/verify.sh` performs seven checks and prints `PASS` only if
all checks succeed:

1.  **Default-deny policy:** confirms `default-deny` still exists in the
    `troubleshoot` namespace.
2.  **Node labels and taints:** confirms at least two spot nodes, at
    least one on-demand node, a GPU-labelled node, and the GPU taint.
3.  **Web Deployment:** waits for the `web` Deployment rollout.
4.  **AI inference Deployment:** waits for the `ai-inference` Deployment
    rollout.
5.  **GPU placement:** confirms the AI inference pod is scheduled on the
    GPU-labelled node.
6.  **Service endpoints:** confirms `web-svc` has ready endpoints.
7.  **In-cluster smoke test:** creates the smoke-test Job and waits for
    it to complete; on failure or timeout, the script prints the Job
    logs.

The troubleshooting assessment was run against the local k3d cluster and
the verifier completed all seven checks with:

``` text
PASS
```

## 8. Files involved

  -----------------------------------------------------------------------
  File                                Role
  ----------------------------------- -----------------------------------
  `troubleshoot/broken-app.yaml`      Original manifest containing the
                                      intentional faults.

  `troubleshoot/fixed-app.yaml`       Corrected web, AI inference,
                                      Service, and NetworkPolicy
                                      resources.

  `troubleshoot/prepare.sh`           Prepares the required node labels
                                      and taints.

  `troubleshoot/smoke-job.yaml`       Defines the in-cluster smoke-test
                                      Job.

  `troubleshoot/verify.sh`            Runs the seven acceptance checks.

  `scripts/30-troubleshoot.sh`        Applies the corrected manifest and
                                      runs the verifier as part of the
                                      assessment workflow.
  -----------------------------------------------------------------------

## 9. Lessons learned

-   Validate image references before deploying workloads.
-   Size resource requests and limits to fit the intended cluster
    capacity.
-   Make probe ports consistent with the application listener.
-   Keep ConfigMap references and volume names consistent.
-   Match Service selectors to pod labels and Service target ports to
    container ports.
-   Use the actual node labels and tolerations required by scheduling
    constraints.
-   Preserve default-deny network isolation and add only the necessary
    allow rules.
-   Use pod events, logs, rollout status, Service endpoints, and
    NetworkPolicy inspection to isolate Kubernetes failures.
