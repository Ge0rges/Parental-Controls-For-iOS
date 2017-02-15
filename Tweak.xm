/* FRAMEWORKS */
#import <CoreFoundation/CFNotificationCenter.h>
#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <SpringBoard/Springboard.h>
#import <objc/runtime.h>

/* DEFINITIONS */
#define uniqueDomainString @"com.ge0rges.pcfios"
#define uniqueNotificationString @"com.ge0rges.pcfios.preferences.changed"

/* FORWARD DECLARATIONS */
@interface NSUserDefaults (UFS_Category)
- (id)objectForKey:(NSString *)key inDomain:(NSString *)domain;
- (void)setObject:(id)value forKey:(NSString *)key inDomain:(NSString *)domain;
@end

@interface SBUIController
+ (instancetype)sharedInstance;
+ (instancetype)sharedInstanceIfExists;
- (UIWindow *)window;
- (void)activateApplication:(SBApplication *)arg1;
@end


@interface SBApplicationController
+ (instancetype)sharedInstance;
+ (instancetype)sharedInstanceIfExists;
- (id)applicationWithBundleIdentifier:(id)arg1;
@end

@interface UIAlertController (Window)
- (void)show;
- (void)show:(BOOL)animated;

@property (nonatomic, strong) UIWindow *alertWindow;

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
- (void)handleTimesUp;
@end

/* GLOBAL VARIABLES */
static NSString *passcode = @"";// Contains the user set passcode. Use -getLatestPreferences to fetch.

static BOOL enabled;// Contains the user set BOOL that determines wether or not the tweak should run. Use -getLatestPreferences to fetch.
static BOOL recentlyLocked = NO;// used to keep track of the lockstate notifications.

static UIAlertController *timesUpAlertController = nil;// The alert shown when time's up.

static NSTimer *timer = nil;// The main timer

static float savedTimeLeft;// Time left VARIABLES

static PCFiOS *pcfios = nil;// Variable to hold our class in

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
  NSNumber *extraTime = [[NSUserDefaults standardUserDefaults] objectForKey:@"extraTime" inDomain:uniqueDomainString];

  return [NSNumber numberWithFloat:([oneDayTime floatValue] + [extraTime floatValue])];
}

// Notifications
static void lockStateChanged(CFNotificationCenterRef center, void *observer, CFStringRef name, const void *object, CFDictionaryRef userInfo) {

  // "com.apple.springboard.lockcomplete" indicates locked device. "com.apple.springboard.lockstate" indicates lock status changed.
  // Therefore lockstate is called when devie is locked *and* unlocked.
  NSString *lockState;
  if (name) {
    lockState = (__bridge NSString*)name;
  } else {
    lockState = @"selfCalled";
  }

  getLatestPreferences();

  // Check if this the following "lockstate" notification froma  previous locckcomplete. If so, reset our indicator.
  if (recentlyLocked) {
    recentlyLocked = NO;
    return;
  }

  if ([lockState.lowercaseString isEqualToString:@"com.apple.springboard.lockcomplete"]) {// Device locked. Stop timers.
    if (timer) {
      [timer invalidate];
      timer = nil;
      [timer release];
    }
    // Hide the parental blocking window
    if (timesUpAlertController) {
      [timesUpAlertController dismissViewControllerAnimated:NO completion:nil];
      timesUpAlertController = nil;
      [timesUpAlertController release];
    }

    // Mark as recently locked for a few miliseconds.
    recentlyLocked = YES;

  } else if (enabled && !timer && !recentlyLocked && savedTimeLeft > 0) {// Device unlocked with time, start a timer.
    // Ping every 5 minutes.
    timer = [NSTimer scheduledTimerWithTimeInterval:5.0 target:pcfios selector:@selector(decrementTimeSaved) userInfo:nil repeats:YES];
    [timer retain];

  } else if (enabled && savedTimeLeft <= 0 && !recentlyLocked) {// Device unlocked with no time, handle times up.
    [pcfios handleTimesUp];
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
    if (timer) {
      [timer invalidate];
      timer = nil;
      [timer release];
    }

    // Every 5 seconds
    timer = [NSTimer scheduledTimerWithTimeInterval:5.0 target:pcfios selector:@selector(decrementTimeSaved) userInfo:nil repeats:YES];
    [timer retain];
  }
}

