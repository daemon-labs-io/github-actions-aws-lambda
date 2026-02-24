#!/bin/bash

# GitHub Actions AWS Lambda Workshop Cleanup Script
# This script removes all workshop-related AWS resources

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

echo "🧹 Cleaning up GitHub Actions AWS Lambda Workshop Environment"
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

# Clean up workshop Lambda functions
echo "🗑️ Cleaning up workshop Lambda functions..."
FUNCTIONS=$(aws_cmd lambda list-functions --query 'Functions[?contains(Tags[?Key==`Workshop`].Value, `GitHubActions`)].FunctionName' --output text)

if [ -n "$FUNCTIONS" ]; then
    for FUNCTION_NAME in $FUNCTIONS; do
        echo "Deleting function: $FUNCTION_NAME"
        
        # Remove function URL if it exists
        if aws_cmd lambda get-function-url-config --function-name "$FUNCTION_NAME" >/dev/null 2>&1; then
            echo "  Removing function URL..."
            aws_cmd lambda delete-function-url-config --function-name "$FUNCTION_NAME" 2>/dev/null || true
        fi
        
        # Delete the function
        aws_cmd lambda delete-function --function-name "$FUNCTION_NAME"
        echo "  ✅ Deleted"
    done
else
    echo "✅ No workshop Lambda functions found"
fi
echo ""

# Clean up Lambda execution roles
echo "🗑️ Cleaning up Lambda execution roles..."
ROLES=$(aws_cmd iam list-roles --query 'Roles[?contains(RoleName, `workshop-lambda`) || contains(RoleName, `WorkshopLambda`)].RoleName' --output text)

if [ -n "$ROLES" ]; then
    for ROLE_NAME in $ROLES; do
        echo "Detaching policies from role: $ROLE_NAME"
        
        # List and detach all policies
        POLICIES=$(aws_cmd iam list-attached-role-policies --role-name "$ROLE_NAME" --query 'AttachedPolicies[].PolicyArn' --output text)
        for POLICY_ARN in $POLICIES; do
            aws_cmd iam detach-role-policy --role-name "$ROLE_NAME" --policy-arn "$POLICY_ARN"
        done
        
        # List and delete all inline policies
        INLINE_POLICIES=$(aws_cmd iam list-role-policies --role-name "$ROLE_NAME" --query 'PolicyNames[]' --output text)
        for INLINE_POLICY in $INLINE_POLICIES; do
            aws_cmd iam delete-role-policy --role-name "$ROLE_NAME" --policy-name "$INLINE_POLICY"
        done
        
        # Delete the role
        aws_cmd iam delete-role --role-name "$ROLE_NAME"
        echo "  ✅ Deleted role: $ROLE_NAME"
    done
else
    echo "✅ No Lambda execution roles found"
fi
echo ""

# Clean up workshop policies
echo "🗑️ Cleaning up workshop policies..."
POLICIES=$(aws_cmd iam list-policies --scope Local --query 'Policies[?contains(PolicyName, `LambdaWorkshop`) || contains(PolicyName, `workshop-lambda`)].Arn' --output text)

if [ -n "$POLICIES" ]; then
    for POLICY_ARN in $POLICIES; do
        POLICY_NAME=$(basename "$POLICY_ARN")
        echo "Deleting policy: $POLICY_NAME"
        
        # Get all roles and detach this policy
        ROLE_NAMES=$(aws_cmd iam list-entities-for-policy --policy-arn "$POLICY_ARN" --query 'PolicyRoles[].RoleName' --output text)
        for ROLE_NAME in $ROLE_NAMES; do
            aws_cmd iam detach-role-policy --role-name "$ROLE_NAME" --policy-arn "$POLICY_ARN"
        done
        
        # Delete the policy
        aws_cmd iam delete-policy --policy-arn "$POLICY_ARN"
        echo "  ✅ Deleted policy: $POLICY_NAME"
    done
else
    echo "✅ No workshop policies found"
fi
echo ""

# Clean up log groups
echo "🗑️ Cleaning up log groups..."
LOG_GROUPS=$(aws_cmd logs describe-log-groups --log-group-name-prefix '/aws/lambda/' --query 'logGroups[?contains(logGroupName, `workshop-lambda`) || contains(logGroupName, `-workshop-lambda`)].logGroupName' --output text)

if [ -n "$LOG_GROUPS" ]; then
    for LOG_GROUP in $LOG_GROUPS; do
        echo "Deleting log group: $LOG_GROUP"
        aws_cmd logs delete-log-group --log-group-name "$LOG_GROUP"
        echo "  ✅ Deleted"
    done
else
    echo "✅ No workshop log groups found"
fi
echo ""

echo "🎉 AWS Environment Cleanup Complete!"
echo ""
echo "✅ All workshop-related AWS resources have been removed."