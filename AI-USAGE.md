# AI Usage Disclosure

AI assistance was used during development to support troubleshooting, review configuration, and improve documentation. All suggested commands and configuration changes were reviewed and validated against the running environment before being committed.

## Tools and Tasks

AI assistance was used for:
- Troubleshooting Kubernetes, k3d, and Calico installation issues.
- Reviewing Kubernetes manifests, Helm templates, probes, resource limits, and scheduling rules.
- Improving Docker Compose and shell-script execution for the required golden path.
- Reviewing CI workflow configuration and security scanning.
- Drafting documentation and operational responses.

Tools used: ChatGPT, Docker, kubectl, Helm, Git, and GitHub Actions for independent validation.

## Representative Prompts

1. "Help diagnose the Calico CRD installation failure caused by oversized metadata annotations and field-manager conflicts. Suggest a safe way to apply the CRDs."

2. "Review the Kubernetes deployment and scheduling configuration. Check spot and on-demand placement, health probes, resource requests, and pod disruption budget."

3. "Review the golden-path execution. The evaluator will run docker compose up -d followed by ./scripts/run-all.sh from the repository directory. Ensure the script works from the host and delegates Kubernetes operations to the toolbox container."

## Example of AI Output That Needed Correction

An initial version of the run-all script assumed it would always execute inside the toolbox container, where the repository is mounted at `/workspace`.

However, the assessment's golden path invokes the script directly from the host repository directory. Running it in that way exposed the host-versus-container path assumption.

I verified the issue by testing the exact golden-path commands from a fresh repository clone. The script was then updated to detect host execution and delegate to the toolbox using Docker Compose. The golden path was tested again after the correction.

## Validation and Responsibility

AI-generated suggestions were not accepted without verification. Commands were tested, Kubernetes resources and application endpoints were checked, CI results were reviewed, and changes were committed only after validation.

The final implementation decisions, testing, and submitted changes remain my responsibility.
