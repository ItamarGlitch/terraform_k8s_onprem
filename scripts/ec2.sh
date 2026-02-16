#!/usr/bin/env bash
set -euo pipefail

export AWS_PROFILE="${AWS_PROFILE:-dev}"

S3_BUCKET="930579047961-tfstate"
S3_REGION="us-east-1"
STATE_FILE="/tmp/ec2-terraform-state-$$.json"
STATE_KEY="services/dev/ec2.tfstate"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
KEY_PATH="${PROJECT_ROOT}/ec2-key.pem"

fetch_state() {
  if ! aws s3 cp "s3://${S3_BUCKET}/${STATE_KEY}" "${STATE_FILE}" --region "${S3_REGION}" 2>/dev/null; then
    echo "Failed to fetch state. Run deploy first or check AWS credentials."
    return 1
  fi
  return 0
}

update_ip_md() {
  local outputs
  outputs=$(terraform output -json 2>/dev/null || true)
  if [ -n "${outputs}" ]; then
    {
      echo "## EC2 Instances"
      echo ""
      echo "SSH key: \`${KEY_PATH}\`"
      echo ""
      echo "| # | Instance | Instance ID | Private IP | Public IP |"
      echo "|---|----------|-------------|------------|-----------|"
      jq -r '
        . as $root |
        ($root.instance_ids.value | keys) as $names |
        range(0; $names | length) as $i |
        ($names[$i]) as $n |
        "| \($i + 1) | \($n) | \($root.instance_ids.value[$n]) | \($root.instance_private_ips.value[$n] // "-") | \($root.instance_public_ips.value[$n] // "-") |"
      ' <<< "${outputs}"
      echo ""
      echo "Example: \`ssh -i ec2-key.pem ubuntu@<public_ip>\`"
    } > "${PROJECT_ROOT}/ip.md"
    echo "Updated ip.md"
  fi
}

do_list() {
  echo "Pulling state from s3://${S3_BUCKET}/${STATE_KEY}..."
  if ! fetch_state; then
    return 1
  fi

  if ! command -v jq &>/dev/null; then
    echo "jq is required. Install with: apt install jq"
    rm -f "${STATE_FILE}"
    return 1
  fi

  OUTPUTS=$(cat "${STATE_FILE}")
  NAMES=$(jq -r '.outputs.instance_ids.value | keys[]?' "${STATE_FILE}" 2>/dev/null || true)
  rm -f "${STATE_FILE}"

  if [ -z "${NAMES}" ]; then
    echo "No running EC2 instances in state."
    return 0
  fi

  echo ""
  echo "All EC2 instances (from remote state):"
  echo ""
  echo "| # | Instance | Instance ID | Private IP | Public IP |"
  echo "|---|----------|-------------|------------|-----------|"
  jq -r '
    . as $root |
    ($root.outputs.instance_ids.value | keys) as $names |
    range(0; $names | length) as $i |
    ($names[$i]) as $n |
    "| \($i + 1) | \($n) | \($root.outputs.instance_ids.value[$n]) | \($root.outputs.instance_private_ips.value[$n] // "-") | \($root.outputs.instance_public_ips.value[$n] // "-") |"
  ' <<< "${OUTPUTS}"
  echo ""
  if [ -f "${KEY_PATH}" ]; then
    echo "SSH key: ${KEY_PATH}"
    echo "Example: ssh -i ec2-key.pem ubuntu@<public_ip>"
  fi
}

do_deploy() {
  echo "Pulling state from s3://${S3_BUCKET}/${STATE_KEY}..."
  if fetch_state 2>/dev/null && command -v jq &>/dev/null; then
    EXISTING=$(jq -r '.outputs.instance_ids.value | keys[]?' "${STATE_FILE}" 2>/dev/null || true)
    rm -f "${STATE_FILE}"
    if [ -n "${EXISTING}" ]; then
      echo "Existing instances:"
      echo "${EXISTING}" | nl -w2 -s'. '
      echo ""
    fi
  fi

  read -rp "Enter instance name(s), comma-separated: " INPUT
  INSTANCE_NAMES=$(echo "${INPUT}" | tr ',' '\n' | tr -d ' ' | grep -v '^$')

  if [ -z "${INSTANCE_NAMES}" ]; then
    echo "No instance names provided."
    return 1
  fi

  JSON_NAMES=$(echo "${INSTANCE_NAMES}" | sed 's/^/"/;s/$/"/' | paste -sd ',' | sed 's/^/[/;s/$/]/')
  echo ""
  echo "Instance names: ${JSON_NAMES}"
  echo ""

  cd "${PROJECT_ROOT}"
  terraform apply -auto-approve -var="instance_names=${JSON_NAMES}"
  update_ip_md
}

