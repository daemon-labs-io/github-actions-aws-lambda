# Deploy AWS Lambda functions with GitHub Actions

This workshop walks you through setting up a production-ready CI/CD pipeline using **GitHub Actions**, **AWS Lambda**, and **TypeScript**.  
It focuses on building automated deployments with secure OIDC authentication, optimising for production workloads, and demonstrating modern cloud-native development practices.

---

## 🛑 Prerequisites

### General/global prerequisites

Before beginning this workshop, please ensure your environment is correctly set up by following the instructions in our prerequisites documentation:

➡️ **[Prerequisites guide](https://github.com/daemon-labs-io/prerequisites)**

### Workshop facilitator setup

> [!CAUTION]
> This only needs to be done by the workshop facilitator before the workshop begins.  
> Participants don't need AWS credentials - they'll use secure OIDC authentication.

If you're running this workshop, complete the AWS setup first:

```shell
./scripts/setup-aws.sh
```

This script creates:
- GitHub OIDC provider for secure authentication (no secrets needed)
- IAM roles for GitHub Actions and Lambda execution
- Required permissions for the workshop

Add the output secrets to your GitHub repository before starting the workshop.

---

## 1. The foundation

**Goal:** Get a working GitHub Actions deployment pipeline running.

### Create your workshop branch

1. Open the repository in your browser: https://github.com/daemon-labs-io/github-actions-aws-lambda
2. Click the "Branch: main" button in the top-left corner
3. Type your branch name: `YOUR-USERNAME-workshop`
   - Replace `YOUR-USERNAME` with your actual GitHub username
4. Click "Create branch: YOUR-USERNAME-workshop"

> [!NOTE]
> This naming convention allows everyone to deploy to their own Lambda function without conflicts.

### Make your first change

1. Click **"Add file"** → **"Create new file"**
2. Name the file: `workshop-log.md`
3. Add content in the editor:
   ```markdown
   # Workshop started by YOUR-NAME
   Date: $(date)
   ```
4. Scroll down and click **"Commit new file"**
5. Leave the default commit message and click **"Commit new file"** again

> [!TIP]
> The workflow is triggered automatically when you push to branches ending with `-workshop`. Your branch name is important!

### Watch your deployment

1. Click the **"Actions"** tab at the top of the repository
2. You should see a workflow running with your branch name
3. Click on the workflow to see real-time deployment logs
4. Watch the steps execute:
   - ✅ Repository checkout
   - ✅ Username extraction (showing your username)
   - ✅ AWS authentication via OIDC
   - ✅ Lambda function creation
   - ✅ Automated testing

---

## 2. The production Lambda

**Goal:** Understand the production-ready Lambda function you're deploying.

### Examine the code structure

1. In the repository, click on the **`production/`** folder
2. Explore the files:
   - `src/index.ts` - The main Lambda handler
   - `Dockerfile` - Production build configuration
   - `package.json` - Dependencies and scripts
   - `tsconfig.json` - TypeScript configuration

> [!NOTE]
> The `production/` directory contains a production-ready Lambda function that's different from the local development version in the original workshop.

### Key files to understand

#### `production/src/index.ts` - The Lambda handler

This is a production-ready handler that:
- Connects to real AWS S3 service (not LocalStack)
- Returns structured JSON responses
- Includes deployment metadata and error handling

```typescript
export const handler: Handler = async (event, context) => {
  console.log("🚀 Lambda deployed via GitHub Actions!");
  
  try {
    const response = await client.send(command);
    return {
      statusCode: 200,
      body: JSON.stringify({
        message: "Hello from GitHub Actions deployed Lambda!",
        buckets: response.Buckets?.map(b => b.Name) || [],
        deployedBy: process.env.GITHUB_ACTOR || "Unknown",
        deployedAt: new Date().toISOString()
      })
    };
  } catch (error) {
    return {
      statusCode: 500,
      body: JSON.stringify({
        message: "Error connecting to S3",
        error: error instanceof Error ? error.message : "Unknown error"
      })
    };
  }
};
```

#### `production/Dockerfile` - Multi-stage build

This is a production-optimized build:
- **Stage 1**: Builder with development dependencies
- **Stage 2**: Runtime with only production dependencies
- **Result**: Smaller, more secure images

```Dockerfile
FROM public.ecr.aws/lambda/nodejs:24 AS base

FROM base AS builder
COPY ./package*.json ${LAMBDA_TASK_ROOT}
RUN npm ci
COPY ./ ${LAMBDA_TASK_ROOT}
RUN npm run build

FROM base
COPY --from=builder ${LAMBDA_TASK_ROOT}/package*.json ${LAMBDA_TASK_ROOT}
RUN npm ci --only=production
COPY --from=builder ${LAMBDA_TASK_ROOT}/build ${LAMBDA_TASK_ROOT}/build

CMD [ "build/index.handler" ]
```

---

## 3. The CI/CD pipeline

**Goal:** Understand how the GitHub Actions workflow deploys to AWS.

### Examine the workflow

1. Click on the **`.github/workflows/deploy-lambda.yaml`** file
2. Examine the key sections:

#### Trigger condition

```yaml
on:
  push:
    branches: ['*-workshop']
```

> [!NOTE]
> This workflow only runs for branches ending with `-workshop`, which is why your branch name was important.

#### OIDC authentication

```yaml
permissions:
  id-token: write
  contents: read

- name: Configure AWS Credentials
  uses: aws-actions/configure-aws-credentials@v4
  with:
    role-to-assume: ${{ secrets.AWS_ROLE_ARN }}
    aws-region: ${{ env.AWS_REGION }}
```

> [!TIP]
> No AWS secrets needed! OIDC creates a secure trust relationship between GitHub and AWS.

#### Deployment steps

The workflow handles:
1. **Build**: Compiles TypeScript and packages the Lambda
2. **Deploy**: Creates or updates the Lambda function
3. **URL creation**: Sets up a Function URL for HTTP access
4. **Testing**: Automatically tests the deployed function

---

## 4. Testing your deployment

**Goal:** Verify your Lambda is working and accessible.

### Get your function details

From the GitHub Actions workflow summary, find:
- **Function name**: `YOUR-USERNAME-workshop-lambda`
- **Function URL**: Direct HTTPS endpoint

### Test via cURL

```shell
# Use the URL from your workflow summary
curl -X POST "YOUR-FUNCTION-URL" \
  -d '{"message": "Hello from workshop!"}' \
  -H "Content-Type: application/json"
```

### Expected response

```json
{
  "message": "Hello from GitHub Actions deployed Lambda!",
  "buckets": ["bucket1", "bucket2"],
  "deployedBy": "YOUR-USERNAME",
  "deployedAt": "2026-02-10T15:30:00.000Z"
}
```

> [!NOTE]
- The `buckets` array shows your AWS S3 buckets
- `deployedBy` shows your GitHub username
- `deployedAt` shows when the deployment happened

### Test in browser

You can also visit your Function URL directly in a web browser.

---

## 5. Advanced deployment

**Goal:** Make changes and see the automated redeployment.

### Modify your Lambda

1. Navigate to **`production/src/index.ts`**
2. Click the **pencil icon** (Edit) to modify the file
3. Add a custom feature by updating the handler:

```typescript
export const handler: Handler = async (event, context) => {
  console.log("🚀 Modified Lambda deployed via GitHub Actions!");
  
  // Add custom logic
  const customMessage = process.env.CUSTOM_MESSAGE || "Hello from workshop!";
  
  try {
    const response = await client.send(command);
    return {
      statusCode: 200,
      body: JSON.stringify({
        message: customMessage,
        buckets: response.Buckets?.map(b => b.Name) || [],
        deployedBy: process.env.GITHUB_ACTOR || "Unknown",
        deployedAt: new Date().toISOString()
      })
    };
  } catch (error) {
    return {
      statusCode: 500,
      body: JSON.stringify({
        message: "Error connecting to S3",
        error: error instanceof Error ? error.message : "Unknown error"
      })
    };
  }
};
```

### Deploy your changes

1. Scroll to the bottom of the page
2. In the "Commit changes" section:
   - Leave the default commit message
   - Select **"Commit directly to the YOUR-USERNAME-workshop branch"**
3. Click **"Commit changes"**

> [!TIP]
- Go to the **Actions** tab to watch the workflow run again
- Notice how it automatically detects the change and redeploys
- Test your updated function with the same URL

### Add environment variables

You can add environment variables to the workflow:

```yaml
- name: Update Lambda function configuration
  run: |
    aws lambda update-function-configuration \
      --function-name ${{ env.FUNCTION_NAME }} \
      --environment Variables={CUSTOM_MESSAGE="Hello from ${{ env.USERNAME }}!"}
```

---

## 6. Production patterns

**Goal:** Understand production-ready deployment patterns.

### Compare local vs production

| Aspect | Local Development | Production Deployment |
|--------|-------------------|----------------------|
| **Environment** | LocalStack | Real AWS |
| **Authentication** | Local credentials | OIDC |
| **Build** | Manual | Automated |
| **Testing** | Ad-hoc | Automated |
| **Scaling** | Single user | Multi-tenant |

### Multi-environment strategy

This pattern scales to multiple environments:

```yaml
# Development branches
on:
  push:
    branches: ['feature-*', 'bugfix-*']
    # Creates: dev-feature-name-lambda

# Staging
on:
  push:
    branches: ['staging']
    # Creates: staging-lambda

# Production
on:
  push:
    branches: ['main']
    # Creates: production-lambda (with manual approval)
```

### Security best practices

1. **OIDC Authentication**: No static AWS secrets
2. **Least Privilege**: Minimal permissions per role
3. **Resource Tagging**: Easy identification and cleanup
4. **Function URLs**: Simpler than API Gateway for workshops

---

## 7. Troubleshooting

**Goal:** Diagnose and fix common deployment issues.

### Common problems

#### Permission denied errors

```bash
# Check your workflow logs
# Verify repository secrets are configured
# Ensure OIDC role trust relationship is correct
```

#### Build failures

```bash
# Check TypeScript compilation
# Verify Node.js version compatibility
# Look at the build logs in GitHub Actions
```

#### Function URL not working

```bash
# Wait a few minutes after deployment
# Check if function was created successfully
# Verify the URL from the workflow summary
```

### Debugging workflow

1. **GitHub Actions tab**: Real-time logs
2. **AWS CloudWatch**: Lambda execution logs
3. **AWS Console**: Verify function exists and has correct configuration

### Getting help

1. Check the **Actions** tab for detailed error logs
2. Look at the specific workflow step that failed
3. Ask to workshop facilitator for assistance

---

## 8. Cleanup

**Goal:** Properly clean up workshop resources.

### Participants

1. Click on **"Branch: YOUR-USERNAME-workshop"** dropdown
2. Select **"main"** branch
3. Click **"Code"** tab
4. Click on **"X branches"** (where X is number of branches)
5. Find your branch and click the **trash icon** to delete it
6. Confirm deletion

### Workshop facilitator

```shell
# Remove all workshop AWS resources
./scripts/cleanup-aws.sh
```

> [!WARNING]
> Only run the cleanup script if you're the workshop facilitator. This will delete all Lambda functions created during the workshop.

### What gets cleaned up

- All Lambda functions with workshop tags
- Lambda execution roles
- CloudWatch log groups
- Function URL configurations
- Workshop IAM policies

---

## 🎉 Congratulations

You've successfully built a production-ready CI/CD pipeline that:

✅ **Deploys** Lambda functions automatically  
✅ **Uses** secure OIDC authentication  
✅ **Scales** to multiple participants  
✅ **Includes** automated testing  
✅ **Demonstrates** modern cloud practices  

### Next steps

- Try adding automated testing to your workflow
- Explore API Gateway integration for more complex routing
- Learn about infrastructure as code with CDK/Terraform
- Build multi-environment pipelines with approval workflows

### Keep learning

- **GitHub Actions Documentation**: https://docs.github.com/en/actions
- **AWS Lambda Developer Guide**: https://docs.aws.amazon.com/lambda/
- **OIDC with AWS**: https://docs.github.com/en/actions/deployment/security-hardening-your-deployments/configuring-openid-connect-in-amazon-web-services