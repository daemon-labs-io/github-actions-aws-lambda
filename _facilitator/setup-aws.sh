#!/bin/bash

# GitHub Actions AWS Lambda Workshop Setup Script
# This script sets up the required AWS resources for the workshop

set -e

# Configuration
AWS_PROFILE=""
AWS_REGION="eu-west-1"
WORKSHOP_ROLE_NAME="GitHubActions-Lambda-Workshop"
LAMBDA_EXECUTION_ROLE_NAME="Lambda-Execution-Role-Workshop"

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -p|--profile)
            AWS_PROFILE="$2"
            shift 2
            ;;
        -r|--region)
            AWS_REGION="$2"
            shift 2
            ;;
        *)
            echo "Usage: $0 [-p|--profile <profile>] [-r|--region <region>]"
            exit 1
            ;;
    esac
done

# Helper function to run aws commands
aws_cmd() {
    local cmd="aws"
    if [[ -n "$AWS_PROFILE" ]]; then
        cmd="$cmd --profile $AWS_PROFILE"
    fi
    $cmd "$@"
}

echo "🚀 Setting up GitHub Actions AWS Lambda Workshop Environment"
echo "Region: $AWS_REGION"
echo ""

# Check AWS CLI is installed and configured
if ! command -v aws &> /dev/null; then
    echo "❌ AWS CLI is not installed. Please install it first."
    exit 1
fi

# Test AWS credentials
echo "🔍 Testing AWS credentials..."
aws_cmd sts get-caller-identity
echo ""

# Create OIDC provider for GitHub (if it doesn't exist)
echo "📝 Setting up GitHub OIDC provider..."
ACCOUNT_ID=$(aws_cmd sts get-caller-identity --query Account --output text)
GITHUB_OIDC_PROVIDER_ARN="arn:aws:iam::${ACCOUNT_ID}:oidc-provider/token.actions.githubusercontent.com"

if ! aws_cmd iam get-open-id-connect-provider --open-id-connect-provider-arn "$GITHUB_OIDC_PROVIDER_ARN" 2>/dev/null; then
    echo "Creating GitHub OIDC provider..."
    aws_cmd iam create-open-id-connect-provider \
        --url https://token.actions.githubusercontent.com \
        --client-id-list sts.amazonaws.com \
        --thumbprint-list 6938fd4d98bab03faadb97b34396831e3780aea1
    echo "✅ GitHub OIDC provider created"
else
    echo "✅ GitHub OIDC provider already exists"
fi
echo ""

# Create GitHub Actions role
echo "🔐 Creating GitHub Actions role: $WORKSHOP_ROLE_NAME"

# Create trust policy for GitHub Actions
cat > trust-policy.json << EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Principal": {
                "Federated": "arn:aws:iam::${ACCOUNT_ID}:oidc-provider/token.actions.githubusercontent.com"
            },
            "Action": "sts:AssumeRoleWithWebIdentity",
            "Condition": {
                "StringLike": {
                    "token.actions.githubusercontent.com:sub": "repo:daemon-labs-io/github-actions-aws-lambda:*"
                }
            }
        }
    ]
}
EOF

# Create permissions policy for workshop
cat > workshop-permissions.json << EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "lambda:CreateFunction",
                "lambda:UpdateFunctionCode",
                "lambda:GetFunction",
                "lambda:GetFunctionUrlConfig",
                "lambda:CreateFunctionUrlConfig",
                "lambda:DeleteFunctionUrlConfig",
                "lambda:AddPermission",
                "lambda:RemovePermission",
                "lambda:TagResource",
                "lambda:UntagResource",
                "logs:CreateLogGroup",
                "logs:CreateLogStream",
                "logs:PutLogEvents",
                "iam:PassRole",
                "iam:CreateRole",
                "iam:GetRole",
                "iam:DeleteRole",
                "iam:AttachRolePolicy",
                "iam:DetachRolePolicy",
                "iam:CreatePolicy",
                "iam:DeletePolicy"
            ],
            "Resource": "*"
        }
    ]
}
EOF

