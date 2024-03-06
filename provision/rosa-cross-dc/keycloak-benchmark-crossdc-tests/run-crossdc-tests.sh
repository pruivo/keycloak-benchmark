#!/bin/bash
set -e

if [[ "$RUNNER_DEBUG" == "1" ]]; then
  set -x
fi

KEYCLOAK_MASTER_PASSWORD_SECRET_NAME=${KEYCLOAK_MASTER_PASSWORD_SECRET_NAME:-"keycloak-master-password"}
# Force eu-central-1 region for secrets manager so we all work with the same secret
SECRET_MANAGER_REGION="eu-central-1"

MAIN_PASSWORD=$(aws secretsmanager get-secret-value --region $SECRET_MANAGER_REGION --secret-id $KEYCLOAK_MASTER_PASSWORD_SECRET_NAME --query SecretString --output text --no-cli-pager)

LOAD_BALANCER_URL=https://client.gh-keycloak-a-gh-keycloak-b-mty1otck.keycloak-benchmark.com
KEYCLOAK_DC1_URL=https://primary.gh-keycloak-a-gh-keycloak-b-mty1otck.keycloak-benchmark.com
KEYCLOAK_DC2_URL=https://backup.gh-keycloak-a-gh-keycloak-b-mty1otck.keycloak-benchmark.com

ISPN_DC1_URL=https://infinispan-external-pruivo-keycloak.apps.gh-keycloak-a.l1su.p1.openshiftapps.com
ISPN_DC2_URL=https://infinispan-external-pruivo-keycloak.apps.gh-keycloak-b.lr9g.p1.openshiftapps.com


mvn -Denforcer.skip clean install -DcrossDCTests \
-Dload-balancer.url=$LOAD_BALANCER_URL \
-Dinfinispan.dc1.url=$ISPN_DC1_URL -Dkeycloak.dc1.url=$KEYCLOAK_DC1_URL \
-Dinfinispan.dc2.url=$ISPN_DC2_URL -Dkeycloak.dc2.url=$KEYCLOAK_DC2_URL \
-Dmain.password=$MAIN_PASSWORD
