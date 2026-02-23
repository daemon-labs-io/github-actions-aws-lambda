# Workshop Facilitator Guide

## Setup

> [!CAUTION]
> This only needs to be done by the workshop facilitator before the workshop begins.
> Participants don't need AWS credentials - they'll use secure OIDC authentication.

If you're running this workshop, complete the AWS setup first:

```shell
./_facilitator/setup-aws.sh
```

This script creates:
- GitHub OIDC provider for secure authentication (no secrets needed)
- IAM roles for GitHub Actions and Lambda execution
- Required permissions for the workshop

Add the output secrets to your GitHub repository before starting the workshop.

## Cleanup

After the workshop, run:

```shell
./_facilitator/cleanup-aws.sh
```
