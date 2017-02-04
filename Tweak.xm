// FRAMEWORKS
#import <CoreFoundation/CFNotificationCenter.h>
#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <SpringBoard/Springboard.h>
#import <GraphicsServices/GraphicsServices.h>

// DEFINITIONS
#define uniqueDomainString @"com.ge0rges.pcfios"
#define uniqueNotificationString @"com.ge0rges.pcfios.preferences.changed"

/* FORWARD DECLARATIONS */
@interface NSUserDefaults (UFS_Category)
- (id)objectForKey:(NSString *)key inDomain:(NSString *)domain;
- (void)setObject:(id)value forKey:(NSString *)key inDomain:(NSString *)domain;
@end

@interface SBUIController
+ (instancetype)sharedInstance;
- (UIWindow *)window;
@end

typedef enum {
  SBIconLocationHomeScreen = 0,
  SBIconLocationDock       = 1,
  SBIconLocationSwitcher   = 2
} SBIconLocation;

@interface SBApplicationIcon
- (NSString *)applicationBundleID;
- (NSString *)displayName;
- (void)launchFromLocation:(SBIconLocation)location context:(id)arg2; // >=iOS 9-10
@end

@interface PCFiOS : NSObject
- (void)decrementTimeSaved;
@end

/* GLOBAL VARIABLES */
static NSString *passcode = @"";// Contains the user set passcode. Use -getLatestPreferences to fetch.

static BOOL enabled;// Contains the user set BOOL that determines wether or not the tweak should run. Use -getLatestPreferences to fetch.
static BOOL timersShouldRun = YES;

static SBApplicationIcon *appIcon = nil;// Current ApplicationIcon (used to resume launch).
static SBIconLocation appLocation = SBIconLocationHomeScreen;// Current app launch location (used to resume launch).

static NSTimer *timer;// The main timer

static float savedTimeLeft;// Time left VARIABLES

static PCFiOS *pcfios;// Variable to hold our class in

/* IMPLEMENTATIONS AND FUNCTIONS*/

// Preferences
static void getLatestPreferences() {// Fetches the last saved state of the user set preferences: passcode and enabled.
  [[NSUserDefaults standardUserDefaults] synchronize];// Make sure all changes are synced

  // Get the passcode of the KeychainItem (security).
  passcode = [[NSUserDefaults standardUserDefaults] objectForKey:@"password" inDomain:uniqueDomainString];

  // Get the enabled state out of the UserDefaults.
  enabled = [[[NSUserDefaults standardUserDefaults] objectForKey:@"enabled" inDomain:uniqueDomainString] boolValue];

  // Get the saved time left
  NSNumber *savedTimeLeftNumber = [[NSUserDefaults standardUserDefaults] objectForKey:@"savedTimeLeft" inDomain:uniqueDomainString];
  if (!savedTimeLeftNumber) {
    [[NSUserDefaults standardUserDefaults] setObject:[NSNumber numberWithFloat:0.0] forKey:@"savedTimeLeft" inDomain:uniqueDomainString];
    [[NSUserDefaults standardUserDefaults] synchronize];// Make sure all changes are synced

    savedTimeLeft = 0;
  }

  savedTimeLeft = [savedTimeLeftNumber floatValue];
}

static NSNumber* timeLimitForDate (NSDate *date) {
  // Synchronize settings
[[NSUserDefaults standardUserDefaults] synchronize];

  // Get the last launch date, and check if today is a new day: "lastLaunchDate"
  NSCalendar *calender = [NSCalendar currentCalendar];
  unsigned unitFlags = NSYearCalendarUnit | NSMonthCalendarUnit | NSDayCalendarUnit;

  NSDateComponents *compDate = [calender components:unitFlags fromDate:date];

  //If new day reset: "savedTimeLeft" to either "hoursWeekdays" or "hoursWeekends" based on current day, then start timer.
  NSString *hoursKey = ([compDate weekday] == 1 || [compDate weekday] == 7) ? @"hoursWeekends" : @"hoursWeekdays";
  NSNumber *oneDayTime = [[NSUserDefaults standardUserDefaults] objectForKey:hoursKey inDomain:uniqueDomainString];

  return oneDayTime;
}

static BOOL applicationIconWithLocationShouldLaunch(SBApplicationIcon *icon, SBIconLocation location) {
  // INFO: TO LAUNCH THE APP ANYWHERE: 			[appIcon launchFromLocation:appLocation context:nil];
  appIcon = icon;
  appLocation = location;

  // TO DO: Check against a whitelist.
  NSArray *alwaysAllowApps = @[@"com.apple.preferences"];
  if ([alwaysAllowApps containsObject:[icon applicationBundleID].lowercaseString]) {
    return YES;
  }

  // Check if time left
  if (savedTimeLeft && enabled) {
    return (savedTimeLeft > 0);
  }

  return YES;
}

