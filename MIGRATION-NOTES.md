# GitLab CI to GitHub Actions Migration

## 1. Objective

Migrate the Quote API CI/CD pipeline to GitHub Actions while retaining automated security scanning, Docker image building, and container image publishing.

The migrated workflow is located at:

`.github/workflows/ci.yml`

## 2. Pipeline design

The GitHub Actions workflow is named `Quote API CI/CD` and supports:

- Push events to the `main` branch.
- Pull requests targeting the `main` branch.
- Manual execution using `workflow_dispatch`.

The pipeline contains two jobs.

### Job 1: Semgrep SAST

- Checks out the source code.
- Sets up Python 3.12.
- Installs Semgrep.
- Scans the application source under `app/` using the `p/python` ruleset.
- Uses `--error` so detected findings cause the job to fail.

This job acts as a security gate. The image build job cannot proceed unless the security scan succeeds.

### Job 2: Build and push image

- Runs only after the Semgrep job succeeds.
- Skips pull-request events to avoid publishing images from unmerged changes.
- Sets up Docker Buildx.
- Authenticates to GitHub Container Registry (GHCR) using `GITHUB_TOKEN`.
- Builds the Docker image from the repository root.
- Publishes the image to GHCR using the full Git commit SHA as its tag.

Image naming convention:

`ghcr.io/<github-owner>/quote-api:<commit-sha>`

The workflow also adds OCI labels identifying the source repository and Git revision.

## 3. Security and permissions

The workflow follows least-privilege permissions:

- Workflow-level permission: `contents: read`.
- Image publishing job: `contents: read` and `packages: write`.
- GHCR authentication uses the automatically provided `GITHUB_TOKEN`; no separate registry password is stored in the repository.

Semgrep is configured as a hard-failing security gate. A failed scan prevents the dependent image publishing job from running.

## 4. GitLab-to-GitHub Actions mapping

| Pipeline responsibility | GitHub Actions implementation |
|---|---|
| Pipeline triggers | `push`, `pull_request`, `workflow_dispatch` |
| Source checkout | `actions/checkout` |
| Python environment | `actions/setup-python` |
| Static application security testing | Semgrep |
| Docker build environment | Docker Buildx |
| Container registry authentication | `docker/login-action` |
| Image build and publishing | `docker/build-push-action` |
| Pipeline dependency | `needs: security-scan` |
| Registry credentials | GitHub `GITHUB_TOKEN` |

## 5. Image versioning and deployment

Images are tagged with the Git commit SHA rather than a mutable `latest` tag. This provides traceability between a published image and the source revision used to build it.

The Helm chart uses an explicitly configured image tag. Updating that tag is a separate deployment configuration change; this workflow does not automatically modify the Helm values or trigger an image-tag update in Argo CD.

## 6. Validation

Validate the migration by checking:

1. A push to `main` triggers the workflow.
2. A pull request targeting `main` runs the Semgrep security scan.
3. A Semgrep finding causes the security job to fail.
4. The image build job waits for the security job to succeed.
5. A successful push to `main` publishes a SHA-tagged image to GHCR.
6. The published image is accessible using the expected GHCR image reference.

The GitHub Actions run history provides the execution logs and job status for review.

## 7. Operational considerations

- Configure branch protection to require the Semgrep status check before merging pull requests.
- Review and maintain the Semgrep ruleset as the application evolves.
- Keep image tags immutable and retain the commit SHA for traceability.
- Ensure the GHCR package visibility and access permissions allow the Kubernetes environment to pull the image.
- Keep deployment image-tag updates separate from image publishing unless an image automation process is introduced.
