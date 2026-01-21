# ShowcaseMonorepo
Multi-Layered Cloud Infrastructure Platform
Orchestrated with Nx, Terraform, and GitHub Actions
🏗️ Executive Summary
In modern cloud environments, "Monolithic Terraform" (one massive state file) creates a massive "blast radius" and slow deployment times. This project demonstrates a Modular, Layered Infrastructure approach. By separating the foundational networking (Layer 1) from the service-specific DNS and Application logic (Layer 2), we achieve faster iterations and higher system stability.

💼 Business Problems Solved
1. The "Blast Radius" Risk
Problem: A minor change to a DNS record shouldn't risk deleting a production Database.

Solution: By decoupling the layers, we ensure that changes in the Service Layer cannot physically modify or destroy the Infrastructure Layer.

2. Ephemeral CI/CD Automation
Problem: GitHub Actions runners are "stateless" and forget everything once a job finishes.

Solution: Implemented a Persistent S3 Bridge that preserves Terraform Plan files across different workflow stages, ensuring that what is "Planned" is exactly what is "Applied."

3. Service Discovery & Security
Problem: Hardcoding IP addresses or long RDS endpoints is brittle and insecure.

Solution: Automated the creation of a Private Route53 Hosted Zone, allowing internal services to communicate via human-readable names (e.g., db.showcase.internal) that update automatically if the underlying hardware changes.

🛠️ Technical Architecture
Layer 1: The Foundation (infra-main)
VPC & Networking: Isolated private subnets.

Persistent Storage: AWS RDS (PostgreSQL) instance.

Exports: Securely shares the DB endpoint via Terraform Remote State.

Layer 2: The Services (infra-services)
DNS Management: AWS Route53 Private Zone.

Cross-Layer Dependency: Dynamically ingests Layer 1 outputs to create CNAME records.

Verification: Zero-trust verification via AWS CLI to ensure DNS records match the physical hardware.

🚀 The DevOps Pipeline
The project utilizes a custom Nx-powered workflow within GitHub Actions:

Monorepo Management: Nx detects exactly which layer changed and only runs the necessary plans.

State Management: State is stored in Amazon S3 with standardized naming conventions for easy auditing.

The "Plan-to-Apply" Handshake:

Plan generates a binary artifact.

Artifact is uploaded to S3.

Apply downloads that specific artifact, preventing "drift" during the deployment window.

📊 Operational Highlights
Cost Optimization: Automated "Destroy" sequences to ensure zero-waste cloud spending.

Auditability: Every change is verified against the AWS API directly, ensuring the "Source of Truth" in S3 matches the "Physical Reality" in the AWS Console


🚀 How to Run
This project uses Nx to wrap Terraform commands. This ensures that commands are executed in the correct order and provides a unified interface for the CI/CD pipeline.


1. Prerequisites
AWS CLI configured with appropriate permissions.

Node.js installed (for Nx execution).

Terraform CLI installed on the local runner.

2. Initialization
Before any infrastructure can be built, the backends must be initialized to point to the S3 State Bucket.

Bash

# Initialize the Foundation Layer
npx nx run infra-main:init

# Initialize the Services Layer
npx nx run infra-services:init
3. Deploying the Foundation (Layer 1)
This layer creates the VPC and the RDS instance.

Bash

# 1. Generate a Plan and save it to S3
npx nx run infra-main:plan

# 2. Review the plan output in the console.

# 3. Apply the saved plan
npx nx run infra-main:apply
4. Deploying the Services (Layer 2)
This layer reads the outputs from Layer 1 to create DNS records. Note that Layer 1 must be successfully applied before this will work.

Bash

# 1. Generate a Plan (reads Layer 1 Remote State)
npx nx run infra-services:plan

# 2. Apply the DNS changes
npx nx run infra-services:apply
5. Verification
To ensure the "Physical Reality" matches the "Code Intent," run the following verification command:

Bash

# Get the Hosted Zone ID from Layer 2 Outputs
ZONE_ID=$(npx nx run infra-services:terraform --args="output -raw hosted_zone_id")

# Query AWS directly for the CNAME record
aws route53 list-resource-record-sets \
  --hosted-zone-id $ZONE_ID \
  --query "ResourceRecordSets[?Name == 'db.showcase.internal.']"
6. Clean Teardown
To avoid unnecessary AWS costs, destroy the resources in reverse order.

Bash

# First: Remove DNS and Services
npx nx run infra-services:destroy

