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

syslog_host="syslog.$pcf_ert_domain"
syslog_port="5514"

properties=$(
  jq -n \
    --arg pcf_az_1 $pcf_az_1 \
    --arg pcf_az_2 $pcf_az_2 \
    --arg pcf_az_3 $pcf_az_3 \
    --arg syslog_host $syslog_host \
    --arg syslog_port $syslog_port \
    '
    {
      ".properties.small_plan_selector": {
        "value": "Plan Active"
      },
      ".properties.small_plan_selector.active.vm_type": {
        "value": "t2.medium"
      },
      ".properties.small_plan_selector.active.disk_size": {
        "value": "10240",
      },
      ".properties.medium_plan_selector": {
        "value": "Plan Inactive",
      },
      ".properties.large_plan_selector": {
        "value": "Plan Inactive",
      },
      ".properties.syslog_selector": {
        "value": "enabled"
      },
      ".properties.syslog_selector.active.syslog_address": {
        "value": $syslog_host
      },
      ".properties.syslog_selector.active.port": {
        "value": $syslog_port
      },
      ".properties.syslog_selector.active.syslog_transport": {
        "value": "tcp"
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
  --product-name p-redis \
  --product-network "$network"

om-linux \
  --target "https://$OPSMAN_DOMAIN_OR_IP_ADDRESS" \
  --username "$OPS_MGR_USR" \
  --password "$OPS_MGR_PWD" \
  --skip-ssl-validation \
  configure-product \
  --product-name p-redis \
  --product-properties "$properties"
