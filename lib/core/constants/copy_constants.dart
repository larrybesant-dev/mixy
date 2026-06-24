// Remove unused imports
// import 'dart:js_util' as js_util;
// import 'package:mixmingle/helpers/helpers.dart';
/// Mix & Mingle Humanized Copy Constants
/// Centralized, human-friendly text strings for the entire app
/// Tone: Playful, safe, inclusive. Short sentences. Contractions. No jargon.
library;

class CopyConstants {
  // Add any missing project-specific imports if needed

  // ============================================================================
  // 1ï¸âƒ£ SPLASH & ONBOARDING
  // ============================================================================

  static const String splashMessage = 'Finding your people...';

  // ============================================================================
  // 2ï¸âƒ£ LOGIN SCREEN
  // ============================================================================

  static const String loginTitle = 'Hey again ðŸ‘‹';
  static const String loginSubtitle = 'Let\'s get you back in the room';

  static const String loginEmailLabel = 'Email address';
  static const String loginEmailHint = 'you@example.com';

  static const String loginPasswordLabel = 'Password';
  static const String loginPasswordHint = 'Your password';

  static const String loginButton = 'Sign In';
  static const String loginSmallText = 'Takes about 2 seconds';

  static const String loginForgotPassword = 'Forgot your password?';
  static const String loginNoAccount = 'New here? ';
  static const String loginSignUp = 'Create an account';

  // Login Error Messages
  static const String loginErrorEmptyFields =
      'We need both your email and password ðŸ‘†';
  static const String loginErrorUserNotFound =
      'Hmm, we don\'t recognize that email. Mind double-checking?';
  static const String loginErrorWrongPassword =
      'Wrong password. Give it another shot?';
  static const String loginErrorNetwork =
      'Can\'t reach our servers right now. Check your connection and try again.';
  static const String loginErrorGeneric = 'Login failed. Try again?';

  // Login Loading States
  static const String loginLoadingMessage = 'Signing you in...';
  static const String loginSuccessMessage =
      'Welcome back! Loading your room...';

  // ============================================================================
  // 3ï¸âƒ£ SIGNUP SCREEN
  // ============================================================================

  static const String signupTitle = 'Let\'s get you started ðŸŽ‰';
  static const String signupSubtitle = 'It only takes 30 seconds, we promise';

  static const String signupNameLabel = 'What\'s your name?';
  static const String signupNameHint = 'e.g., Alex';

  static const String signupEmailLabel = 'Your email';
  static const String signupEmailHint = 'you@example.com';

  static const String signupPasswordLabel = 'Create a password';
  static const String signupPasswordHint = 'Min. 6 characters';

  static const String signupButton = 'Create My Account';

  static const String signupHasAccount = 'Already have an account? ';
  static const String signupSignIn = 'Sign in here';

  // Signup Error Messages
  static const String signupErrorEmptyFields =
      'Oops â€” we need all the info ðŸ‘†';
  static const String signupErrorShortPassword =
      'Your password needs at least 6 characters';
  static const String signupErrorEmailTaken =
      'That email\'s already taken. Want to log in instead?';
  static const String signupErrorNetwork =
      'Can\'t connect right now. Try again in a sec?';
  static const String signupErrorGeneric = 'Signup failed. Try again?';

  // Signup Loading States
  static const String signupLoadingMessage = 'Creating your account...';
  static const String signupSuccessMessage =
      'Welcome to the party! ðŸŽŠ Setting up your profile...';

  // ============================================================================
  // 4ï¸âƒ£ HOME SCREEN
  // ============================================================================

  static const String homeGreeting = 'Hey, there! ðŸ‘‹';
  static const String homeSubGreeting = 'Ready to meet someone new?';

  // Navigation Cards
  static const String homeRooms = 'Rooms';
  static const String homeRoomsSubtitle = 'Jump into a live room';

  static const String homeSpeedDating = 'Speed Dating';
  static const String homeSpeedDatingSubtitle = 'Match & date in 60 seconds';

  static const String homeMessages = 'Messages';
  static const String homeMessagesSubtitle = 'Talk to your matches';

  static const String homeEvents = 'Events';
  static const String homeEventsSubtitle = 'See what\'s happening';

  static const String homeProfile = 'Profile';
  static const String homeProfileSubtitle = 'Edit your vibe';

  static const String homeNotifications = 'Notifications';
  static const String homeNotificationsSubtitle = 'See what\'s new';

  static const String homeActivityTitle = 'What\'s happening';