do_manage() {
  echo "Pulling state from s3://${S3_BUCKET}/${STATE_KEY}..."
  if ! fetch_state; then
    return 1
  fi

  if ! command -v jq &>/dev/null; then
    echo "jq is required. Install with: apt install jq"
    rm -f "${STATE_FILE}"
    return 1
  fi

  NAMES=$(jq -r '.outputs.instance_ids.value | keys[]?' "${STATE_FILE}" 2>/dev/null || true)
  OUTPUTS=$(cat "${STATE_FILE}")
  rm -f "${STATE_FILE}"

  if [ -z "${NAMES}" ]; then
    echo "No running EC2 instances in state."
    read -rp "Enter new instance name to add (or Enter to quit): " NEW_NAME
    if [ -n "${NEW_NAME}" ]; then
      cd "${PROJECT_ROOT}"
      JSON_NAMES=$(echo "${NEW_NAME}" | tr ',' '\n' | tr -d ' ' | grep -v '^$' | sed 's/^/"/;s/$/"/' | paste -sd ',' | sed 's/^/[/;s/$/]/')
      terraform apply -auto-approve -var="instance_names=${JSON_NAMES}"
      update_ip_md
    fi
    return 0
  fi

  echo ""
  echo "All EC2 instances:"
  echo ""
  echo "| # | Instance | Instance ID | Private IP | Public IP |"
  echo "|---|----------|-------------|------------|-----------|"
  jq -r '
    . as $root |
    ($root.outputs.instance_ids.value | keys) as $names |
    range(0; $names | length) as $i |
    ($names[$i]) as $n |
    "| \($i + 1) | \($n) | \($root.outputs.instance_ids.value[$n]) | \($root.outputs.instance_private_ips.value[$n] // "-") | \($root.outputs.instance_public_ips.value[$n] // "-") |"
  ' <<< "${OUTPUTS}"
  echo ""
  if [ -f "${KEY_PATH}" ]; then
    echo "SSH key: ${KEY_PATH}"
    echo ""
  fi
  echo "Enter new instance NAME to add (or Enter to quit)"
  read -rp "> " INPUT

  if [ -z "${INPUT}" ]; then
    return 0
  fi

  cd "${PROJECT_ROOT}"
  NEW_NAMES=$(echo -e "${NAMES}\n${INPUT}" | grep -v '^$')
  JSON_NAMES=$(echo "${NEW_NAMES}" | sed 's/^/"/;s/$/"/' | paste -sd ',' | sed 's/^/[/;s/$/]/')
  echo "Adding ${INPUT}..."
  terraform apply -auto-approve -var="instance_names=${JSON_NAMES}"
  update_ip_md
}

do_destroy() {
  echo "Pulling state from s3://${S3_BUCKET}/${STATE_KEY}..."
  if ! fetch_state; then
    return 1
  fi

  if ! command -v jq &>/dev/null; then
    echo "jq is required. Install with: apt install jq"
    rm -f "${STATE_FILE}"
    return 1
  fi

  NAMES=$(jq -r '.outputs.instance_ids.value | keys[]?' "${STATE_FILE}" 2>/dev/null || true)
  OUTPUTS=$(cat "${STATE_FILE}")
  rm -f "${STATE_FILE}"

  if [ -z "${NAMES}" ]; then
    echo "No running EC2 instances to destroy."
    return 0
  fi

  echo ""
  echo "Running EC2 instances:"
  echo ""
  echo "| # | Instance | Instance ID | Private IP | Public IP |"
  echo "|---|----------|-------------|------------|-----------|"
  jq -r '
    . as $root |
    ($root.outputs.instance_ids.value | keys) as $names |
    range(0; $names | length) as $i |
    ($names[$i]) as $n |
    "| \($i + 1) | \($n) | \($root.outputs.instance_ids.value[$n]) | \($root.outputs.instance_private_ips.value[$n] // "-") | \($root.outputs.instance_public_ips.value[$n] // "-") |"
  ' <<< "${OUTPUTS}"
  echo ""
  read -rp "Enter instance NUMBER to destroy (or Enter to cancel): " INPUT

  if [ -z "${INPUT}" ]; then
    echo "Cancelled."
    return 0
  fi

  if ! [[ "${INPUT}" =~ ^[0-9]+$ ]]; then
    echo "Invalid number."
    return 1
  fi

  REMOVE_NAME=$(echo "${NAMES}" | sed -n "${INPUT}p")
  if [ -z "${REMOVE_NAME}" ]; then
    echo "Invalid number."
    return 1
  fi

  REMAINING=$(echo "${NAMES}" | grep -v "^${REMOVE_NAME}$" | grep -v '^$' || true)
  if [ -z "${REMAINING}" ]; then
    JSON_NAMES="[]"
  else
    JSON_NAMES=$(echo "${REMAINING}" | sed 's/^/"/;s/$/"/' | paste -sd ',' | sed 's/^/[/;s/$/]/')
  fi

  cd "${PROJECT_ROOT}"
  echo "Destroying ${REMOVE_NAME}..."
  terraform apply -auto-approve -var="instance_names=${JSON_NAMES}"
  update_ip_md
}

show_menu() {
  echo ""
  echo "What do you want to do?"
  echo "  1) List instances"
  echo "  2) Deploy new instance(s)"
  echo "  3) Add instance"
  echo "  4) Destroy instance"
  echo "  5) Quit"
  echo ""
  read -rp "Choice [1-5]: " choice
  case "${choice}" in
    1) do_list ;;
    2) do_deploy ;;
    3) do_manage ;;
    4) do_destroy ;;
    5) echo "Bye."; exit 0 ;;
    *) echo "Invalid choice."; exit 1 ;;
  esac
}

if [ $# -ge 1 ]; then
  case "$1" in
    list)    do_list ;;
    deploy)  do_deploy ;;
    add)     do_manage ;;
    destroy) do_destroy ;;
    *) echo "Usage: $0 [list|deploy|add|destroy]"; exit 1 ;;
  esac
else
  show_menu
fi
