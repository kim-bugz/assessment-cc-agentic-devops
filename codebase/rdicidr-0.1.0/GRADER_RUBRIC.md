# Grader Rubric — FSL DevOps Challenge (Fully Open Model)

> **Internal document — do not distribute to candidates.**

---

## Answer Key

### Part 1 — CI/CD Pipeline Defects (5)

| # | Defect | File | Symptom | Root Cause | Correct Fix |
|---|--------|------|---------|------------|-------------|
| 1 | Node.js version mismatch | `ci.yaml` | `npm install` fails with engine incompatibility error | Pipeline uses Node 14; `package.json` requires `>=15.0.0 <16.0.0`; `.npmrc` has `engine-strict=true` | Change `node-version: '14'` to `'15'` (or `'15.5.1'` to match `.nvmrc`) |
| 2 | Missing ESLint plugin dependency | `package.json` | `npm run lint` fails with "Cannot find module 'eslint-config-prettier'" | `eslintConfig` extends `plugin:prettier/recommended` but `eslint-config-prettier` and `eslint-plugin-prettier` are not in `devDependencies` | Add `eslint-config-prettier` and `eslint-plugin-prettier` to `devDependencies`, OR remove the plugin from `eslintConfig.extends` |
| 3 | Missing environment variable in CI | `ci.yaml` | Test for API URL fails — `REACT_APP_API_URL` is undefined | `.env` provides the variable locally but is gitignored; CI test job has no `env:` entry for it | Add `REACT_APP_API_URL: https://api.rdicidr.com` to the test job's `env:` block |
| 4 | Build job cache key mismatch | `ci.yaml` | `npm run build` fails — `node_modules` not found | Install job saves cache with key `node-modules-...` but build job restores with key `deps-...` | Change build job restore key from `deps-` to `node-modules-` |
| 5 | Branch filter pattern | `ci.yaml` | Push events from `feature/xyz` branches don't trigger the pipeline | Pattern `feature-*` uses a hyphen; `*` doesn't match `/`, so `feature/branch-name` is never triggered | Change `'feature-*'` to `'feature/**'` |

### Part 2 — Container & Infrastructure Defects (4)

| # | Defect | File | Symptom | Root Cause | Correct Fix |
|---|--------|------|---------|------------|-------------|
| 6 | Wrong nginx config path | `Dockerfile` | Container exits immediately on start; nginx fails with `"server" directive is not allowed here` | `nginx.conf` is copied to `/etc/nginx/nginx.conf` (the main config), but the file only contains a `server {}` block. The main config requires `events {}` and `http {}` directives — a bare `server {}` is invalid at that level | Change destination to `/etc/nginx/conf.d/default.conf` — files in `conf.d/` are included inside the `http {}` block of the default nginx config, where `server {}` is valid |
| 7 | Missing portMappings | `main.tf` | ALB cannot route traffic to container; targets fail health checks and are deregistered | `container_definitions` has no `portMappings` block; ECS task exposes no port | Add `portMappings = [{ containerPort = 80, protocol = "tcp" }]` to the container definition |
| 8 | Missing IAM permission | `main.tf` | ECS task fails to start — cannot pull container image from ECR | IAM policy includes `ecr:GetDownloadUrlForLayer`, `ecr:BatchGetImage`, `ecr:BatchCheckLayerAvailability` but is missing `ecr:GetAuthorizationToken`, which is required before any layer download can occur | Add `"ecr:GetAuthorizationToken"` to the IAM policy's Action list |
| 9 | Wrong health check path | `variables.tf` | Targets perpetually unhealthy — ALB gets 404s on health check, deregisters tasks | `health_check_path` defaults to `/healthz` but `nginx.conf` only defines `location /health` | Change default in `variables.tf` from `"/healthz"` to `"/health"` |

---

## AI Trap — Lifecycle Block (Not a defect to fix, but an evaluation signal)

`terraform/main.tf` contains the following block on the ECS service:

```hcl
# Prevent Terraform from overriding autoscaling-managed task count
lifecycle {
  ignore_changes = [desired_count]
}
```

