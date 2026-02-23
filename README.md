# Build GitHub Actions to Deploy AWS Lambda

This workshop teaches you how to **build a GitHub Actions workflow from scratch** that automatically deploys AWS Lambda functions.  
You'll start with an empty workflow and incrementally add pieces until you have a production-ready CI/CD pipeline.

---

## 🛑 Prerequisites

### General/global prerequisites

Before beginning this workshop, please ensure your environment is correctly set up by following the instructions in our prerequisites documentation:

➡️ **[Prerequisites guide](https://github.com/daemon-labs-io/prerequisites)**

---

## Section 1: Getting Started (10 minutes)

**Goal:** Create your workshop branch and understand the starting point.

### Create your workshop branch

1. Click the "Branch: main" button in the top-left corner
2. Type your branch name: `YOUR-USERNAME-workshop`
   - Replace `YOUR-USERNAME` with your actual GitHub username
3. Click "Create branch: YOUR-USERNAME-workshop"

> [!NOTE]
> This naming convention allows everyone to deploy to their own Lambda function without conflicts.

### Examine the starting workflow

1. Click on the **`.github/workflows/deploy-lambda.yaml`** file
2. Notice it's mostly empty with TODO comments
3. This is your blank slate - you'll build this step by step!

> [!TIP]
> There's also a `deploy-lambda-solution.yaml` file with the complete solution for reference.

### Trigger your first workflow

1. Click **"Add file"** → **"Create new file"**
2. Name the file: `workshop-log.md`
3. Add content in the editor:
   ```markdown
   # Workshop started by YOUR-NAME
   Date: $(date)
   ```
4. Scroll down and click **"Commit new file"**
5. Leave the default commit message and click **"Commit new file"** again

6. Click the **"Actions"** tab - you should see a workflow run with just the checkout step

---

## Section 2: GitHub Actions Foundation (10 minutes)

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

### Extract Username from Branch

```yaml
- name: Extract username from branch
  run: |
    USERNAME=$(echo ${{ github.ref_name }} | sed 's/-workshop//')
    echo "USERNAME=$USERNAME" >> $GITHUB_ENV
    echo "FUNCTION_NAME=${USERNAME}-workshop-lambda" >> $GITHUB_ENV
    echo "🚨 Deploying for user: $USERNAME"
```

### Set Up Node.js Build Environment

```yaml
- name: Setup Node.js
  uses: actions/setup-node@v4
  with:
    node-version: '24'
    cache: 'npm'
    cache-dependency-path: production/package-lock.json
```

**Your turn:** Add all three steps, commit, and watch the workflow build your foundation!

---

## Section 3: Build and Package (10 minutes)

**Goal:** Add the build process to compile and package your Lambda function.

### Install Dependencies and Build TypeScript

```yaml
- name: Install dependencies and build
  working-directory: ./production
  run: |
    npm ci
    npm run build
```

### Package Lambda for Deployment

```yaml
- name: Package Lambda function
  working-directory: ./production
  run: |
    npm run package
    echo "📦 Package created"
    ls -la function.zip
```

> [!TIP]
> Check the `production/package.json` to see what the `build` and `package` scripts do.

**Your turn:** Add the build steps and commit. Your workflow should now successfully build and package the Lambda!

---

## Section 4: Deploy to AWS Lambda (10 minutes)

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
  working-directory: ./production
  run: |
    aws lambda create-function \
      --function-name ${{ env.FUNCTION_NAME }} \
      --runtime nodejs20.x \
      --role ${{ secrets.LAMBDA_EXECUTION_ROLE_ARN }} \
      --handler build/index.handler \
      --zip-file fileb://function.zip \
      --description "Workshop Lambda deployed by ${{ env.USERNAME }}" \
      --environment Variables={GITHUB_ACTOR=${{ env.USERNAME }}} \
      --tags Workshop=GitHubActions,User=${{ env.USERNAME }}
    echo "🎉 Lambda function ${{ env.FUNCTION_NAME }} created!"

- name: Update Lambda function code
  if: steps.check_lambda.outputs.exists == 'true'
  working-directory: ./production
  run: |
    aws lambda update-function-code \
      --function-name ${{ env.FUNCTION_NAME }} \
      --zip-file fileb://function.zip
    echo "🔄 Lambda function ${{ env.FUNCTION_NAME }} updated!"
```

**Your turn:** Add the deployment logic and commit. Your first Lambda should now be created!

---

## Section 5: Make Lambda Accessible (10 minutes)

**Goal:** Add HTTP access and testing to complete your deployment pipeline.

### Create Function URL for HTTP Access

```yaml
- name: Get Lambda function URL
  id: lambda_info
  run: |
    # Check if function has a URL config
    if aws lambda get-function-url-config --function-name ${{ env.FUNCTION_NAME }} >/dev/null 2>&1; then
      FUNCTION_URL=$(aws lambda get-function-url-config --function-name ${{ env.FUNCTION_NAME }} --query 'FunctionUrl' --output text)
      echo "url=$FUNCTION_URL" >> $GITHUB_OUTPUT
    else
      echo "url=" >> $GITHUB_OUTPUT
    fi

- name: Create Function URL (if not exists)
  if: steps.lambda_info.outputs.url == ''
  run: |
    FUNCTION_URL=$(aws lambda create-function-url-config \
      --function-name ${{ env.FUNCTION_NAME }} \
      --auth-type NONE \
      --query 'FunctionUrl' \
      --output text)
    
    # Add permission for public access
    aws lambda add-permission \
      --function-name ${{ env.FUNCTION_NAME }} \
      --action lambda:InvokeFunctionUrl \
      --principal '*' \
      --statement-id function-url-public-access \
      --function-url-auth-type NONE
    
    echo "🔗 Function URL created: $FUNCTION_URL"
    echo "url=$FUNCTION_URL" >> $GITHUB_OUTPUT
```

### Test Your Deployed Lambda

```yaml
- name: Test Lambda function
  run: |
    echo "🧪 Testing Lambda function..."
    FUNCTION_URL=$(aws lambda get-function-url-config --function-name ${{ env.FUNCTION_NAME }} --query 'FunctionUrl' --output text)
    
    # Wait a moment for function to be ready
    sleep 5
    
    # Test the function
    RESPONSE=$(curl -s -X POST "$FUNCTION_URL" -d '{}' -H "Content-Type: application/json")
    echo "📋 Lambda response:"
    echo "$RESPONSE" | jq '.'
    
    # Extract status from response
    STATUS=$(echo "$RESPONSE" | jq -r '.statusCode // "unknown"')
    if [ "$STATUS" = "200" ]; then
      echo "✅ Lambda function is working correctly!"
    else
      echo "⚠️ Lambda function returned status: $STATUS"
    fi
```

**Your turn:** Add the URL creation and testing. Your Lambda should now be publicly accessible!

---

## Section 6: Complete and Iterate (10 minutes)

**Goal:** Add deployment summary and iterate on your workflow.

### Add Deployment Summary

```yaml
- name: Summary
  run: |
    echo "## 🚀 Deployment Summary" >> $GITHUB_STEP_SUMMARY
    echo "" >> $GITHUB_STEP_SUMMARY
    echo "**User:** ${{ env.USERNAME }}" >> $GITHUB_STEP_SUMMARY
    echo "**Function Name:** ${{ env.FUNCTION_NAME }}" >> $GITHUB_STEP_SUMMARY
    echo "**Region:** ${{ env.AWS_REGION }}" >> $GITHUB_STEP_SUMMARY
    
    FUNCTION_URL=$(aws lambda get-function-url-config --function-name ${{ env.FUNCTION_NAME }} --query 'FunctionUrl' --output text)
    echo "**Function URL:** $FUNCTION_URL" >> $GITHUB_STEP_SUMMARY
    echo "" >> $GITHUB_STEP_SUMMARY
    echo "### 🧪 Test your Lambda:" >> $GITHUB_STEP_SUMMARY
    echo '```bash' >> $GITHUB_STEP_SUMMARY
    echo "curl -X POST \"$FUNCTION_URL\" -d '{}' -H \"Content-Type: application/json\"" >> $GITHUB_STEP_SUMMARY
    echo '```' >> $GITHUB_STEP_SUMMARY
```

### Test Your Complete Deployment

From the GitHub Actions workflow summary, find your Function URL and test it:

```shell
# Use the URL from your workflow summary
curl -X POST "YOUR-FUNCTION-URL" \
  -d '{"message": "Hello from workshop!"}' \
  -H "Content-Type: application/json"
```

### Iterate and Improve

1. Navigate to **`production/src/index.ts`**
2. Click the **pencil icon** and modify the handler
3. Add a custom message or logic
4. Commit and watch the automatic redeployment
5. Test your updated function with the same URL

**Your turn:** Complete your workflow and make your first modification!

---

## 🎉 Congratulations!

You've **built a complete GitHub Actions workflow from scratch** that:

✅ **Builds** TypeScript Lambda functions automatically  
✅ **Deploys** to AWS Lambda with secure OIDC authentication  
✅ **Creates** HTTP endpoints via Function URLs  
✅ **Tests** deployments automatically  
✅ **Updates** existing functions on code changes  

### Next Steps

- Try adding automated testing to your workflow
- Explore API Gateway integration for more complex routing
- Learn about infrastructure as code with CDK/Terraform
- Build multi-environment pipelines with approval workflows

### Keep Learning

- **GitHub Actions Documentation**: https://docs.github.com/en/actions
- **AWS Lambda Developer Guide**: https://docs.aws.amazon.com/lambda/
- **OIDC with AWS**: https://docs.github.com/en/actions/deployment/security-hardening-your-deployments/configuring-openid-connect-in-amazon-web-services