# Check if role already exists
if ! aws_cmd iam get-role --role-name $WORKSHOP_ROLE_NAME 2>/dev/null; then
    echo "Creating GitHub Actions role..."
    aws_cmd iam create-role \
        --role-name $WORKSHOP_ROLE_NAME \
        --assume-role-policy-document file://trust-policy.json \
        --description "GitHub Actions role for Lambda workshop" \
        --tags Key=Workshop,Value=GitHubActions
    
    # Attach permissions
    aws_cmd iam put-role-policy \
        --role-name $WORKSHOP_ROLE_NAME \
        --policy-name "LambdaWorkshopPermissions" \
        --policy-document file://workshop-permissions.json
    
    echo "✅ GitHub Actions role created"
else
    echo "✅ GitHub Actions role already exists, updating permissions..."
    aws_cmd iam put-role-policy \
        --role-name $WORKSHOP_ROLE_NAME \
        --policy-name "LambdaWorkshopPermissions" \
        --policy-document file://workshop-permissions.json
fi

WORKSHOP_ROLE_ARN="arn:aws:iam::${ACCOUNT_ID}:role/${WORKSHOP_ROLE_NAME}"
echo "📋 Role ARN: $WORKSHOP_ROLE_ARN"
echo ""

# Create Lambda execution role
echo "🏗️ Creating Lambda execution role: $LAMBDA_EXECUTION_ROLE_NAME"

# Create Lambda execution trust policy
cat > lambda-trust-policy.json << EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Principal": {
                "Service": "lambda.amazonaws.com"
            },
            "Action": "sts:AssumeRole"
        }
    ]
}
EOF

# Create Lambda execution permissions
cat > lambda-execution-permissions.json << EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "logs:CreateLogGroup",
                "logs:CreateLogStream",
                "logs:PutLogEvents"
            ],
            "Resource": "arn:aws:logs:*:*:*"
        },
        {
            "Effect": "Allow",
            "Action": [
                "s3:ListBuckets"
            ],
            "Resource": "*"
        }
    ]
}
EOF

if ! aws_cmd iam get-role --role-name $LAMBDA_EXECUTION_ROLE_NAME 2>/dev/null; then
    echo "Creating Lambda execution role..."
    aws_cmd iam create-role \
        --role-name $LAMBDA_EXECUTION_ROLE_NAME \
        --assume-role-policy-document file://lambda-trust-policy.json \
        --description "Lambda execution role for workshop" \
        --max-session-duration 3600 \
        --tags Key=Workshop,Value=GitHubActions
    
    # Attach permissions
    aws_cmd iam put-role-policy \
        --role-name $LAMBDA_EXECUTION_ROLE_NAME \
        --policy-name "LambdaWorkshopExecutionPermissions" \
        --policy-document file://lambda-execution-permissions.json
    
    echo "✅ Lambda execution role created"
else
    echo "✅ Lambda execution role already exists, updating permissions..."
    aws_cmd iam put-role-policy \
        --role-name $LAMBDA_EXECUTION_ROLE_NAME \
        --policy-name "LambdaWorkshopExecutionPermissions" \
        --policy-document file://lambda-execution-permissions.json
fi

LAMBDA_EXECUTION_ROLE_ARN="arn:aws:iam::${ACCOUNT_ID}:role/${LAMBDA_EXECUTION_ROLE_NAME}"
echo "📋 Lambda execution role ARN: $LAMBDA_EXECUTION_ROLE_ARN"
echo ""

# Cleanup temporary files
rm -f trust-policy.json workshop-permissions.json lambda-trust-policy.json lambda-execution-permissions.json

echo ""
echo "🎉 AWS Environment Setup Complete!"
echo ""
echo "📋 Required Repository Secrets:"
echo "=================================="
echo "AWS_ROLE_ARN: $WORKSHOP_ROLE_ARN"
echo "LAMBDA_EXECUTION_ROLE_ARN: $LAMBDA_EXECUTION_ROLE_ARN"
echo ""
echo "➡️ Add these secrets to your GitHub repository:"
echo "   1. Go to: https://github.com/daemon-labs-io/github-actions-aws-lambda/settings/secrets/actions"
echo "   2. Click 'New repository secret'"
echo "   3. Add the two secrets above"
echo ""
echo "🚀 Your workshop environment is ready!"