static void decrementTimeSaved() {// Decrements the "savedTimeLeft" and goes through a series of checks
 savedTimeLeft -= 300.0;// This gets pinged every 5 minutes
 if (savedTimeLeft < 0 && enabled && timer) {
   [timer invalidate];
   timer = nil;
   [timer release];

   timersShouldRun = NO;
 }

 [[NSUserDefaults standardUserDefaults] setObject:[NSNumber numberWithFloat:savedTimeLeft] forKey:@"savedTimeLeft" inDomain:uniqueDomainString];
 [[NSUserDefaults standardUserDefaults] synchronize];
}

@implementation PCFiOS
- (void)decrementTimeSaved {
  decrementTimeSaved();
}

@end

// NOTIFICATIONS
static void lockStateChanged(CFNotificationCenterRef center, void *observer, CFStringRef name, const void *object, CFDictionaryRef userInfo) {

  //the "com.apple.springboard.lockcomplete" notification will always come after the "com.apple.springboard.lockstate" notification
  NSString *lockState = (NSString*)name;
  getLatestPreferences();

  if ([lockState.lowercaseString isEqualToString:@"com.apple.springboard.lockcomplete"] && enabled && timer) {// Device locked. Stop timers.
    [timer invalidate];
    timer = nil;
    [timer release];

  } else if (timersShouldRun && enabled) {// Device Unlocked and we should time it (conservatively).
    if (timer) {
      [timer invalidate];
      timer = nil;
      [timer release];
    }

    // Ping every 5 minutes.
    timer = [NSTimer scheduledTimerWithTimeInterval:300.0 target:pcfios selector:@selector(decrementTimeSaved) userInfo:nil repeats:YES];
    [timer retain];
  }
}


static void tweakSettingsChanged(CFNotificationCenterRef center, void *observer, CFStringRef name, const void *object, CFDictionaryRef userInfo) {
  // Sync NSUserDefaults changes
  [[NSUserDefaults standardUserDefaults] synchronize];

  // Adjust time limit for new settings, by adding the difference the last time limit, and the new one to the saved time left.
  NSNumber *timeLimitForToday = timeLimitForDate([NSDate date]);

  float newTimeLimitForToday = [timeLimitForToday floatValue];
  float oldTimeLimitForToday = [[[NSUserDefaults standardUserDefaults] objectForKey:@"timeLimitToday" inDomain:uniqueDomainString] floatValue];

  // Update the time left & timeLimitToday.
  savedTimeLeft = savedTimeLeft + (newTimeLimitForToday - oldTimeLimitForToday);
  [[NSUserDefaults standardUserDefaults] setObject:[NSNumber numberWithFloat:savedTimeLeft] forKey:@"savedTimeLeft" inDomain:uniqueDomainString];
  [[NSUserDefaults standardUserDefaults] setObject:timeLimitForToday forKey:@"timeLimitToday" inDomain:uniqueDomainString];
  [[NSUserDefaults standardUserDefaults] synchronize];

  getLatestPreferences();// Update all other prefs.

  // Reset timer
  if (savedTimeLeft > 0 && enabled) {
    timersShouldRun = YES;

    if (timer) {
      [timer invalidate];
      timer = nil;
      [timer release];
    }

    // Change 1.0 to 500 in production
    timer = [NSTimer scheduledTimerWithTimeInterval:300.0 target:pcfios selector:@selector(decrementTimeSaved) userInfo:nil repeats:YES];
    [timer retain];
  }
}