  // App Bar Actions
  static const String homeSettingsTooltip = 'Tune your experience';
  static const String homeLogoutTooltip = 'See you soon!';

  // Bottom Navigation
  static const String navHome = 'Home';
  static const String navRooms = 'Rooms';
  static const String navChat = 'Chat';
  static const String navFavorites = 'Favorites';

  // ============================================================================
  // 5ï¸âƒ£ BROWSE ROOMS
  // ============================================================================

  static const String browseRoomsTitle = 'Jump into a room';
  static const String browseRoomsSubtitle = 'Pick one â€” or start your own';

  static const String browseSearchHint = 'Looking for something specific?';
  static const String browseFilterTooltip = 'Narrow it down';

  static const String browseCategoryAll = 'All vibes';
  static const String browseCategoryMusic = 'ðŸŽµ Music';
  static const String browseCategoryGaming = 'ðŸŽ® Gaming';
  static const String browseCategoryChat = 'ðŸ’¬ Chat';
  static const String browseCategoryLive = 'ðŸ”´ Live';

  static const String browseCreateRoom = 'Start your room';

  // Empty States
  static const String browseEmptyTitle = 'Looks quiet...';
  static const String browseEmptyMessage =
      'Why not break the silence? Start a room.';
  static const String browseEmptyButton = 'Launch a room';

  // Room Card
  static const String browseRoomViewers = 'chilling here';
  static const String browseJoinButton = 'Join the fun';

  // ============================================================================
  // 6ï¸âƒ£ CHAT & MESSAGES
  // ============================================================================

  static const String chatEmptyTitle = 'Your inbox is empty';
  static const String chatEmptyMessage = 'Go find someone to chat with ðŸ‘‰';

  static const String chatInputHint = 'Say hi ðŸ‘‹ ... or share a vibe';
  static const String chatSendTooltip = 'Send your magic âœ¨';

  static const String chatTypingIndicator = 'is typing...';
  static const String chatTypingLong = 'is thinking of something good...';

  static const String chatOnlineStatus = 'Online now';
  static const String chatOfflineStatus = 'Was here ';

  static const String chatPinnedLabel = 'ðŸ“Œ Pinned â€” read first';
  static const String chatUnsendLabel = 'Unsend';
  static const String chatBlockLabel = 'Block this person';
  static const String chatReportLabel = 'Report & block';

  // Message States
  static const String chatSending = 'Sending...';
  static const String chatSent = 'âœ”ï¸'; // Single checkmark
  static const String chatDelivered = 'âœ”âœ”'; // Double checkmark
  static const String chatRead = 'âœ”âœ”'; // Double checkmark (bright)

  // ============================================================================
  // 7ï¸âƒ£ ERRORS & VALIDATION
  // ============================================================================

  static const String errorGeneric =
      'Oops â€” something went wrong. Mind trying again?';
  static const String errorNetwork =
      'Can\'t reach the server right now. Check your connection?';
  static const String errorPermission =
      'We need your permission for this one. Check your settings?';
  static const String errorNotFound =
      'This doesn\'t exist anymore... but something else might surprise you';
  static const String errorTimeout = 'Taking too long. Try again?';
  static const String errorConnectionLost = 'Lost connection. Reconnecting...';
  static const String errorRoomFull =
      'That room\'s packed right now. Try another?';
  static const String errorUserBlocked =
      'They\'ve blocked messages. Respect that.';
  static const String errorAlreadyInRoom = 'You\'re already in this room!';

  // ============================================================================
  // 8ï¸âƒ£ EMPTY STATES (Pre-built Components)
  // ============================================================================

  static const String emptyNoEventsTitle = 'No events yet';
  static const String emptyNoEventsMessage =
      'Start planning. Get people excited. Make it happen.';
  static const String emptyNoEventsButton = 'Start an event';

  static const String emptyNoUsersTitle = 'No one yet';
  static const String emptyNoUsersMessage =
      'Keep exploring. Your person is out there.';
  static const String emptyNoUsersSubtitle =
      'Ready to mingle? Jump into a room.';

  static const String emptyNoRoomsTitle = 'No rooms live right now';
  static const String emptyNoRoomsMessage =
      'Why wait? Go live and start the party.';
  static const String emptyNoRoomsButton = 'Start a room';

  static const String emptyNoMatches = 'No one yet';
  static const String emptyNoMatchesMessage =
      'Keep exploring. Your person is out there.';

  static const String emptyNotificationsTitle = 'All caught up!';
  static const String emptyNotificationsMessage =
      'You\'re not missing anything. Yet ðŸ˜‰';

