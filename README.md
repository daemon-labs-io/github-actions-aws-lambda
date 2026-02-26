# Build GitHub Actions to Deploy AWS Lambda

This workshop teaches you how to **build a GitHub Actions workflow from scratch** that automatically deploys AWS Lambda functions.  
You'll start with an empty workflow and incrementally add pieces until you have a production-ready CI/CD pipeline.

---

## 🛑 Prerequisites

### General/global prerequisites

Before beginning this workshop, please ensure your environment is correctly set up by following the instructions in our prerequisites documentation:

➡️ **[Prerequisites guide](https://github.com/daemon-labs-io/prerequisites)**

---

## Section 1: Getting started

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
    paths:
      - .github/**
      - lambda/**

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

> [!TIP]
> The `paths:` filter means the workflow only runs when files in `.github/**` or `lambda/**` change. This saves CI minutes by skipping runs when only README or other files are modified!

Scroll down and click **"Commit new file"**, then leave the default commit message and click **"Commit new file"** again.

### Open a pull request

Right-click the **"Pull requests"** tab in the navigation and open it in a new tab.

Click **"New pull request"**, select your branch as the source (e.g., `gary-workshop`), ensure the base is `main`, then click **"Create pull request"**.

Click the **"Actions"** link from your PR to see your workflow run!

### What can GitHub Actions do?

- **Triggers** - Run workflows on push, pull request, schedule, manual dispatch, or webhook events
- **Jobs** - Group steps that run on the same runner; jobs can run in parallel or depend on each other
- **Steps** - Execute shell commands or use pre-built actions
- **Actions** - Reusable units of work from GitHub Marketplace (or build your own)

> [!NOTE]
> Want to learn more about workflow syntax? Check out the [GitHub Actions workflow reference](https://docs.github.com/en/actions/reference/workflows-and-actions/workflow-syntax).

---

## Section 2: GitHub Actions foundation

**Goal:** Add the core GitHub Actions pieces for authentication and setup.

### Configure AWS authentication

Add this step after the checkout step:

```yaml
- name: Configure AWS Credentials
  uses: aws-actions/configure-aws-credentials@v6
  with:
    role-to-assume: ${{ secrets.AWS_ROLE_ARN }}
    aws-region: ${{ env.AWS_REGION }}
```

### Set up Node.js build environment

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

## Section 3: Build and package

**Goal:** Add the build process to compile and package your Lambda function.

### Install dependencies and build TypeScript

```yaml
- name: Install dependencies
  working-directory: ./lambda
  run: npm ci
- name: Build TypeScript
  working-directory: ./lambda
  run: npm run build
```

### Package Lambda for deployment

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

### Check if Lambda already exists

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

### Create new Lambda or update existing

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

## Section 5: Test your deployment

**Goal:** Verify your Lambda function is working correctly.

### Test your deployed Lambda

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

## Section 6: Simplify with reusable actions

**Goal:** See how pre-built actions can simplify your workflow.

You've now built a complete deployment pipeline using raw AWS CLI commands. Let's see how we can simplify it!

### Replace deployment with aws-lambda-deploy

The aws-lambda-deploy action handles packaging and deployment automatically:

- Packaging the code (zip)
- Checking if the function exists
- Creating or updating the function

Replace the **Section 4** deployment steps and keep the **Section 5** test step:

```yaml
- name: Deploy to Lambda
  uses: aws-actions/aws-lambda-deploy@v1
  with:
    function-name: ${{ env.FUNCTION_NAME }}
    function-description: "Workshop Lambda deployed by ${{ github.actor }}"
    code-artifacts-dir: ./lambda
    handler: build/index.handler
    runtime: nodejs24.x
```

> [!TIP]
> The action also supports environment variables, memory size, timeout, and many other options!

### Test your simplified workflow

Commit your changes, watch the workflow run, and notice how much simpler the deployment step is!

### Compare the results

The aws-lambda-deploy action eliminates the packaging step (zip) and simplifies deployment:

| Approach | What it does | Lines |
|----------|--------------|-------|
| Raw CLI | Build → Package (zip) → Deploy → Test | ~44 |
| aws-lambda-deploy | Build → Deploy (handles packaging) → Test | ~24 |

Both approaches work - the action just makes it easier!

### Add environment variables

Let's see how to pass configuration to your Lambda using environment variables. Update your deployment to include some:

```yaml
- name: Deploy to Lambda
  uses: aws-actions/aws-lambda-deploy@v1
  with:
    function-name: ${{ env.FUNCTION_NAME }}
    function-description: "Workshop Lambda deployed by ${{ github.actor }}"
    code-artifacts-dir: ./lambda
    handler: build/index.handler
    runtime: nodejs24.x
    env-vars: |
      GITHUB_ACTOR=${{ github.actor }}
      ENVIRONMENT=workshop
```

Now let's verify the environment variables are set:

```yaml
- name: Verify environment variables
  run: |
    echo "🔍 Checking Lambda configuration..."
    aws lambda get-function-configuration \
      --function-name ${{ env.FUNCTION_NAME }} \
      --query 'Environment' \
      --output table
```

> [!NOTE]
> Environment variables are a great way to configure your Lambda without changing code!

---

## 🎉 Congratulations

You've **built a complete GitHub Actions workflow from scratch** that:

✅ **Builds** TypeScript Lambda functions automatically  
✅ **Deploys** to AWS Lambda with secure OIDC authentication  
✅ **Creates** HTTP endpoints via Function URLs  
✅ **Learned** both raw CLI commands and pre-built actions  
✅ **Can simplify** deployments with aws-lambda-deploy