# Second: Remove VPC and RDS
npx nx run infra-main:destroy
💡 Lessons Learned (Architect's Notes)
State Serialization: We encountered a "Saved plan is stale" error during the process. This taught us that in a GitHub Actions environment, the S3 state file's serial number must exactly match the tfplan file. Cleaning old plans from S3 is a mandatory step after a manual destroy.

Data Transformation: RDS endpoints include a port suffix (e.g., :5432). Route53 CNAMEs do not support ports. We implemented a split function in the Layer 1 outputs.tf to ensure the "Producer" sends clean data to the "Consumer."

The "Self-Fixing" Mystery: We observed that Terraform errors regarding "missing attributes" are often actually "data availability" issues. Once Layer 1 successfully commits its state to S3, the downstream Layer 2 errors resolve themselves.


<a alt="Nx logo" href="https://nx.dev" target="_blank" rel="noreferrer"><img src="https://raw.githubusercontent.com/nrwl/nx/master/images/nx-logo.png" width="45"></a>

✨ Your new, shiny [Nx workspace](https://nx.dev) is ready ✨.

[Learn more about this workspace setup and its capabilities](https://nx.dev/getting-started/intro#learn-nx?utm_source=nx_project&amp;utm_medium=readme&amp;utm_campaign=nx_projects) or run `npx nx graph` to visually explore what was created. Now, let's get you up to speed!

## Run tasks

To run tasks with Nx use:

```sh
npx nx <target> <project-name>
```

For example:

```sh
npx nx build myproject
```

These targets are either [inferred automatically](https://nx.dev/concepts/inferred-tasks?utm_source=nx_project&utm_medium=readme&utm_campaign=nx_projects) or defined in the `project.json` or `package.json` files.

[More about running tasks in the docs &raquo;](https://nx.dev/features/run-tasks?utm_source=nx_project&utm_medium=readme&utm_campaign=nx_projects)

## Add new projects

While you could add new projects to your workspace manually, you might want to leverage [Nx plugins](https://nx.dev/concepts/nx-plugins?utm_source=nx_project&utm_medium=readme&utm_campaign=nx_projects) and their [code generation](https://nx.dev/features/generate-code?utm_source=nx_project&utm_medium=readme&utm_campaign=nx_projects) feature.

To install a new plugin you can use the `nx add` command. Here's an example of adding the React plugin:
```sh
npx nx add @nx/react
```

Use the plugin's generator to create new projects. For example, to create a new React app or library:

```sh
# Generate an app
npx nx g @nx/react:app demo

# Generate a library
npx nx g @nx/react:lib some-lib
```

You can use `npx nx list` to get a list of installed plugins. Then, run `npx nx list <plugin-name>` to learn about more specific capabilities of a particular plugin. Alternatively, [install Nx Console](https://nx.dev/getting-started/editor-setup?utm_source=nx_project&utm_medium=readme&utm_campaign=nx_projects) to browse plugins and generators in your IDE.

[Learn more about Nx plugins &raquo;](https://nx.dev/concepts/nx-plugins?utm_source=nx_project&utm_medium=readme&utm_campaign=nx_projects) | [Browse the plugin registry &raquo;](https://nx.dev/plugin-registry?utm_source=nx_project&utm_medium=readme&utm_campaign=nx_projects)

## Set up CI!

### Step 1

To connect to Nx Cloud, run the following command:

```sh
npx nx connect
```

Connecting to Nx Cloud ensures a [fast and scalable CI](https://nx.dev/ci/intro/why-nx-cloud?utm_source=nx_project&utm_medium=readme&utm_campaign=nx_projects) pipeline. It includes features such as:

- [Remote caching](https://nx.dev/ci/features/remote-cache?utm_source=nx_project&utm_medium=readme&utm_campaign=nx_projects)
- [Task distribution across multiple machines](https://nx.dev/ci/features/distribute-task-execution?utm_source=nx_project&utm_medium=readme&utm_campaign=nx_projects)
- [Automated e2e test splitting](https://nx.dev/ci/features/split-e2e-tasks?utm_source=nx_project&utm_medium=readme&utm_campaign=nx_projects)
- [Task flakiness detection and rerunning](https://nx.dev/ci/features/flaky-tasks?utm_source=nx_project&utm_medium=readme&utm_campaign=nx_projects)

### Step 2

Use the following command to configure a CI workflow for your workspace:

```sh
npx nx g ci-workflow
```

[Learn more about Nx on CI](https://nx.dev/ci/intro/ci-with-nx#ready-get-started-with-your-provider?utm_source=nx_project&utm_medium=readme&utm_campaign=nx_projects)

## Install Nx Console

Nx Console is an editor extension that enriches your developer experience. It lets you run tasks, generate code, and improves code autocompletion in your IDE. It is available for VSCode and IntelliJ.

[Install Nx Console &raquo;](https://nx.dev/getting-started/editor-setup?utm_source=nx_project&utm_medium=readme&utm_campaign=nx_projects)

## Useful links

Learn more:

- [Learn more about this workspace setup](https://nx.dev/getting-started/intro#learn-nx?utm_source=nx_project&amp;utm_medium=readme&amp;utm_campaign=nx_projects)
- [Learn about Nx on CI](https://nx.dev/ci/intro/ci-with-nx?utm_source=nx_project&utm_medium=readme&utm_campaign=nx_projects)
- [Releasing Packages with Nx release](https://nx.dev/features/manage-releases?utm_source=nx_project&utm_medium=readme&utm_campaign=nx_projects)
- [What are Nx plugins?](https://nx.dev/concepts/nx-plugins?utm_source=nx_project&utm_medium=readme&utm_campaign=nx_projects)

And join the Nx community:
- [Discord](https://go.nx.dev/community)
- [Follow us on X](https://twitter.com/nxdevtools) or [LinkedIn](https://www.linkedin.com/company/nrwl)
- [Our Youtube channel](https://www.youtube.com/@nxdevtools)
- [Our blog](https://nx.dev/blog?utm_source=nx_project&utm_medium=readme&utm_campaign=nx_projects)