  // ============================================================================
  // 9ï¸âƒ£ BUTTONS & ACTIONS
  // ============================================================================

  // Primary Actions
  static const String buttonJoin = 'Join the fun';
  static const String buttonCreateRoom = 'Go live';
  static const String buttonSend = 'Send';
  static const String buttonCreateAccount = 'Create Account';
  static const String buttonSignIn = 'Sign In';
  static const String buttonSaveProfile = 'Save my vibe';
  static const String buttonEditProfile = 'Edit profile';
  static const String buttonRemove = 'Remove';
  static const String buttonCancel = 'Cancel';
  static const String buttonConfirm = 'Sounds good';

  // Secondary Actions
  static const String buttonLeave = 'Leave quietly';
  static const String buttonBlock = 'Block this person';
  static const String buttonReport = 'Report & block';
  static const String buttonSkip = 'Skip this one';
  static const String buttonLater = 'Ask me later';
  static const String buttonNotNow = 'Maybe next time';
  static const String buttonLearnMore = 'Tell me more';

  // ============================================================================
  // ðŸ”Ÿ FORM FIELDS & LABELS
  // ============================================================================

  // Profile Form
  static const String formNameLabel = 'What\'s your name?';
  static const String formNameHint = 'First name is fine';

  static const String formBioLabel = 'Tell us about you';
  static const String formBioHint = 'What do people need to know?';

  static const String formAgeLabel = 'Your age';
  static const String formAgeHint = 'Just for matching';

  static const String formLocationLabel = 'Where are you?';
  static const String formLocationHint = 'City or neighborhood';

  static const String formInterestsLabel = 'What do you love?';
  static const String formInterestsHint = 'Pick as many as you want';

  static const String formGenderLabel = 'Gender';
  static const String formLookingForLabel = 'What are you here for?';
  static const String formLookingForHint = 'Friends? Dating? Both?';

  // ============================================================================
  // 1ï¸âƒ£0ï¸âƒ£ SETTINGS & PREFERENCES
  // ============================================================================

  static const String settingsAccount = 'Your account';
  static const String settingsNotifications = 'Notify me when...';
  static const String settingsPrivacy = 'Who can see you';
  static const String settingsBlocked = 'People you\'ve blocked';
  static const String settingsHelp = 'Need help?';
  static const String settingsLogout = 'Leave Mix & Mingle';
  static const String settingsDeleteAccount = 'Delete everything';

  // Settings Messages
  static const String settingsLogoutMessage =
      'You\'ll be able to come back anytime.';
  static const String settingsDeleteWarning =
      'This is permanent. We\'ll delete everything.';

  // ============================================================================
  // 1ï¸âƒ£0ï¸âƒ£ + 1ï¸âƒ£ LOADING & WAITING STATES
  // ============================================================================

  static const String loadingGeneric = 'One sec...';
  static const String loadingRooms = 'Finding rooms...';
  static const String loadingProfile = 'Grabbing your profile...';
  static const String loadingJoiningRoom = 'Getting your seat ready...';
  static const String loadingSendingMessage = 'Sending...';
  static const String loadingUploadingPhoto = 'Making you look good...';
  static const String loadingSaving = 'Saving your changes...';

  // ============================================================================
  // 1ï¸âƒ£0ï¸âƒ£ + 2ï¸âƒ£ NOTIFICATIONS & ALERTS
  // ============================================================================

  // In-App Notifications
  static const String notifNewMessage = '[Message preview]';
  static const String notifUserJoinedRoom = 'just hopped in';
  static const String notifHostLive = 'just went live ðŸ”´';
  static const String notifMatchFound = 'It\'s a match! ðŸŽ‰';
  static const String notifFriendRequest = 'wants to connect';
  static const String notifBirthday = 'Happy birthday, [Name]! ðŸŽ‚';

  // ============================================================================
  // TONE GUIDELINES (for reference in code comments)
  // ============================================================================
  /*
   * âœ… DO:
   * - Use contractions ("you're", "it's", "can't")
   * - Keep sentences short (under 15 words)
   * - Use emojis sparingly (one per screen max)
   * - Be honest about errors
   * - Add gentle humor where appropriate
   * - Say "you" not "users"
   *
   * âŒ DON'T:
   * - Use robotic language ("submit", "proceed", "access")
   * - Over-explain
   * - Use corporate jargon
   * - Center everything (imperfection = human)
   * - Show too many options at once
   */
}
