#!/bin/bash

# This script automates building and pushing multi-architecture Docker images
# and creating a manifest list for all projects in the Nx workspace.

# Exit immediately if a command exits with a non-zero status.
set -euo pipefail

# --- Configuration ---
# Replace with your AWS Account ID and Region if they are different.
AWS_ACCOUNT_ID="318112817098"
AWS_REGION="us-east-1"
ECR_REGISTRY="${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com"

# --- Main Script ---

echo "Logging in to Amazon ECR..."
aws ecr get-login-password --region "${AWS_REGION}" | docker login --username AWS --password-stdin "${ECR_REGISTRY}"
echo "Login Succeeded."

# Get a list of all project names that have a "container" target.
PROJECTS=$(npx nx show projects --target container)

for project in ${PROJECTS}; do
  echo "--- Processing project: ${project} ---"

  # The repository URI as defined in your container target
  REPOSITORY_URI="${ECR_REGISTRY}/retail-store/${project}"

  echo "Building and pushing multi-arch images for ${project}..."
  # This command builds for both arm64 and amd64 and pushes them
  # It creates tags like: my-repo:latest-amd64 and my-repo:latest-arm64
  npx nx container "${project}" --configuration=publish

  echo "Creating and pushing manifest for ${project}..."
  # This command uses the script in scripts/create-manifest.sh to create a
  # manifest list that points to the arch-specific images.
  npx nx manifest "${project}" --args="--repository ${REPOSITORY_URI} --tag latest"

  echo "--- Finished processing project: ${project} ---"
done

echo "All projects have been built and pushed successfully."