# FSL DevOps Challenge — Terraform & CI/CD

**Duration:** 90 minutes  
**Format:** Live troubleshooting session with verbal narration  
**AI tools:** Permitted and encouraged — see policy below

---

## AI Usage Policy

You are free to use any AI tools (Claude, ChatGPT, Copilot, etc.) throughout this challenge. There are no restrictions.

Two things are required regardless of what tools you use:

1. **Narrate before you act.** Before running a command or applying a fix, say out loud what you expect to find and why. "I think the problem is X because Y" before you confirm it.
2. **Own every fix.** If you apply a suggestion from an AI tool, you must be able to explain it. We may ask "why does that fix it?" at any point.

---

## Context

You have been handed a partially broken repository for **rdicidr**, a React-based CIDR calculator. It has been containerized and infrastructure has been written to deploy it on AWS ECS Fargate behind an Application Load Balancer.

The repository contains deliberate defects seeded across three areas:

- The GitHub Actions CI/CD pipeline
- The Docker container build
- The Terraform / ECS infrastructure

Your job is to find and fix them.

---

## Part 1 — CI/CD Pipeline (40 minutes)

File: `.github/workflows/ci.yaml`  
Supporting files: `package.json`, `src/App.test.js`, `.npmrc`, `.nvmrc`

The pipeline has **5 defects**. Some will cause immediate failures; others are logic errors that produce incorrect behavior without an obvious error message.

### Setup

```bash
cd codebase/rdicidr-0.1.0
nvm use         # switch to the project's required Node version
npm install
echo "REACT_APP_API_URL=https://api.rdicidr.com" > .env
```

### What to do

1. Review the pipeline file and identify what is wrong.
2. Run commands locally to reproduce failures where possible.
3. Apply fixes and explain each one.

### Guidance

- Read error messages carefully — the symptom is not always the root cause.
- Check all files that the pipeline depends on, not just `ci.yaml`.
- One defect is only detectable by reviewing the YAML — there is nothing to run locally.

---

## Part 2 — Container & Infrastructure (40 minutes)

Files: `Dockerfile`, `nginx.conf`, `terraform/main.tf`, `terraform/variables.tf`

There are **4 defects** across the container build and Terraform config. The infrastructure targets AWS ECS Fargate with an ALB.

### Setup

```bash
cd terraform
terraform init
terraform validate
```

### What to do

1. Review the Dockerfile and nginx config. Identify any defect that would prevent the container from running correctly.
2. Review the Terraform. Identify defects that would prevent a successful deployment or cause runtime failures.
3. For each defect: state the symptom, identify the root cause, apply the fix, and explain why it works.

### Guidance

- `terraform validate` passing does not mean the config is correct — HCL syntax is not the same as deployment correctness.
- Pay attention to what the infrastructure config *references* versus what is actually *configured*.
- One item in the Terraform may look like a recognised best practice. Evaluate whether it applies to this specific configuration.

---

## Part 3 — Production Readiness (10 minutes)

No coding required. Answer the following questions verbally or in writing.

### Question A

Set aside all the defects you just fixed. Looking at this repository as a whole — the CI pipeline, the Dockerfile, and the Terraform — **what would need to change before this is production-ready?**

There is no single correct answer. We are looking for breadth of awareness and your ability to distinguish "works in a demo" from "operates safely at scale."

Prompts to consider (you do not need to cover all of these):

- Security: network access, secrets, IAM scope
- Reliability: what happens when a deploy fails mid-way?
- Observability: how would you know something is wrong at 2am?
- Cost: any resources here that would surprise you on the bill?
- Process: what is missing from the CI/CD flow before a real team could use this?

### Question B

You receive this error in ECS task logs shortly after a `terraform apply`:

```
CannotPullContainerError: inspect image has been retried 1 time(s):
failed to resolve ref "123456789012.dkr.ecr.us-east-1.amazonaws.com/rdicidr:latest":
unexpected status code 401 Unauthorized
```

Walk through how you would diagnose this. What is the likely root cause and how do you confirm it?

---

## Deliverables

By the end of the session you should have:

- [ ] All CI defects identified and fixed (or explained if you ran out of time)
- [ ] All container and Terraform defects identified and fixed (or explained)
- [ ] Answered Part 3 questions verbally

**Partial credit applies.** A clear explanation of a root cause you didn't have time to fix is worth more than a fix you cannot explain.