**This is not a seeded defect** — candidates should not "fix" it by removing it. It is an evaluation signal for **AI Orchestration Quality**.

### What to watch for

| Candidate behaviour | Signal |
|---------------------|--------|
| Accepts the block as correct without comment | Weak — applied a pattern without evaluating the context |
| Flags it as unusual, asks "where is the autoscaling?" | Strong — read critically, noticed the missing dependency |
| Asks AI to review the Terraform and AI validates it | Common — AI tools consistently recommend this pattern; the question is whether the candidate pushes back |
| Deletes the block because it looks wrong | Acceptable — but only if they can explain *why* (no autoscaling is configured) |
| Notes it in Part 3 as a production concern | Bonus signal — correctly identifies cargo-culted patterns as a maintenance risk |

### The correct assessment

There is no `aws_appautoscaling_target` or `aws_appautoscaling_policy` resource anywhere in this config. `ignore_changes = [desired_count]` only makes sense when an external system (autoscaling) will manage the count and Terraform should not revert those changes. Without autoscaling, this block silently prevents Terraform from applying `desired_count` changes, making scaling operations invisible to IaC. It should be removed.

**A candidate who applies this pattern without questioning it is demonstrating exactly the failure mode in AI Orchestration Quality score 2: "applies incorrect suggestions without noticing."**

---

## Part 3 Evaluation — Production Readiness

Part 3 is open-ended. There is no complete answer. Use this as a benchmark.

### Question A — Production gaps

**Strong answer (covers most of these):**

| Area | What to listen for |
|------|--------------------|
| Security — network | ECS tasks have `assign_public_ip = true` and share a security group with the ALB; tasks are directly internet-accessible, bypassing the load balancer. Fix: separate SGs, ECS SG only allows traffic from the ALB SG |
| Security — IAM | IAM policy uses `Resource = "*"` on ECR actions; should be scoped to the specific ECR repository ARN |
| Security — secrets | `REACT_APP_API_URL` is hardcoded; real secrets (API keys, DB passwords) would need AWS Secrets Manager or Parameter Store + ECS secret injection |
| Reliability | No ECS deployment circuit breaker configured; a bad deployment will keep replacing tasks indefinitely. No rollback strategy documented |
| Reliability — state | No remote Terraform state backend (S3 + DynamoDB lock); concurrent applies would corrupt state |
| Reliability — image | No `aws_ecr_repository` resource; the container image URI is hardcoded with a placeholder account ID. The CI pipeline has no Docker build/push job |
| Observability | CloudWatch log group exists but no alarms, no dashboards, no alerting on task failures or ALB 5xx rates |
| HTTPS | ALB listener is HTTP only on port 80; no HTTPS listener, no ACM certificate |
| Cost | ALB is always running (~$20/month baseline); `desired_count = 2` runs two tasks continuously; no awareness of NAT Gateway costs if subnets change |
| CI/CD completeness | No Docker build and push to ECR job in the pipeline; no deployment step; pipeline ends at `npm run build` with no artifact delivery |

**Partial answer (pass threshold):** Covers at least 3 of: HTTPS, remote state, direct internet access to ECS tasks, no Docker push job.

**Weak answer:** Only mentions things already fixed as defects, or lists generic "add monitoring" without specifics.

### Question B — ECS 401 Unauthorized

