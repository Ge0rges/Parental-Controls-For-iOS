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

@interface UIAlertViewDelegateClass : NSObject <UIAlertViewDelegate>

@end

/* GLOBAL VARIABLES */
static NSString *passcode = @"";// Contains the user set passcode. Use -getLatestPreferences to fetch.

static BOOL enabled;// Contains the user set BOOL that determines wether or not the tweak should run. Use -getLatestPreferences to fetch.
static BOOL timersShouldRun = YES;

static SBApplicationIcon *appIcon = nil;// Current ApplicationIcon (used to resume launch).
static SBIconLocation appLocation = SBIconLocationHomeScreen;// Current app launch location (used to resume launch).



/* IMPLEMENTATIONS AND FUNCTIONS*/

// Preferences
static void getLatestPreferences() {// Fetches the last saved state of the user set preferences: passcode and enabled.
  // Get the passcode of the KeychainItem (security).
  passcode = [[NSUserDefaults standardUserDefaults] objectForKey:@"password" inDomain:uniqueDomainString];

  // Get the enabled state out of the UserDefaults.
  enabled = [[[NSUserDefaults standardUserDefaults] objectForKey:@"enabled" inDomain:uniqueDomainString] boolValue];
}

static BOOL applicationIconWithLocationShouldLaunch(SBApplicationIcon *icon, SBIconLocation location) {
  // INFO: TO LAUNCH THE APP ANYWHERE: 			[appIcon launchFromLocation:appLocation context:nil];
  appIcon = icon;
  appLocation = location;

  // Check if time left: savedTimeLeft
  NSNumber *savedTimeLeft = [[NSUserDefaults standardUserDefaults] objectForKey:@"savedTimeLeft" inDomain:uniqueDomainString];
  if (savedTimeLeft) {
    return ([savedTimeLeft floatValue] > 0);
  }

  return YES;
}


@implementation UIAlertViewDelegateClass
- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex {}
- (void)alertView:(UIAlertView *)alertView didDismissWithButtonIndex:(NSInteger)buttonIndex {}

@end


static void tweakSettingsChanged(CFNotificationCenterRef center, void *observer, CFStringRef name, const void *object, CFDictionaryRef userInfo) {
// HANDLE ENABLE <-> DISABLE. TIME LIMIT CHANGE.
}

%ctor {// Called when loading the binary.
  HBLogDebug(@"PCFiOS: ctor called.");

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

      // Mark the timer to start.
      timersShouldRun = YES;

    } else {//Otherwise, resume timers.
      timersShouldRun = YES;
    }
  }

  // Update "lastLaunchDate".
  [[NSUserDefaults standardUserDefaults] setObject:todayDate forKey:@"lastLaunchDate" inDomain:uniqueDomainString];

  // Register for tweak preference changes notifications (must do this even if tweak is disabled, in case it gets enabled).
  CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(), NULL, tweakSettingsChanged, (CFStringRef)uniqueNotificationString, NULL, CFNotificationSuspensionBehaviorCoalesce);
}

%hook SBApplicationIcon

- (void)launchFromLocation:(SBIconLocation)location context:(id)context {// Called when user tries to launch an app. (iOS 9-10)
  HBLogDebug(@"PCFiOS: launchFromLocation hooked.");

  if (applicationIconWithLocationShouldLaunch(self, location)) {// Check wether the time has run out.
    %orig();

    // Set a timer until the app quits.

  } else {
    // Time has run out. Show an alert.

  }
}

%end

%hook SBApplication

%end
