#!/usr/bin/env bash
set -e

if [[ "$RUNNER_DEBUG" == "1" ]]; then
  set -x
fi

if [ -f ./.env ]; then
  source ./.env
fi

function requiredEnv() {
  for ENV in $@; do
      if [ -z "${!ENV}" ]; then
        echo "${ENV} variable must be set"
        exit 1
      fi
  done
}

SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

AWS_ACCOUNT=${AWS_ACCOUNT:-$(aws sts get-caller-identity --query "Account" --output text)}

requiredEnv AWS_ACCOUNT CLUSTER_NAME REGION CIDR

export CLUSTER_NAME=${CLUSTER_NAME:-$(whoami)}

echo "Verifying ROSA prerequisites."
echo "Check if AWS CLI is installed."; aws --version
echo "Check if ROSA CLI is installed."; rosa version
echo "Check if ELB service role is enabled."
if ! aws iam get-role --role-name "AWSServiceRoleForElasticLoadBalancing" --no-cli-pager; then
  aws iam create-service-linked-role --aws-service-name "elasticloadbalancing.amazonaws.com"
fi
rosa whoami
rosa verify quota

echo "Installing ROSA cluster ${CLUSTER_NAME}"

cd ${SCRIPT_DIR}/../opentofu/modules/rosa/hcp
tofu init
WORKSPACE=${CLUSTER_NAME}-${REGION}
tofu workspace new ${WORKSPACE} || true
export TF_WORKSPACE=${WORKSPACE}

TOFU_CMD="tofu apply -auto-approve \
  -var vpc_cidr=${CIDR} \
  -var cluster_name=${CLUSTER_NAME} \
  -var region=${REGION} \
  -var subnet_cidr_prefix=28"

if [ -n "${COMPUTE_MACHINE_TYPE}" ]; then
  TOFU_CMD+=" -var instance_type=${COMPUTE_MACHINE_TYPE}"
fi

if [ -n "${VERSION}" ]; then
  TOFU_CMD+=" -var openshift_version=${VERSION}"
fi

if [ -n "${REPLICAS}" ]; then
  TOFU_CMD+=" -var replicas=${REPLICAS}"
fi

echo ${TOFU_CMD}
${TOFU_CMD}

SCALING_MACHINE_POOL=$(rosa list machinepools -c "${CLUSTER_NAME}" -o json | jq -r '.[] | select(.id == "scaling") | .id')
if [[ "${SCALING_MACHINE_POOL}" != "scaling" ]]; then
    rosa create machinepool -c "${CLUSTER_NAME}" --instance-type m5.4xlarge --max-replicas 10 --min-replicas 1 --name scaling --enable-autoscaling
fi

cd ${SCRIPT_DIR}
./rosa_oc_login.sh
./rosa_efs_create.sh
../infinispan/install_operator.sh

# cryostat operator depends on certmanager operator
./rosa_install_certmanager_operator.sh
./rosa_install_cryotstat_operator.sh

./rosa_install_openshift_logging.sh

echo "Cluster ${CLUSTER_NAME} is ready."
