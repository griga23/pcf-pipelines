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
    --arg rabbitmq_username $rabbitmq_username \
    --arg rabbitmq_password $rabbitmq_password \
    --arg pcf_az_1 $pcf_az_1 \
    --arg pcf_az_2 $pcf_az_2 \
    --arg pcf_az_3 $pcf_az_3 \
    --arg syslog_host $syslog_host \
    --arg syslog_port $syslog_port \
    '
    {
      ".rabbitmq-server.server_admin_credentials": {
        "value": {
          "identity": $rabbitmq_username,
          "password": $rabbitmq_password,
        }
      },
      ".properties.disk_alarm_threshold": {
        "value": "mem_relative_1_5"
      },
      ".properties.syslog_selector": {
        "value": "disabled"
      },
      ".properties.on_demand_broker_dedicated_single_node_plan_rabbitmq_az_placement": {
        "value": [
          $pcf_az_1,
          $pcf_az_2,
          $pcf_az_3
        ]
      },
      ".properties.on_demand_broker_dedicated_single_node_plan_rabbitmq_vm_type": {
        "value": "t2.medium"
      },
      ".properties.on_demand_broker_dedicated_single_node_plan_rabbitmq_persistent_disk_type": {
        "value": "10240"
      },
      ".properties.on_demand_broker_dedicated_single_node_plan_disk_limit_acknowledgement": {
        "value": [
          "acknowledge"
        ]
      },
      ".properties.syslog_selector": {
        "value": "enabled"
      },
      ".properties.syslog_selector.enabled.address": {
        "value": $syslog_host
      },
      ".properties.syslog_selector.enabled.port": {
        "value": $syslog_port
      },
      ".properties.syslog_selector.enabled.syslog_transport": {
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
  --product-name p-rabbitmq \
  --product-network "$network"

om-linux \
  --target "https://$OPSMAN_DOMAIN_OR_IP_ADDRESS" \
  --username "$OPS_MGR_USR" \
  --password "$OPS_MGR_PWD" \
  --skip-ssl-validation \
  configure-product \
  --product-name p-rabbitmq \
  --product-properties "$properties"

om-linux \
  --target "https://$OPSMAN_DOMAIN_OR_IP_ADDRESS" \
  --username "$OPS_MGR_USR" \
  --password "$OPS_MGR_PWD" \
  --skip-ssl-validation \
  set-errand-state \
  --product-name "p-rabbitmq" \
  --errand-name "broker-registrar" \
  --post-deploy-state "when-changed"

om-linux \
  --target "https://$OPSMAN_DOMAIN_OR_IP_ADDRESS" \
  --username "$OPS_MGR_USR" \
  --password "$OPS_MGR_PWD" \
  --skip-ssl-validation \
  set-errand-state \
  --product-name "p-rabbitmq" \
  --errand-name "register-on-demand-service-broker" \
  --post-deploy-state "when-changed"

om-linux \
  --target "https://$OPSMAN_DOMAIN_OR_IP_ADDRESS" \
  --username "$OPS_MGR_USR" \
  --password "$OPS_MGR_PWD" \
  --skip-ssl-validation \
  set-errand-state \
  --product-name "p-rabbitmq" \
  --errand-name "upgrade-all-service-instances" \
  --post-deploy-state "when-changed"

om-linux \
  --target "https://$OPSMAN_DOMAIN_OR_IP_ADDRESS" \
  --username "$OPS_MGR_USR" \
  --password "$OPS_MGR_PWD" \
  --skip-ssl-validation \
  set-errand-state \
  --product-name "p-rabbitmq" \
  --errand-name "multitenant-smoke-tests" \
  --post-deploy-state "when-changed"