%ctor {// Called when loading the binary.
  // Fetch the latest preferences.
  getLatestPreferences();

  // Init our class once and for all.
  pcfios = [PCFiOS new];
  [pcfios retain];

  // The current date will be needed in both scopes.
  NSDate *todayDate = [NSDate date];

  // Set the timit limit for today before all else.
  NSNumber *timeLimitForToday = timeLimitForDate(todayDate);
  [[NSUserDefaults standardUserDefaults] setObject:timeLimitForToday forKey:@"timeLimitToday" inDomain:uniqueDomainString];

  if (enabled) {// Check if the tweak should run.
    // Get the last launch date, and check if today is a new day: "lastLaunchDate"
    NSDate *lastLaunchDate = [[NSUserDefaults standardUserDefaults] objectForKey:@"lastLaunchDate" inDomain:uniqueDomainString];

    NSCalendar *calender = [NSCalendar currentCalendar];
    unsigned unitFlags = NSYearCalendarUnit | NSMonthCalendarUnit | NSDayCalendarUnit;

    NSDateComponents *compOne = [calender components:unitFlags fromDate:lastLaunchDate];
    NSDateComponents *compTwo = [calender components:unitFlags fromDate:todayDate];

    if (([compOne day] != [compTwo day] && [compOne month] == [compTwo month] && [compOne year] == [compTwo year]) || !lastLaunchDate) {
      //If new day reset: "savedTimeLeft" to either "hoursWeekdays" or "hoursWeekends" based on current day, then start timer.
      [[NSUserDefaults standardUserDefaults] setObject:timeLimitForToday forKey:@"savedTimeLeft" inDomain:uniqueDomainString];
      savedTimeLeft = [timeLimitForToday floatValue];

      // Mark the timer to start.
      timersShouldRun = YES;

    } else {//Otherwise, resume timers.
      timersShouldRun = YES;
    }

  } else {
    timersShouldRun = NO;
  }

  // Update "lastLaunchDate".
  [[NSUserDefaults standardUserDefaults] setObject:todayDate forKey:@"lastLaunchDate" inDomain:uniqueDomainString];

  // Register for tweak preference changes notifications (must do this even if tweak is disabled, in case it gets enabled).
  CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(), NULL, tweakSettingsChanged, (CFStringRef)uniqueNotificationString, NULL, CFNotificationSuspensionBehaviorDeliverImmediately);

  // Register for lock state changes
  CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(), NULL, lockStateChanged, (CFStringRef)@"com.apple.springboard.lockstate", NULL, CFNotificationSuspensionBehaviorDeliverImmediately);
  CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(), NULL, lockStateChanged, (CFStringRef)@"com.apple.springboard.lockcomplete", NULL, CFNotificationSuspensionBehaviorDeliverImmediately);
}

%dtor {// Called when tweak gets unloaded.
  // Save the time left before the tweak gets unloaded.
  [[NSUserDefaults standardUserDefaults] setObject:[NSNumber numberWithFloat:savedTimeLeft] forKey:@"savedTimeLeft" inDomain:uniqueDomainString];
  [[NSUserDefaults standardUserDefaults] synchronize];
}

%hook SBApplicationIcon

- (void)launchFromLocation:(SBIconLocation)location context:(id)context {// Called when user tries to launch an app. (iOS 9-10)
  // Get the top window to be used later
  UIWindow *topWindow = [[NSClassFromString(@"SBUIController") sharedInstance] window];

  // Check that this isn't an unauthorized Cydia launch
  if ([[self applicationBundleID].lowercaseString isEqualToString:@"com.saurik.cydia"] && passcode.length > 0 && enabled) {
    UIAlertController *alertController = [UIAlertController alertControllerWithTitle:@"Please Enter your Parent-Pass to authenticate this action" message:nil preferredStyle:UIAlertControllerStyleAlert];

    // Add textField
    [alertController addTextFieldWithConfigurationHandler:^(UITextField *textfield) {
      textfield.secureTextEntry = YES;
      textfield.keyboardType = UIKeyboardTypeNumberPad;
    }];

    [alertController addAction:[UIAlertAction actionWithTitle:@"Authenticate" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
      NSString *enteredPasscode = ((UITextField *)alertController.textFields.firstObject).text;
      if ([enteredPasscode isEqualToString:passcode]) {
        %orig;// Launch Cydia

      } else {// Notify the user of incorrect password.
        UIAlertController *dismissAC = [UIAlertController alertControllerWithTitle:@"Incorrect Passcode" message:nil preferredStyle:UIAlertControllerStyleAlert];
        [dismissAC addAction:[UIAlertAction actionWithTitle:@"Ok" style:UIAlertActionStyleCancel handler:nil]];
        [topWindow.rootViewController presentViewController:dismissAC animated:YES completion:nil];
      }
    }]];

    [alertController addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];

    [topWindow.rootViewController presentViewController:alertController animated:YES completion:nil];

    return;

  } else if (applicationIconWithLocationShouldLaunch(self, location)) {// Check wether the time has run out.
    %orig();

  } else {// Time's up!
    // Show a alert view.
    int seconds = 0;
    int minutes = 0;
    int hours = 0;

    if (savedTimeLeft > 0) {
      seconds = (int)savedTimeLeft % 60;
      minutes = ((int)savedTimeLeft / 60) % 60;
      hours = (int)savedTimeLeft / 3600;
    }

    NSString *messageString = [NSString stringWithFormat:@"%02d:%02d:%02d",hours, minutes, seconds];

    UIAlertController *timesUpAC = [UIAlertController alertControllerWithTitle:@"Times Up!" message:messageString preferredStyle:UIAlertControllerStyleAlert];
    [timesUpAC addAction:[UIAlertAction actionWithTitle:@"Aww" style:UIAlertActionStyleDestructive handler:nil]];
    [topWindow.rootViewController presentViewController:timesUpAC animated:YES completion:nil];
  }
}

%end
