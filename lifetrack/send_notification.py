#!/usr/bin/env python3
"""
LifeTrack Push Notification Testing Script

This script allows you to easily send test push notifications to your LifeTrack app
via Firebase Cloud Messaging (FCM).

Usage:
    python3 send_notification.py --token DEVICE_TOKEN --title "Test" --body "Body"
    
Requirements:
    - requests library (pip install requests)
    - Firebase Server API Key
    - Valid FCM device token from the app
"""

import requests
import json
import argparse
from datetime import datetime

# Configuration
SERVER_API_KEY = "YOUR_FIREBASE_SERVER_API_KEY_HERE"  # Replace with your key
FCM_ENDPOINT = "https://fcm.googleapis.com/fcm/send"

# Predefined notification types
NOTIFICATION_TYPES = {
    'task': 'task_reminder',
    'schedule': 'schedule_reminder',
    'free': 'free_time_alert',
    'goal': 'goal_progress',
    'achievement': 'achievement',
    'general': 'general',
}

class NotificationSender:
    def __init__(self, server_key):
        self.server_key = server_key
        self.headers = {
            "Content-Type": "application/json",
            "Authorization": f"key={self.server_key}"
        }
    
    def send_notification(self, token, title, body, notification_type='general', metadata=None):
        """Send a push notification to a device."""
        
        if not self.server_key or self.server_key == "YOUR_FIREBASE_SERVER_API_KEY_HERE":
            print("❌ Error: SERVER_API_KEY not configured!")
            print("   1. Go to Firebase Console > Project Settings > Cloud Messaging")
            print("   2. Copy the Server API Key")
            print("   3. Replace SERVER_API_KEY in this script")
            return False
        
        if notification_type not in NOTIFICATION_TYPES.values():
            print(f"⚠️  Warning: Unknown notification type '{notification_type}'")
            print(f"   Valid types: {', '.join(NOTIFICATION_TYPES.values())}")
        
        payload = {
            "to": token,
            "notification": {
                "title": title,
                "body": body,
                "click_action": "FLUTTER_NOTIFICATION_CLICK"
            },
            "data": {
                "type": notification_type,
                "sent_at": datetime.now().isoformat(),
            }
        }
        
        # Add custom metadata if provided
        if metadata:
            payload["data"].update(metadata)
        
        try:
            print(f"📤 Sending notification...")
            print(f"   Title: {title}")
            print(f"   Body: {body}")
            print(f"   Type: {notification_type}")
            
            response = requests.post(
                FCM_ENDPOINT,
                data=json.dumps(payload),
                headers=self.headers,
                timeout=10
            )
            
            if response.status_code == 200:
                print("✅ Notification sent successfully!")
                print(f"   Response: {response.json()}")
                return True
            else:
                print(f"❌ Error sending notification!")
                print(f"   Status Code: {response.status_code}")
                print(f"   Response: {response.text}")
                return False
                
        except requests.exceptions.RequestException as e:
            print(f"❌ Request failed: {e}")
            return False

def main():
    parser = argparse.ArgumentParser(
        description="Send test push notifications to LifeTrack app",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  # Send a task reminder
  python3 send_notification.py --token YOUR_TOKEN --title "Task Due" --body "Complete your homework" --type task

  # Send a schedule reminder
  python3 send_notification.py --token YOUR_TOKEN --title "Meeting" --body "Daily standup in 15 min" --type schedule

  # Send a free time notification
  python3 send_notification.py --token YOUR_TOKEN --title "You're Free!" --body "Open time slot available" --type free

  # Send with custom metadata
  python3 send_notification.py --token YOUR_TOKEN --title "Goal Update" --body "Progress: 75%" --type goal --metadata taskId=123 goalId=456
        """
    )
    
    parser.add_argument(
        '--token', '-t',
        required=True,
        help='FCM device token (get from app logs: "FCM Token: ...")'
    )
    
    parser.add_argument(
        '--title', '-ti',
        required=True,
        help='Notification title'
    )
    
    parser.add_argument(
        '--body', '-b',
        required=True,
        help='Notification body text'
    )
    
    parser.add_argument(
        '--type', '-ty',
        choices=list(NOTIFICATION_TYPES.keys()),
        default='general',
        help='Notification type (default: general)'
    )
    
    parser.add_argument(
        '--metadata', '-m',
        nargs='*',
        help='Custom metadata as key=value pairs (e.g., taskId=123 eventId=456)'
    )
    
    args = parser.parse_args()
    
    # Parse metadata
    metadata = {}
    if args.metadata:
        for item in args.metadata:
            if '=' in item:
                key, value = item.split('=', 1)
                metadata[key] = value
    
    # Send notification
    sender = NotificationSender(SERVER_API_KEY)
    notification_type = NOTIFICATION_TYPES[args.type]
    success = sender.send_notification(
        args.token,
        args.title,
        args.body,
        notification_type,
        metadata
    )
    
    exit(0 if success else 1)

if __name__ == '__main__':
    main()
