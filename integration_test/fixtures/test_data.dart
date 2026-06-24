// integration_test/fixtures/test_data.dart
// Reusable test data and fixtures for E2E tests

class TestUserCredentials {
  static const String testEmail1 = 'testuser1@mixvy.test';
  static const String testPassword1 = 'TestPassword123!';
  static const String testDisplayName1 = 'Test User 1';

  static const String testEmail2 = 'testuser2@mixvy.test';
  static const String testPassword2 = 'TestPassword123!';
  static const String testDisplayName2 = 'Test User 2';
}

class TestRoomData {
  static const String testRoomName = 'E2E Test Room';
  static const String testRoomTopic = 'Integration Testing';
  static const String testMessage1 = 'E2E test message 1';
  static const String testMessage2 = 'E2E test message 2';
}

class TestUIElements {
  // Navigation
  static const String navFeed = 'Feed';
  static const String navMessages = 'Messages';
  static const String navLiveRooms = 'Live Rooms';
  static const String navDating = 'Dating';
  static const String navProfile = 'Profile';

  // Auth
  static const String btnSignIn = 'SIGN IN';
  static const String btnSignUp = 'SIGN UP';
  static const String btnCreateAccount = 'Create Account';

  // Room Controls
  static const String btnMuteAll = 'Mute All';
  static const String btnLockMics = 'Lock Mics';
  static const String btnLockCameras = 'Lock Cameras';
  static const String btnLeaveRoom = 'Leave';

  // Chat
  static const String inputChat = 'Type a message...';
  static const String btnSend = 'Send';

  // Friends
  static const String titleFriends = 'Friends';
  static const String titleFriendsOnline = 'Friends Online';
}

class TestTimeouts {
  static const Duration shortWait = Duration(seconds: 1);
  static const Duration normalWait = Duration(seconds: 3);
  static const Duration firebaseWait = Duration(seconds: 5);
  static const Duration longWait = Duration(seconds: 10);
}

/// Helper to generate unique test data (email, room name, etc.)
class TestDataGenerator {
  static String generateEmail(String prefix) {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    return '$prefix-$timestamp@mixvy.test';
  }

  static String generateRoomName() {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    return 'E2E-Test-Room-$timestamp';
  }

  static String generateMessage() {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    return 'E2E test message - $timestamp';
  }
}

/// Test expectations - use in assertions
class TestExpectations {
  // Auth expectations
  static const String expectedHomeScreen = 'Feed';
  static const String expectedLoggedInUser = 'Profile';

  // Room expectations
  static const String expectedRoomChat = 'Type a message';
  static const String expectedModerationPanel = 'Mute All';

  // Social expectations
  static const String expectedFriendsList = 'Friends';
  static const String expectedPresenceIndicator = '●'; // Green dot

  // Error messages (should NOT see these)
  static const String errorDeactivatedWidget =
      'Looking up a deactivated widget';
  static const String errorAuthFailed = 'Firebase auth failed';
  static const String errorPermissionDenied = 'Permission denied';
  static const String errorInvalidMember = 'invalid_use_of_protected_member';
}