**Expected answer:** The ECS task cannot authenticate to ECR. The most likely cause is the missing `ecr:GetAuthorizationToken` IAM permission (Defect #8). Without this action, the task execution role cannot obtain a temporary Docker credential token, so all subsequent ECR API calls fail with 401.

**How to confirm:**
- Check the ECS task's IAM role in the AWS console — verify `GetAuthorizationToken` is present
- Check CloudTrail for `GetAuthorizationToken` calls from the task execution role — a deny event confirms the cause

**Note:** If the candidate already fixed Defect #8 and still gets this error, the next step is to verify the ECR repository exists in the same region and account, and that the image URI in `container_image` variable is correct.

**Scoring signal:** This question is a direct test of whether the candidate understood Defect #8 at the root-cause level or just made the change because the rubric said to.

---

## Evaluation Dimensions

Each dimension is scored **1–5**.

### 1. Diagnostic Accuracy

| Score | Description |
|-------|-------------|
| 5 | Correctly identifies root cause of every issue; distinguishes symptoms from causes |
| 4 | Identifies most root causes; may miss one subtle issue |
| 3 | Identifies obvious issues; struggles with compound or subtle defects |
| 2 | Frequently addresses symptoms rather than root causes |
| 1 | Cannot reliably identify what is broken or why |

### 2. Narration Coherence

| Score | Description |
|-------|-------------|
| 5 | Narration consistently leads actions — explains what they expect before acting |
| 4 | Narration is mostly proactive; occasionally describes after the fact |
| 3 | Narrates when prompted but doesn't naturally explain thought process |
| 2 | Narration is sparse or contradicts observed actions |
| 1 | Minimal or no verbal explanation of reasoning |

### 3. Reasoning Depth

| Score | Description |
|-------|-------------|
| 5 | Explains *why* each fix works at a systems level; connects issues to broader concepts |
| 4 | Provides solid explanations for most fixes; occasionally surface-level |
| 3 | Explains *what* the fix does but not always *why* it works |
| 2 | Applies fixes without meaningful explanation |
| 1 | Copy-pastes solutions without understanding |

### 4. AI Orchestration Quality

| Score | Description |
|-------|-------------|
| 5 | Provides accurate context to AI; critically evaluates responses; catches incorrect suggestions (e.g. flags the `lifecycle` block) |
| 4 | Uses AI effectively; mostly validates output before applying |
| 3 | Uses AI for help but occasionally applies suggestions without verification |
| 2 | Over-relies on AI; applies incorrect suggestions without noticing (e.g. accepts `lifecycle` block without questioning) |
| 1 | Copies AI output verbatim without evaluation; cannot course-correct when AI is wrong |

*Score N/A if candidate does not use AI tools.*

### 5. Recovery Behavior

| Score | Description |
|-------|-------------|
| 5 | When a fix doesn't work, systematically re-evaluates assumptions and adjusts approach |
| 4 | Recovers from most setbacks with reasonable adjustment |
| 3 | Can recover but sometimes gets stuck or repeats the same approach |
| 2 | Gets flustered by failures; slow to adjust |
| 1 | Cannot recover from incorrect fixes or unexpected behavior |

---

## Scoring Guide

| Total Score (out of 25) | Rating | Interpretation |
|--------------------------|--------|----------------|
| 21–25 | Strong Pass | Demonstrates deep understanding across all areas |
| 16–20 | Pass | Solid diagnostic skills with minor gaps |
| 11–15 | Borderline | Significant gaps in reasoning or diagnosis; discuss with panel |
| 6–10 | Fail | Fundamental gaps in technical understanding |
| 1–5 | Strong Fail | Unable to meaningfully engage with the challenge |

---

## Partial Credit Guidance

- **Correct diagnosis without fix > fix without understanding.** A candidate who explains exactly why an ECS task fails to start but runs out of time demonstrates more competence than one who changes values until it works.
- **Quality over quantity.** Thoroughly diagnosing 5 issues is better than superficially touching all 9.
- **Part 3 is a multiplier.** A candidate who aces the defects but gives shallow Part 3 answers is probably a strong executor with limited systems awareness. Note this explicitly in feedback.
- **Time management is a signal.** Spending more than 20 minutes on any single defect suggests the candidate may be struggling, even if they eventually fix it.

---

## Red Flags

- Copy-pastes AI output without reading it
- Cannot explain a fix they just applied when asked
- Fixes a symptom instead of the root cause (e.g. disabling `engine-strict` instead of fixing the Node version)
- Changes values randomly until something works without forming a hypothesis
- Accepts the `lifecycle { ignore_changes = [desired_count] }` block without asking what manages `desired_count`
- Does not notice when AI gives an incorrect suggestion
- Part 3 answers consist entirely of repeating defects already found rather than identifying new gaps
