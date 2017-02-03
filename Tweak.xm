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

static NSTimer *timer;

static float savedTimeLeft;

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
  }

  savedTimeLeft = 0;
}

static BOOL applicationIconWithLocationShouldLaunch(SBApplicationIcon *icon, SBIconLocation location) {
  // INFO: TO LAUNCH THE APP ANYWHERE: 			[appIcon launchFromLocation:appLocation context:nil];
  appIcon = icon;
  appLocation = location;

  // TO DO: Check against a blacklist.

  // Check if time left: savedTimeLeft
  if (savedTimeLeft && enabled) {
    return (savedTimeLeft > 0);
  }

  return YES;
}

static void decrementTimeSaved() {// Decrements the "savedTimeLeft" and goes through a series of checks
 savedTimeLeft -= 1.0;
 if (savedTimeLeft < 0 && enabled && timer) {
   [timer invalidate];
   timer = nil;
   [timer release];

   [[NSUserDefaults standardUserDefaults] setObject:[NSNumber numberWithFloat:savedTimeLeft] forKey:@"savedTimeLeft" inDomain:uniqueDomainString];
   [[NSUserDefaults standardUserDefaults] synchronize];
 }
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

  if ([lockState isEqualToString:@"com.apple.springboard.lockcomplete"] && enabled && timer) {// Device locked. Stop timers.
    [timer invalidate];
    timer = nil;
    [timer release];

  } else if (timersShouldRun && enabled) {// Device Unlocked and we should time it (conservatively).
    if (timer) {
      [timer invalidate];
      timer = nil;
      [timer release];
    }

    // Change 1.0 to 500 in production
    timer = [[NSTimer scheduledTimerWithTimeInterval:1.0 target:[PCFiOS new] selector:@selector(decrementTimeSaved:) userInfo:nil repeats:NO] retain];
  }
}


static void tweakSettingsChanged(CFNotificationCenterRef center, void *observer, CFStringRef name, const void *object, CFDictionaryRef userInfo) {
  getLatestPreferences();
}

%ctor {// Called when loading the binary.
  // Fetch the latest preferences.
  getLatestPreferences();

  // The current date will be needed in both scopes.
  NSDate *todayDate = [NSDate date];

  if (enabled) {// Check if the tweak should run.
    // Get the last launch date, and check if today is a new day: "lastLaunchDate"
    NSDate *lastLaunchDate = [[NSUserDefaults standardUserDefaults] objectForKey:@"lastLaunchDate" inDomain:uniqueDomainString];

    NSCalendar *calender = [NSCalendar currentCalendar];
    unsigned unitFlags = NSYearCalendarUnit | NSMonthCalendarUnit | NSDayCalendarUnit;

    NSDateComponents *compOne = [calender components:unitFlags fromDate:lastLaunchDate];
    NSDateComponents *compTwo = [calender components:unitFlags fromDate:todayDate];

    if (([compOne day] == [compTwo day] && [compOne month] == [compTwo month] && [compOne year] == [compTwo year]) || !lastLaunchDate) {
      //If new day reset: "savedTimeLeft" to either "hoursWeekdays" or "hoursWeekends" based on current day, then start timer.
      NSString *hoursKey = ([compTwo weekday] == 1 || [compTwo weekday] == 7) ? @"hoursWeekends" : @"hoursWeekdays";
      NSNumber *oneDayTime = [[NSUserDefaults standardUserDefaults] objectForKey:hoursKey inDomain:uniqueDomainString];
      [[NSUserDefaults standardUserDefaults] setObject:oneDayTime forKey:@"savedTimeLeft" inDomain:uniqueDomainString];
      savedTimeLeft = [oneDayTime floatValue];

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
  CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(), NULL, tweakSettingsChanged, (CFStringRef)uniqueNotificationString, NULL, CFNotificationSuspensionBehaviorCoalesce);

  // Register for lock state changes
  CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(), NULL, lockStateChanged, (CFStringRef)@"com.apple.springboard.lockstate", NULL, CFNotificationSuspensionBehaviorCoalesce);
  CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(), NULL, lockStateChanged, (CFStringRef)@"com.apple.springboard.lockcomplete", NULL, CFNotificationSuspensionBehaviorCoalesce);
}

%hook SBApplicationIcon

- (void)launchFromLocation:(SBIconLocation)location context:(id)context {// Called when user tries to launch an app. (iOS 9-10)
  // Check that this isn't an unauthorized Cydia launch
  if ([[self applicationBundleID] isEqualToString:@"com.saurik.Cydia"] && passcode.length > 0 && enabled) {
    UIWindow *topWindow = [[NSClassFromString(@"SBUIController") sharedInstance] window];

    UIAlertController *alertController = [UIAlertController alertControllerWithTitle:@"Please Enter your Parent-Pass to authenticate this action" message:nil preferredStyle:UIAlertControllerStyleAlert];

    // Add textField
    [alertController addTextFieldWithConfigurationHandler:^(UITextField *textfield) {
      textfield.secureTextEntry = YES;
      textfield.keyboardType = UIAlertViewStyleSecureTextInput;
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
  }
}

%end
