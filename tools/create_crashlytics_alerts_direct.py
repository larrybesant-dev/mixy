#!/usr/bin/env python3
"""
Create Crashlytics alert policies using Google Cloud Monitoring API
"""

from google.cloud import monitoring_v3
import sys

def create_alerts():
    client = monitoring_v3.AlertPolicyServiceClient()
    channel_id = "projects/mixvy-v2/notificationChannels/5103384296039862868"
    project_name = client.common_project_path("mixvy-v2")
    
    print("\n✅ Using notification channel:", channel_id)
    
    # Alert 1: CRITICAL severity
    print("\n[1/3] Creating CRITICAL Alert...")
    alert1 = monitoring_v3.AlertPolicy(
        display_name="MixVy Production - CRITICAL Network Recovery Failure",
        conditions=[
            monitoring_v3.AlertPolicy.Condition(
                display_name="FATAL severity errors",
                condition_threshold=monitoring_v3.AlertPolicy.Condition.MetricThreshold(
                    filter='resource.type="global" AND severity="FATAL"',
                    comparison=monitoring_v3.ComparisonType.COMPARISON_GT,
                    threshold_value=0,
                    duration={"seconds": 60},
                ),
            )
        ],
        notification_channels=[channel_id],
        combiner=monitoring_v3.AlertPolicy.ConditionCombinerType.OR,
    )
    try:
        result1 = client.create_alert_policy(name=project_name, alert_policy=alert1)
        print("✅ Alert 1 created:", result1.name)
    except Exception as e:
        print("⚠️  Alert 1 error:", str(e))
    
    # Alert 2: ERROR count
    print("\n[2/3] Creating ERROR Alert...")
    alert2 = monitoring_v3.AlertPolicy(
        display_name="MixVy Production - ERROR Reconnection Failures",
        conditions=[
            monitoring_v3.AlertPolicy.Condition(
                display_name="5+ errors in 5 minutes",
                condition_threshold=monitoring_v3.AlertPolicy.Condition.MetricThreshold(
                    filter='resource.type="global" AND severity="ERROR"',
                    comparison=monitoring_v3.ComparisonType.COMPARISON_GT,
                    threshold_value=5,
                    duration={"seconds": 300},
                ),
            )
        ],
        notification_channels=[channel_id],
        combiner=monitoring_v3.AlertPolicy.ConditionCombinerType.OR,
    )
    try:
        result2 = client.create_alert_policy(name=project_name, alert_policy=alert2)
        print("✅ Alert 2 created:", result2.name)
    except Exception as e:
        print("⚠️  Alert 2 error:", str(e))
    
    # Alert 3: WARNING count
    print("\n[3/3] Creating WARNING Alert...")
    alert3 = monitoring_v3.AlertPolicy(
        display_name="MixVy Production - WARNING Connection Health Degrading",
        conditions=[
            monitoring_v3.AlertPolicy.Condition(
                display_name="3+ warnings in 5 minutes",
                condition_threshold=monitoring_v3.AlertPolicy.Condition.MetricThreshold(
                    filter='resource.type="global" AND severity="WARNING"',
                    comparison=monitoring_v3.ComparisonType.COMPARISON_GT,
                    threshold_value=3,
                    duration={"seconds": 300},
                ),
            )
        ],
        notification_channels=[channel_id],
        combiner=monitoring_v3.AlertPolicy.ConditionCombinerType.OR,
    )
    try:
        result3 = client.create_alert_policy(name=project_name, alert_policy=alert3)
        print("✅ Alert 3 created:", result3.name)
    except Exception as e:
        print("⚠️  Alert 3 error:", str(e))
    
    print("\n✅ Alert creation complete!")

if __name__ == "__main__":
    try:
        create_alerts()
    except Exception as e:
        print(f"❌ Error: {e}", file=sys.stderr)
        sys.exit(1)
