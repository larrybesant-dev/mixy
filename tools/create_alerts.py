#!/usr/bin/env python
"""
Create Firebase Crashlytics alerts for MixVy monitoring.

This script creates 3 production alerts:
1. CRITICAL: Max reconnection retries exceeded
2. ERROR: Repeated reconnection failures (5+ in 5min)
3. WARNING: Connection health degrading
"""

import os
import sys
import json

def install_and_import():
    """Install required packages if not available."""
    try:
        from google.cloud import monitoring_v3
        from google.api_core import gapic_v1
        return monitoring_v3
    except ImportError:
        print("Installing google-cloud-monitoring...")
        os.system(f"{sys.executable} -m pip install google-cloud-monitoring -q")
        from google.cloud import monitoring_v3
        return monitoring_v3

def create_notification_channel(client, project_id, email):
    """Create or find email notification channel."""
    channels_client = monitoring_v3.NotificationChannelServiceClient()
    project_path = channels_client.common_project_path(project_id)
    
    # List existing email channels
    channels = channels_client.list_notification_channels(name=project_path)
    for channel in channels:
        if channel.type_ == 'email' and email in channel.labels.get('email_address', ''):
            print(f"✅ Found existing email channel: {channel.name}")
            return channel.name
    
    # Create new email channel
    notification_channel = monitoring_v3.NotificationChannel(
        type_='email',
        display_name=f"Email - {email}",
        labels={'email_address': email},
        enabled=True,
    )
    
    created_channel = channels_client.create_notification_channel(
        name=project_path,
        notification_channel=notification_channel
    )
    print(f"✅ Created notification channel: {created_channel.name}")
    return created_channel.name

def create_alert(client, project_id, alert_config, notification_channel_id):
    """Create a monitoring alert policy."""
    alert_policy_client = monitoring_v3.AlertPolicyServiceClient()
    project_path = alert_policy_client.common_project_path(project_id)
    
    # Build the condition
    condition = monitoring_v3.AlertPolicy.Condition(
        display_name=alert_config['condition_display'],
        condition_threshold=monitoring_v3.AlertPolicy.Condition.MetricThreshold(
            filter_=alert_config['filter'],
            comparison=alert_config['comparison'],
            threshold_value=alert_config['threshold'],
            duration={'seconds': alert_config.get('duration_seconds', 0)},
        )
    )
    
    # Build the alert policy
    policy = monitoring_v3.AlertPolicy(
        display_name=alert_config['name'],
        conditions=[condition],
        notification_channels=[notification_channel_id],
        alert_strategy=monitoring_v3.AlertPolicy.AlertStrategy(
            auto_close={'seconds': 259200}  # 3 days
        ),
    )
    
    # Create the policy
    created_policy = alert_policy_client.create_alert_policy(
        name=project_path,
        alert_policy=policy
    )
    
    print(f"✅ Created alert: {alert_config['name']}")
    print(f"   Policy ID: {created_policy.name}")
    return created_policy

def main():
    project_id = "mixvy-v2"
    email = "larrybesant@gmail.com"
    
    print("🚀 MixVy Crashlytics Alerts Setup")
    print("=" * 60)
    
    # Import and install packages
    monitoring_v3 = install_and_import()
    
    try:
        # Initialize clients
        alert_policy_client = monitoring_v3.AlertPolicyServiceClient()
        
        # Create notification channel
        print(f"\n📧 Setting up email notifications to {email}...")
        notification_channel = create_notification_channel(
            alert_policy_client, project_id, email
        )
        
        # Define alert configurations
        alerts = [
            {
                'name': 'MixVy Production - CRITICAL Network Recovery Failure',
                'condition_display': 'Issue severity is FATAL',
                'filter': 'resource.type="cloud_function" AND severity="FATAL" AND log_name=~"^projects/mixvy-v2.*crashlytics.*" AND textPayload=~".*CRIT.*"',
                'comparison': 'COMPARISON_GT',
                'threshold': 0,
                'duration_seconds': 60,
            },
            {
                'name': 'MixVy Production - ERROR Reconnection Failures',
                'condition_display': 'Issue count > 5 in 5 minutes',
                'filter': 'resource.type="cloud_function" AND severity="ERROR" AND textPayload=~".*\[MIXVY_DEBUG\].*\[ERR\].*"',
                'comparison': 'COMPARISON_GT',
                'threshold': 5,
                'duration_seconds': 300,
            },
            {
                'name': 'MixVy Production - WARNING Connection Health Degrading',
                'condition_display': 'Issue count > 3 in 5 minutes',
                'filter': 'resource.type="cloud_function" AND severity="WARNING" AND textPayload=~".*\[MIXVY_DEBUG\].*\[WARN\].*"',
                'comparison': 'COMPARISON_GT',
                'threshold': 3,
                'duration_seconds': 300,
            },
        ]
        
        # Create alerts
        print(f"\n🔔 Creating {len(alerts)} production alerts...\n")
        for alert_config in alerts:
            try:
                create_alert(alert_policy_client, project_id, alert_config, notification_channel)
            except Exception as e:
                print(f"⚠️  Failed to create {alert_config['name']}: {str(e)[:100]}")
        
        print("\n" + "=" * 60)
        print("✅ Alert setup complete!")
        print("\nNext steps:")
        print("1. Check your email for confirmation")
        print("2. Test alerts by triggering connection failures")
        print("3. Monitor Crashlytics dashboard: https://console.firebase.google.com/project/mixvy-v2/crashlytics")
        
    except Exception as e:
        print(f"\n❌ Error: {str(e)}")
        print("\nNote: You may need to authenticate with gcloud first:")
        print("  gcloud auth application-default login")
        sys.exit(1)

if __name__ == "__main__":
    main()
