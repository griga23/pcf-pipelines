#!/bin/bash
set -eu

export OPSMAN_DOMAIN_OR_IP_ADDRESS="opsman.$pcf_ert_domain"

network=$(
  jq -n \
    --arg iaas $pcf_iaas \
    --arg singleton_availability_zone "$pcf_az_1" \
    --arg other_availability_zones "$pcf_az_1,$pcf_az_2,$pcf_az_3" \
    '
    {
      "network": {
        "name": (if $iaas == "aws" then "deployment" else "ert" end),
      },
      "service_network": {
        "name": "dynamic-services",
      },
      "other_availability_zones": ($other_availability_zones | split(",") | map({name: .})),
      "singleton_availability_zone": {
        "name": $singleton_availability_zone
      }
    }
    '
)

om-linux \
  --target "https://$OPSMAN_DOMAIN_OR_IP_ADDRESS" \
  --username "$OPS_MGR_USR" \
  --password "$OPS_MGR_PWD" \
  --skip-ssl-validation \
  configure-product \
  --product-name p-spring-cloud-services \
  --product-network "$network"

om-linux \
  --target "https://$OPSMAN_DOMAIN_OR_IP_ADDRESS" \
  --username "$OPS_MGR_USR" \
  --password "$OPS_MGR_PWD" \
  --skip-ssl-validation \
  set-errand-state \
  --product-name "p-spring-cloud-services" \
  --errand-name "deploy-service-broker" \
  --post-deploy-state "when-changed"

om-linux \
  --target "https://$OPSMAN_DOMAIN_OR_IP_ADDRESS" \
  --username "$OPS_MGR_USR" \
  --password "$OPS_MGR_PWD" \
  --skip-ssl-validation \
  set-errand-state \
  --product-name "p-spring-cloud-services" \
  --errand-name "register-service-broker" \
  --post-deploy-state "when-changed"

om-linux \
  --target "https://$OPSMAN_DOMAIN_OR_IP_ADDRESS" \
  --username "$OPS_MGR_USR" \
  --password "$OPS_MGR_PWD" \
  --skip-ssl-validation \
  set-errand-state \
  --product-name "p-spring-cloud-services" \
  --errand-name "run-smoke-tests" \
  --post-deploy-state "when-changed"
