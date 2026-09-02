# Push Notification Testing Guide for LifeTrack

## Overview
The LifeTrack app now supports Firebase Cloud Messaging (FCM) for push notifications. Follow this guide to test and verify push notifications work correctly.

## Prerequisites
1. Firebase Project configured for LifeTrack
2. Android/iOS app setup with google-services.json (Android) or GoogleService-Info.plist (iOS)
3. Device or emulator with Google Play Services (for Android)
4. Firebase Console access

## Setup Steps

### 1. Get FCM Token (For Testing)
The app logs the FCM token on startup. To get it:
1. Run the app in debug mode
2. Check the console logs for: 'FCM Token: <token>'
3. Copy this token for use in testing

Alternatively, modify NotificationsScreen temporarily to display the token.

### 2. Test Local Notifications (Without FCM)
The app automatically creates local notifications for:
- Task reminders
- Schedule reminders  
- Free time alerts
- Goals progress
- Achievements

### 3. Send Test Push Notifications via Firebase Console

#### Option A: Firebase Console UI
1. Go to Firebase Console (https://console.firebase.google.com/)
2. Select your LifeTrack project
3. Go to Messaging (Cloud Messaging)
4. Click 'Send your first message'
5. Fill in:
   - Title: 'Test Notification'
   - Body: 'This is a test push notification'
6. Click 'Send test message'
7. Enter your FCM token
8. Click 'Send'

#### Option B: Using cURL (For Developers)
\\\ash
# 1. Get your Server API Key from Firebase Console
#    Project Settings > Cloud Messaging > Server API Key

# 2. Send notification via cURL
curl -X POST https://fcm.googleapis.com/fcm/send \\
  -H "Content-Type: application/json" \\
  -H "Authorization: key=YOUR_SERVER_API_KEY" \\
  -d '{
    "to": "DEVICE_FCM_TOKEN",
    "notification": {
      "title": "Test Task Reminder",
      "body": "Complete your pending tasks!",
      "click_action": "FLUTTER_NOTIFICATION_CLICK"
    },
    "data": {
      "type": "task_reminder",
      "taskId": "123"
    }
  }'
\\\

#### Option C: Using Python Script
\\\python
import requests
import json

SERVER_API_KEY = "YOUR_SERVER_API_KEY"
DEVICE_TOKEN = "DEVICE_FCM_TOKEN"

url = "https://fcm.googleapis.com/fcm/send"

headers = {
    "Content-Type": "application/json",
    "Authorization": f"key={SERVER_API_KEY}"
}

payload = {
    "to": DEVICE_TOKEN,
    "notification": {
        "title": "Test Schedule Reminder",
        "body": "Your meeting starts in 15 minutes",
        "click_action": "FLUTTER_NOTIFICATION_CLICK"
    },
    "data": {
        "type": "schedule_reminder",
        "scheduleId": "456"
    }
}

response = requests.post(url, data=json.dumps(payload), headers=headers)
print(f"Status: {response.status_code}")
print(f"Response: {response.text}")
\\\

## Testing Scenarios

### 1. Foreground Notification
- Keep app open
- Send test notification
- Expected: Local notification appears at top

### 2. Background Notification  
- Send the app to background (tap home/back button)
- Send test notification
- Expected: System notification appears, database stores notification

### 3. Notification Tap
- Send notification
- Tap notification
- Expected: App opens and notification is marked as read

### 4. Notification Storage
- Send multiple test notifications
- Open app and go to Notifications screen
- Expected: All notifications appear in list with correct metadata

## Notification Types Supported

When sending test notifications, use these type values:
- 'task_reminder' - Task due reminders
- 'schedule_reminder' - Upcoming schedule alerts
- 'free_time_alert' - Free time notifications
- 'goal_progress' - Goal progress updates
- 'achievement' - Achievement unlocked
- 'general' - Default notification type

## Debugging

### Check Notification Status
1. Open LifeTrack app
2. Go to Notifications screen (tap bell icon)
3. All received notifications are listed with:
   - Title and body
   - Notification type with icon
   - Time received
   - Read/unread status

### Check Logs
In Android Studio/Console, search for:
- 'LifeTrack.notifications' - Notification service logs
- 'FCM Token:' - Token logs
- 'Received FCM message:' - Message receipt logs

### Common Issues

**Issue: Notifications not appearing**
- Check device notification permissions
- Verify FCM token is correct
- Check Firebase project is properly configured
- Ensure Server API Key is valid

**Issue: App crashes on notification**
- Check error logs
- Verify all required fields in notification data
- Check notification model parsing

**Issue: Notifications not stored in database**
- Verify database initialization
- Check NotificationRepository for errors
- Check database permissions

## Manual Testing of Database

1. Open app and receive notifications
2. Use Flutter DevTools or Android Studio database viewer
3. Query 'notifications' table to verify data storage
4. Check is_read flag updates when marking as read

## Automated Testing

Add unit tests in 	est/ folder to verify:
1. Notification model serialization/deserialization
2. Repository CRUD operations
3. Service notification handling
4. Database persistence

## Performance Testing

1. Send 100+ notifications
2. Verify UI responsiveness
3. Check memory usage
4. Verify no database locks

## Additional Resources

- [Firebase Cloud Messaging Documentation](https://firebase.google.com/docs/cloud-messaging)
- [Flutter Local Notifications Plugin](https://pub.dev/packages/flutter_local_notifications)
- [Firebase Messaging for Flutter](https://pub.dev/packages/firebase_messaging)