static void handleTimesUp() {
  // Present an alert view explaining the situation, and providing options.
  if (!timesUpAlertController) {
    timesUpAlertController = [UIAlertController alertControllerWithTitle:@"Time's Up!" message:@"You've run out of time for today. Here are your options:" preferredStyle:UIAlertControllerStyleAlert];
    [timesUpAlertController retain];

    // Add textField
    __block UITextField *localTextField;// To avoid increasing the retain count on the alert
    [timesUpAlertController addTextFieldWithConfigurationHandler:^(UITextField *textfield) {
      localTextField = textfield;
      textfield.secureTextEntry = YES;
      textfield.keyboardType = UIKeyboardTypeNumberPad;
    }];

    [timesUpAlertController addAction:[UIAlertAction actionWithTitle:@"Add 1 Hour" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
      NSString *enteredPasscode = localTextField.text;
      if ([enteredPasscode isEqualToString:passcode]) {// Check for Correct password.
        // Add 3600 to extraTime, notify of settings changed.
        NSNumber *extraTime = [[NSUserDefaults standardUserDefaults] objectForKey:@"extraTime" inDomain:uniqueDomainString];
        [[NSUserDefaults standardUserDefaults] setObject:[NSNumber numberWithFloat:([extraTime floatValue] + 3600.0)] forKey:@"extraTime" inDomain:uniqueDomainString];

        timesUpAlertController = nil;
        [timesUpAlertController release];

        tweakSettingsChanged(nil, nil, nil, nil, nil);

      } else {// Notify the user of incorrect password.
        UIAlertController *dismissAC = [UIAlertController alertControllerWithTitle:@"Incorrect Passcode" message:nil preferredStyle:UIAlertControllerStyleAlert];
        [dismissAC addAction:[UIAlertAction actionWithTitle:@"Ok" style:UIAlertActionStyleCancel handler:^(UIAlertAction *action) {
          timesUpAlertController = nil;
          [timesUpAlertController release];

          handleTimesUp();// Return to the initial alert view
        }]];
        [dismissAC show];
      }
    }]];

    // In future version
    // [timesUpAlertController addAction:[UIAlertAction actionWithTitle:@"Open Settings" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action){
    //   SBApplication *settingsApp = [[NSClassFromString(@"SBApplicationController") sharedInstance] applicationWithBundleIdentifier:@"com.apple.Preferences"];
    //   [[NSClassFromString(@"SBUIController") sharedInstanceIfExists] activateApplication:settingsApp];
    //
    //   [pcfios performSelector:@selector(handleTimesUp) withObject:nil afterDelay:300];
    // }]];
    //
    // [timesUpAlertController addAction:[UIAlertAction actionWithTitle:@"Open Phone" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action){
    //   SBApplication *phoneApp = [[NSClassFromString(@"SBApplicationController") sharedInstance] applicationWithBundleIdentifier:@"com.yourcompany.mobilephone"];
    //   [[NSClassFromString(@"SBUIController") sharedInstanceIfExists] activateApplication:phoneApp];
    //
    //   [pcfios performSelector:@selector(handleTimesUp) withObject:nil afterDelay:300];
    // }]];
    //
    // [timesUpAlertController addAction:[UIAlertAction actionWithTitle:@"Open Messages" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action){
    //   SBApplication *messagesApp = [[NSClassFromString(@"SBApplicationController") sharedInstance] applicationWithBundleIdentifier:@"com.apple.MobileSMS"];
    //   [[NSClassFromString(@"SBUIController") sharedInstanceIfExists] activateApplication:messagesApp];
    //
    //   [pcfios performSelector:@selector(handleTimesUp) withObject:nil afterDelay:300];
    // }]];
  }

  [timesUpAlertController show];
}

static void decrementTimeSaved() {// Decrements the "savedTimeLeft" and goes through a series of checks
savedTimeLeft -= 5.0;// This gets pinged every 5 minutes
if (savedTimeLeft < 0 && enabled && timer) {
  [timer invalidate];
  timer = nil;
  [timer release];

  savedTimeLeft = 0;

  handleTimesUp();
}

[[NSUserDefaults standardUserDefaults] setObject:[NSNumber numberWithFloat:savedTimeLeft] forKey:@"savedTimeLeft" inDomain:uniqueDomainString];
[[NSUserDefaults standardUserDefaults] synchronize];
}

