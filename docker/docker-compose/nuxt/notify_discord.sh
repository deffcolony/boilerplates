#!/bin/bash

# Discord webhook URL
WEBHOOK_URL="IMPORT_DISCORD_WEBHOOK_URL_HERE"
WEBHOOK_NAME="Deployment System"

# Project directory
PROJECT_DIR="my-nuxt-project"

# Repository URL
REPO_URL="https://gitlab.DOMAIN.COM/mynuxtproject.git"

# Branding Assets
COMPANY_DOMAIN="DOMAIN.COM"
COMPANY_LOGO="mylogo.png"
BRAND_COLOR=5814783  # Primary brand color

# Environment (passed as an argument)
ENVIRONMENT=$1

# Set environment-specific values
case $ENVIRONMENT in
  "prod")
    SITE_URL="https://$COMPANY_DOMAIN"
    ENV_COLOR=5814783  # Green
    ENV_ICON="🌐"
    ;;
  "stage")
    SITE_URL="https://staging.$COMPANY_DOMAIN"
    ENV_COLOR=16761095  # Orange
    ENV_ICON="🛠️"
    ;;
  "dev")
    SITE_URL="http://localhost:3000"
    ENV_COLOR=3447003  # Blue
    ENV_ICON="💻"
    ;;
  *)
    echo "Unknown environment: $ENVIRONMENT"
    exit 1
    ;;
esac

# Get Git commit information from the project directory
COMMIT_HASH=$(git -C "$PROJECT_DIR" rev-parse --short HEAD 2>/dev/null || echo "unknown")
COMMIT_MESSAGE=$(git -C "$PROJECT_DIR" log -1 --pretty=%B 2>/dev/null | tr -d '\n' || echo "No commit message")
BRANCH_NAME="main"

# Build status handling
if [ $? -eq 0 ]; then
  STATUS_TITLE="✅ Deployment Successful"
  STATUS_COLOR=$ENV_COLOR
  STATUS_DESCRIPTION="**$ENVIRONMENT** environment deployment completed successfully!"
  DEPLOYMENT_FOOTER="Deployed to $ENVIRONMENT"
else
  STATUS_TITLE="❌ Deployment Failed"
  STATUS_COLOR=16711680  # Red
  STATUS_DESCRIPTION="**$ENVIRONMENT** environment deployment failed! Immediate attention required."
  DEPLOYMENT_FOOTER="Deployment aborted"
fi

# Construct JSON payload
JSON_PAYLOAD=$(cat <<EOF
{
  "content": null,
  "embeds": [
    {
      "title": "${STATUS_TITLE}",
      "description": "${STATUS_DESCRIPTION}",
      "color": ${STATUS_COLOR},
      "thumbnail": {
        "url": "${COMPANY_LOGO}"
      },
      "fields": [
        {
          "name": "${ENV_ICON} Environment",
          "value": "**${ENVIRONMENT}**\n[Visit Site](${SITE_URL})",
          "inline": true
        },
        {
          "name": "📦 Build Info",
          "value": "Branch: **${BRANCH_NAME}**\nCommit: [\`${COMMIT_HASH}\`](${REPO_URL}/-/commit/${COMMIT_HASH})",
          "inline": true
        },
        {
          "name": "📝 Last Commit",
          "value": "_${COMMIT_MESSAGE}_",
          "inline": false
        }
      ],
      "author": {
        "name": "${WEBHOOK_NAME}",
        "url": "${SITE_URL}",
        "icon_url": "${COMPANY_LOGO}"
      },
      "footer": {
        "text": "${DEPLOYMENT_FOOTER}",
        "icon_url": "${COMPANY_LOGO}"
      },
      "timestamp": "$(date -u +'%Y-%m-%dT%H:%M:%SZ')"
    }
  ]
}
EOF
)

# Send the webhook
curl -H "Content-Type: application/json" \
     -X POST \
     --data "$JSON_PAYLOAD" \
     $WEBHOOK_URL



# === Optional stuff or ideas for JSON_PAYLOAD ===
