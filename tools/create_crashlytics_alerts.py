#!/usr/bin/env python3
"""
Create Crashlytics monitoring alerts using Google Cloud Monitoring API.

Usage:
  python3 create_crashlytics_alerts.py
"""

import sys
import json
from typing import Optional

def create_notification_channel(project_id: str, email: str) -> Optional[str]:
    """Create or retrieve email notification channel."""
    from google.cloud import monitoring_v3
    
    client = monitoring_v3.NotificationChannelServiceClient()
    
    # List existing email channels
    project_path = client.common_project_path(project_id)
    channels = client.list_notification_channels(name=project_path)
    
    for channel in channels:
        if (channel.type_ == 'email' and 
            email in channel.labels.get('email_address', '')):
            print(f"✅ Found existing email channel: {channel.name}")
            return channel.name
    
    # Create new email channel
    print(f"📧 Creating new email notification channel for {email}...")
    
    notification_channel = monitoring_v3.NotificationChannel(
        type_='email',
        display_name=f'Email - {email}',
        labels={'email_address': email},
        enabled=True,
    )
    
    created_channel = client.create_notification_channel(
        name=project_path,
        notification_channel=notification_channel
    )
    
    print(f"✅ Created notification channel: {created_channel.name}")
    return created_channel.name


def create_alert_policy(
    project_id: str,
    display_name: str,
    condition_name: str,
    filter_string: str,
    threshold: float,
    duration_seconds: int,
    notification_channel_id: str
) -> str:
    """Create a monitoring alert policy."""
    from google.cloud import monitoring_v3
    from google.protobuf.duration_pb2 import Duration
    
    client = monitoring_v3.AlertPolicyServiceClient()
    project_path = client.common_project_path(project_id)
    
    # Create condition
    condition = monitoring_v3.AlertPolicy.Condition(
        display_name=condition_name,
        condition_threshold=monitoring_v3.AlertPolicy.Condition.MetricThreshold(
            filter_=filter_string,
            comparison=monitoring_v3.ComparisonType.COMPARISON_GT,
            threshold_value=threshold,
            duration=Duration(seconds=duration_seconds),
        )
    )
    
    # Create alert policy
    policy = monitoring_v3.AlertPolicy(
        display_name=display_name,
        conditions=[condition],
        notification_channels=[notification_channel_id],
        alert_strategy=monitoring_v3.AlertPolicy.AlertStrategy(
            auto_close=Duration(seconds=259200)  # 3 days
        ),
    )
    
    # Create the policy
    created_policy = client.create_alert_policy(
        name=project_path,
        alert_policy=policy
    )
    
    print(f"✅ Created alert: {display_name}")
    print(f"   Policy ID: {created_policy.name}")
    
    return created_policy.name


def main():
    """Main function to create all 3 alerts."""
    import os
    
    # Configuration
    project_id = 'mixvy-v2'
    email = 'larrybesant@gmail.com'
    
    print("🚀 MixVy Crashlytics Alerts - Automated Setup")
    print("=" * 60)
    
    try:
        # Import required libraries
        from google.cloud import monitoring_v3
        from google.auth import default
        
        # Check authentication
        credentials, project = default()
        print(f"✅ Authenticated as: {credentials.service_account_email if hasattr(credentials, 'service_account_email') else 'User'}")
        
    except ImportError:
        print("❌ Error: google-cloud-monitoring not installed")
        print("Install with: pip install google-cloud-monitoring")
        sys.exit(1)
    except Exception as e:
        print(f"❌ Authentication error: {str(e)}")
        print("\nTo authenticate, run:")
        print("  gcloud auth application-default login")
        sys.exit(1)
    
    try:
        # Step 1: Create notification channel
        print(f"\n📧 Setting up email notifications to {email}...")
        channel_id = create_notification_channel(project_id, email)
        
        if not channel_id:
            print("⚠️  Failed to create notification channel")
            sys.exit(1)
        
        # Step 2: Define alert configurations
        alerts = [
            {
                'name': 'MixVy Production - CRITICAL Network Recovery Failure',
                'condition': 'Issue severity is FATAL',
                'filter': 'resource.type="global" AND severity="FATAL" AND log_name=~".*crashlytics.*"',
                'threshold': 0,
                'duration': 60,
            },
            {
                'name': 'MixVy Production - ERROR Reconnection Failures (5+ in 5min)',
                'condition': 'Issue count > 5 in 5 minutes',
                'filter': 'resource.type="global" AND severity="ERROR" AND log_name=~".*crashlytics.*"',
                'threshold': 5,
                'duration': 300,
            },
            {
                'name': 'MixVy Production - WARNING Connection Health Degrading (3+ in 5min)',
                'condition': 'Issue count > 3 in 5 minutes',
                'filter': 'resource.type="global" AND severity="WARNING" AND log_name=~".*crashlytics.*"',
                'threshold': 3,
                'duration': 300,
            },
        ]
        
        # Step 3: Create alerts
        print(f"\n🔔 Creating {len(alerts)} monitoring alerts...\n")
        
        created_policies = []
        for alert in alerts:
            try:
                policy_id = create_alert_policy(
                    project_id=project_id,
                    display_name=alert['name'],
                    condition_name=alert['condition'],
                    filter_string=alert['filter'],
                    threshold=alert['threshold'],
                    duration_seconds=alert['duration'],
                    notification_channel_id=channel_id
                )
                created_policies.append(policy_id)
            except Exception as e:
                print(f"⚠️  Failed to create {alert['name']}: {str(e)}")
        
        # Step 4: Summary
        print("\n" + "=" * 60)
        print(f"✅ Alert Setup Complete!")
        print(f"\n📊 Alerts Created: {len(created_policies)}/{len(alerts)}")
        
        if created_policies:
            print("\n✅ Verification Steps:")
            print("1. Check your email for notification confirmation")
            print("2. Click the verification link in the email")
            print("3. Go to Firebase Console → Crashlytics → Alerts")
            print("4. Verify all 3 alerts are listed and enabled")
            
            print("\n📈 Test Alert Delivery (Optional):")
            print("1. Open: https://mixvy-v2.web.app")
            print("2. Join a live room")
            print("3. Disable network (DevTools → Network → Offline)")
            print("4. Wait for reconnection to fail (14 seconds)")
            print("5. Check email for alert notification")
            
            print(f"\n🔗 Quick Links:")
            print(f"  • View Alerts: https://console.firebase.google.com/project/{project_id}/monitoring/alertpolicies")
            print(f"  • Crashlytics: https://console.firebase.google.com/project/{project_id}/crashlytics")
            print(f"  • Project: https://console.firebase.google.com/project/{project_id}/overview")
        
        return 0 if created_policies else 1
    
    except Exception as e:
        print(f"\n❌ Error: {str(e)}")
        import traceback
        traceback.print_exc()
        return 1


if __name__ == '__main__':
    sys.exit(main())
