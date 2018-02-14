# Jan's file from Cristian

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
syslog_port="6514"

backup_bucket="$(jq -r '.s3_pcf_mysql_backup' extra-infrastructure/metadata)"
backup_aws_access_key_id="$(jq -r '.s3_mysql_backups_access_key_id' extra-infrastructure/metadata)"
backup_aws_secret_access_key="$(jq -r '.s3_mysql_backups_secret_access_key' extra-infrastructure/metadata)"

properties=$(
  jq -n \
    --arg alert_recipient_email $ALERT_RECIPIENT_EMAIL \
    --arg syslog_host $syslog_host \
    --arg syslog_port $syslog_port \
    --arg backup_bucket $backup_bucket \
    --arg backup_aws_access_key_id "$backup_aws_access_key_id" \
    --arg backup_aws_secret_access_key "$backup_aws_secret_access_key" \
    '
    {
      ".properties.optional_protections": {
        "value": "enable"
      },
      ".properties.syslog": {
        "value": "disabled"
      },
      ".properties.optional_protections.enable.recipient_email": {
        "value": $alert_recipient_email
      },
      ".properties.syslog": {
        "value": "enabled"
      },
      ".properties.syslog.enabled.address": {
        "value": $syslog_host
      },
      ".properties.syslog.enabled.port": {
        "value": $syslog_port
      },
      ".properties.backup_options": {
        "value": "enable"
      },
      ".properties.backup_options.enable.cron_schedule": {
        "value": "@every 30m"
      },
      ".properties.backup_options.enable.backup_all_masters": {
        "value": "1"
      },
      ".properties.backups": {
        "value": "enable"
      },
      ".properties.backups.enable.endpoint_url": {
        "value": "https://s3.eu-central-1.amazonaws.com"
      },
      ".properties.backups.enable.bucket_name": {
        "value": $backup_bucket
      },
      ".properties.backups.enable.bucket_path": {
        "value": "backups"
      },
      ".properties.backups.enable.access_key_id": {
        "value": $backup_aws_access_key_id
      },
      ".properties.backups.enable.secret_access_key": {
        "value": {
          "secret": $backup_aws_secret_access_key
        }
      },
      ".properties.backups.enable.region": {
        "value": "eu-central-1"
      }
    }
    '
)

resources=$(
  jq -n \
    '
      {
        "backup-prepare": {
          "instances": 1
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
  --product-name p-mysql \
  --product-network "$network" \
  --product-properties "$properties" \
  --product-resources "$resources"

om-linux \
  --target "https://$OPSMAN_DOMAIN_OR_IP_ADDRESS" \
  --username "$OPS_MGR_USR" \
  --password "$OPS_MGR_PWD" \
  --skip-ssl-validation \
  set-errand-state \
  --product-name "p-mysql" \
  --errand-name "broker-registrar" \
  --post-deploy-state "when-changed"

om-linux \
  --target "https://$OPSMAN_DOMAIN_OR_IP_ADDRESS" \
  --username "$OPS_MGR_USR" \
  --password "$OPS_MGR_PWD" \
  --skip-ssl-validation \
  set-errand-state \
  --product-name "p-mysql" \
  --errand-name "smoke-tests" \
  --post-deploy-state "when-changed"