@implementation PCFiOS
- (void)decrementTimeSaved {
  decrementTimeSaved();
}

- (void)handleTimesUp {
  handleTimesUp();
}

@end

// http://stackoverflow.com/questions/26554894/how-to-present-uialertcontroller-when-not-in-a-view-controller
@implementation UIAlertController (Window)
@dynamic alertWindow;

- (void)setAlertWindow:(UIWindow *)alertWindow {
  objc_setAssociatedObject(self, @selector(alertWindow), alertWindow, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (UIWindow *)alertWindow {
  return objc_getAssociatedObject(self, @selector(alertWindow));
}

- (void)show {
  [self show:YES];
}

- (void)show:(BOOL)animated {
  self.alertWindow = [[UIWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
  self.alertWindow.rootViewController = [[UIViewController alloc] init];

  id<UIApplicationDelegate> delegate = [UIApplication sharedApplication].delegate;
  // Applications that does not load with UIMainStoryboardFile might not have a window property:
  if ([delegate respondsToSelector:@selector(window)]) {
    // we inherit the main window's tintColor
    self.alertWindow.tintColor = delegate.window.tintColor;
  }

  // window level is above the top window (this makes the alert, if it's a sheet, show over the keyboard)
  UIWindow *topWindow = [UIApplication sharedApplication].windows.lastObject;
  self.alertWindow.windowLevel = topWindow.windowLevel + 1;

  [self.alertWindow makeKeyAndVisible];
  [self.alertWindow.rootViewController presentViewController:self animated:animated completion:nil];
}

- (void)viewDidDisappear:(BOOL)animated {
  [super viewDidDisappear:animated];

  // precaution to insure window gets destroyed
  self.alertWindow.hidden = YES;
  self.alertWindow = nil;
}

@end

static void setupTweakForTimeEvent(CFNotificationCenterRef center, void *observer, CFStringRef name, const void *object, CFDictionaryRef userInfo) {
  // The current date will be needed in both scopes.
  NSDate *todayDate = [NSDate date];

  // Get the timit limit for today before all else.
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

      // New day, reset any extraTime
      [[NSUserDefaults standardUserDefaults] setObject:[NSNumber numberWithFloat:0.0] forKey:@"extraTime" inDomain:uniqueDomainString];

      // Remove the alert view if it exists
      if (timesUpAlertController) {
        [timesUpAlertController dismissViewControllerAnimated:YES completion:nil];
        timesUpAlertController = nil;
        [timesUpAlertController release];
      }
    }
  }

  // Update "lastLaunchDate".
  [[NSUserDefaults standardUserDefaults] setObject:todayDate forKey:@"lastLaunchDate" inDomain:uniqueDomainString];
}

%ctor {// Called when loading the binary.
  // Fetch the latest preferences.
  getLatestPreferences();

  // Init our class once and for all.
  pcfios = [PCFiOS new];
  [pcfios retain];

  // Launch Setup
  setupTweakForTimeEvent(nil, nil, nil, nil, nil);

  // Register for tweak preference changes notifications (must do this even if tweak is disabled, in case it gets enabled).
  CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(), NULL, tweakSettingsChanged, (CFStringRef)uniqueNotificationString, NULL, CFNotificationSuspensionBehaviorDeliverImmediately);

  // Register for lock state changes
  CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(), NULL, lockStateChanged, (__bridge CFStringRef)@"com.apple.springboard.lockstate", NULL, CFNotificationSuspensionBehaviorDeliverImmediately);
  CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(), NULL, lockStateChanged, (__bridge CFStringRef)@"com.apple.springboard.lockcomplete", NULL, CFNotificationSuspensionBehaviorDeliverImmediately);

  // Register for day changes
  CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(), NULL, setupTweakForTimeEvent, (__bridge CFStringRef)NSCalendarDayChangedNotification, NULL, CFNotificationSuspensionBehaviorDeliverImmediately);

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

  }
  %orig();
}

%end
