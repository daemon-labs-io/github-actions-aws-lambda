# Build GitHub Actions to Deploy AWS Lambda

This workshop teaches you how to **build a GitHub Actions workflow from scratch** that automatically deploys AWS Lambda functions.  
You'll start with an empty workflow and incrementally add pieces until you have a production-ready CI/CD pipeline.

---

## 🛑 Prerequisites

### General/global prerequisites

Before beginning this workshop, please ensure your environment is correctly set up by following the instructions in our prerequisites documentation:

➡️ **[Prerequisites guide](https://github.com/daemon-labs-io/prerequisites)**

---

## Section 1: Getting Started

**Goal:** Create your workshop branch and understand the starting point.

### Create your workshop branch

Open the repository in a new tab: [daemon-labs-io/github-actions-aws-lambda](https://github.com/daemon-labs-io/github-actions-aws-lambda) (right-click the link and "Open link in new tab" or use split view).

Click the **"Branch: main"** button in the top-left corner, type your branch name as `YOUR-USERNAME-workshop` (replacing `YOUR-USERNAME` with your actual GitHub username), then click **"Create branch: YOUR-USERNAME-workshop"**.

> [!NOTE]
> This naming convention allows everyone to deploy to their own Lambda function without conflicts.

### Create your workflow file

Click **"Add file"** → **"Create new file"** and name the file:

```text
.github/workflows/deploy-lambda.yaml
``` 

Add this minimal workflow:

```yaml
name: Deploy Lambda to AWS

on:
  push:
    branches: ["*-workshop"]

concurrency:
  group: ${{ github.workflow }}-${{ github.ref }}
  cancel-in-progress: true

env:
  AWS_REGION: eu-west-1

jobs:
  deploy:
    runs-on: ubuntu-latest
    env:
      FUNCTION_NAME: ${{ github.ref_name }}
    permissions:
      id-token: write
      contents: read
    steps:
      - name: Checkout repository
        uses: actions/checkout@v6
```

Scroll down and click **"Commit new file"**, then leave the default commit message and click **"Commit new file"** again.

### Open a pull request

Right-click the **"Pull requests"** tab in the navigation and open it in a new tab.

Click **"New pull request"**, select your branch as the source (e.g., `gary-workshop`), ensure the base is `main`, then click **"Create pull request"**.

Click the **"Actions"** link from your PR to see your workflow run!

---

## Section 2: GitHub Actions Foundation

**Goal:** Add the core GitHub Actions pieces for authentication and setup.

### Configure AWS Authentication

Add this step after the checkout step:

```yaml
- name: Configure AWS Credentials
  uses: aws-actions/configure-aws-credentials@v6
  with:
    role-to-assume: ${{ secrets.AWS_ROLE_ARN }}
    aws-region: ${{ env.AWS_REGION }}
```

### Set Up Node.js Build Environment

```yaml
- name: Setup Node.js
  uses: actions/setup-node@v6
  with:
    node-version: 24
    cache: npm
    cache-dependency-path: lambda/package-lock.json
```

**Your turn:** Add all three steps, commit, and watch the workflow build your foundation!

---

## Section 3: Build and Package

**Goal:** Add the build process to compile and package your Lambda function.

### Install Dependencies and Build TypeScript

```yaml
- name: Install dependencies
  working-directory: ./lambda
  run: npm ci
- name: Build TypeScript
  working-directory: ./lambda
  run: npm run build
```

### Package Lambda for Deployment

```yaml
- name: Package Lambda function
  working-directory: ./lambda
  run: npm run package
```

> [!TIP]
> Check the `lambda/package.json` to see what the `build` and `package` scripts do.

**Your turn:** Add the build steps and commit. Your workflow should now successfully build and package the Lambda!

---

## Section 4: Deploy to AWS Lambda

**Goal:** Add the logic to deploy your packaged Lambda to AWS.

### Check if Lambda Already Exists

```yaml
- name: Check if Lambda function exists
  id: check_lambda
  run: |
    if aws lambda get-function --function-name ${{ env.FUNCTION_NAME }} >/dev/null 2>&1; then
      echo "exists=true" >> $GITHUB_OUTPUT
      echo "✅ Lambda function ${{ env.FUNCTION_NAME }} exists"
    else
      echo "exists=false" >> $GITHUB_OUTPUT
      echo "➡️ Lambda function ${{ env.FUNCTION_NAME }} needs to be created"
    fi
```

### Create New Lambda or Update Existing

```yaml
- name: Create Lambda function
  if: steps.check_lambda.outputs.exists == 'false'
  working-directory: ./lambda
  run: |
    aws lambda create-function \
      --function-name ${{ env.FUNCTION_NAME }} \
      --runtime nodejs24.x \
      --role ${{ secrets.LAMBDA_EXECUTION_ROLE_ARN }} \
      --handler build/index.handler \
      --zip-file fileb://function.zip \
      --description "Workshop Lambda deployed by ${{ github.actor }}" \
      --environment Variables={GITHUB_ACTOR=${{ github.actor }}} \
      --tags Workshop=GitHubActions,User=${{ github.actor }}
    echo "🎉 Lambda function ${{ env.FUNCTION_NAME }} created!"

- name: Update Lambda function code
  if: steps.check_lambda.outputs.exists == 'true'
  working-directory: ./lambda
  run: |
    aws lambda update-function-code \
      --function-name ${{ env.FUNCTION_NAME }} \
      --zip-file fileb://function.zip
    echo "🔄 Lambda function ${{ env.FUNCTION_NAME }} updated!"
```

**Your turn:** Add the deployment logic and commit. Your first Lambda should now be created!

---

## Section 5: Test Your Deployment

**Goal:** Verify your Lambda function is working correctly.

### Test Your Deployed Lambda

```yaml
- name: Test Lambda function
  run: |
    echo "🧪 Testing Lambda function..."
    aws lambda invoke \
      --function-name ${{ env.FUNCTION_NAME }} \
      --payload '{}' \
      --log-type Tail \
      response.json
    
    echo "📋 Lambda response:"
    cat response.json
```

**Your turn:** Add the testing step. Your Lambda should now be deployed and working!

---

## Section 6: Simplify with Actions

**Goal:** See how pre-built actions can simplify your workflow.

You've now built a complete deployment pipeline using raw AWS CLI commands. Let's see how we can simplify it!

### Replace Deployment with aws-lambda-deploy

The aws-lambda-deploy action handles all of this automatically:

- Checking if the function exists
- Creating or updating the function
- Testing the function

Replace your **Section 4 and 5 steps** with this single action:

```yaml
- name: Deploy to Lambda
  uses: aws-actions/aws-lambda-deploy@v1
  with:
    function-name: ${{ env.FUNCTION_NAME }}
    function-description: "Workshop Lambda deployed by ${{ github.actor }}"
    code-artifacts-dir: ./lambda
    handler: index.handler
    runtime: nodejs24.x
```

> [!TIP]
> The action also supports environment variables, memory size, timeout, and many other options!

### Test Your Simplified Workflow

Commit your changes, watch the workflow run, and notice how much simpler the deployment step is!

### Compare the Results

| Approach               | Lines of Code | Steps    |
| ---------------------- | ------------- | -------- |
| Raw CLI (Sections 4-5) | ~30           | 4+ steps |
| aws-lambda-deploy     | ~10           | 1 step   |

Both approaches work - the action just makes it easier!

---

## 🎉 Congratulations

You've **built a complete GitHub Actions workflow from scratch** that:

✅ **Builds** TypeScript Lambda functions automatically  
✅ **Deploys** to AWS Lambda with secure OIDC authentication  
✅ **Creates** HTTP endpoints via Function URLs  
✅ **Learned** both raw CLI commands and pre-built actions  
✅ **Can simplify** deployments with aws-lambda-deploy

### Next Steps

- Try adding automated testing to your workflow
- Explore API Gateway integration for more complex routing
- Learn about infrastructure as code with CDK/Terraform
- Build multi-environment pipelines with approval workflows
