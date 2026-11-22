#!/usr/bin/env bash
# Source this file from a GitLab CI job to exchange the job's AWS OIDC token
# for short-lived ECR push credentials. No static AWS key is used or stored.
#
# Required environment:
#   AWS_OIDC_TOKEN          - GitLab id_token with aud=sts.amazonaws.com
#   AWS_ECR_PUSH_ROLE_ARN   - role trusted by the GitLab project and branch
# Optional:
#   AWS_REGION              - defaults to ap-south-1

# shellcheck shell=bash

AWS_CLI_VERSION="2.42.1"
AWS_CLI_SHA256="ff2631c32c5db291b099600f404bc493454ec66c125ff4604625da90480c1f47"
AWS_CLI_ZIP="https://awscli.amazonaws.com/awscli-exe-linux-x86_64-${AWS_CLI_VERSION}.zip"
AWS_REGION="${AWS_REGION:-ap-south-1}"

: "${AWS_OIDC_TOKEN:?AWS_OIDC_TOKEN is required}"
: "${AWS_ECR_PUSH_ROLE_ARN:?AWS_ECR_PUSH_ROLE_ARN is required}"

if ! command -v aws >/dev/null 2>&1; then
  install_dir="${RUNNER_TEMP:-/tmp}/awscli-${AWS_CLI_VERSION}"
  mkdir -p "$install_dir"
  curl -fsSL "$AWS_CLI_ZIP" -o "$install_dir/awscliv2.zip"
  printf '%s  %s\n' "$AWS_CLI_SHA256" "$install_dir/awscliv2.zip" | sha256sum -c -
  unzip -q -o "$install_dir/awscliv2.zip" -d "$install_dir"
  "$install_dir/aws/install" --install-dir "$install_dir/v2" \
    --bin-dir "$install_dir/bin" --update
  export PATH="$install_dir/bin:$PATH"
fi

token_file="${RUNNER_TEMP:-/tmp}/aws-oidc-token"
printf '%s' "$AWS_OIDC_TOKEN" >"$token_file"
chmod 600 "$token_file"

credentials="$(aws sts assume-role-with-web-identity \
  --region "$AWS_REGION" \
  --role-arn "$AWS_ECR_PUSH_ROLE_ARN" \
  --role-session-name "gitlab-${CI_PROJECT_ID:-unknown}-${CI_PIPELINE_ID:-unknown}" \
  --web-identity-token "file://$token_file" \
  --query Credentials --output json)"
rm -f "$token_file"

export AWS_ACCESS_KEY_ID
export AWS_SECRET_ACCESS_KEY
export AWS_SESSION_TOKEN
export AWS_REGION
export AWS_SDK_LOAD_CONFIG=true
AWS_ACCESS_KEY_ID="$(printf '%s' "$credentials" | python3 -c 'import json,sys; print(json.load(sys.stdin)["AccessKeyId"])')"
AWS_SECRET_ACCESS_KEY="$(printf '%s' "$credentials" | python3 -c 'import json,sys; print(json.load(sys.stdin)["SecretAccessKey"])')"
AWS_SESSION_TOKEN="$(printf '%s' "$credentials" | python3 -c 'import json,sys; print(json.load(sys.stdin)["SessionToken"])')"
unset credentials

echo "Assumed ${AWS_ECR_PUSH_ROLE_ARN} with short-lived STS credentials."
