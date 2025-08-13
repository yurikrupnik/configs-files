#!/usr/bin/env nu

def "main send cluster-ready" [
    webhook_url: string
    --channel: string = "#general"
] {
    let message = {
        "channel": $channel,
        "text": "🎉 Kubernetes Cluster Infrastructure Setup Complete!",
        "attachments": [
            {
                "color": "good",
                "title": "All Dependencies Installed Successfully",
                "fields": [
                    {
                        "title": "Crossplane",
                        "value": "✅ Installed and Running",
                        "short": true
                    },
                    {
                        "title": "HashiCorp Vault",
                        "value": "✅ Installed and Running (Dev Mode)",
                        "short": true
                    },
                    {
                        "title": "External Secrets Operator",
                        "value": "✅ Installed and Running",
                        "short": true
                    }
                ],
                "footer": "Infrastructure Setup Complete",
                "ts": (date now | format date "%s")
            }
        ]
    }
    
    try {
        http post $webhook_url ($message | to json)
        print "✅ Slack notification sent successfully"
    } catch {
        print "❌ Failed to send Slack notification. Please check your webhook URL."
    }
}

def "main help" [] {
    print "📢 Slack Notification Script"
    print ""
    print "Usage:"
    print "  send cluster-ready <webhook_url> [--channel <channel>]"
    print ""
    print "Example:"
    print "  nu scripts/send-slack-notification.nu send cluster-ready https://hooks.slack.com/services/YOUR/WEBHOOK/URL --channel \"#devops\""
}