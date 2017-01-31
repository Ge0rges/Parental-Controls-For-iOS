// FRAMEWORKS
#import <CoreFoundation/CFNotificationCenter.h>
#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <SpringBoard/Springboard.h>
#import <GraphicsServices/GraphicsServices.h>

// CLASSES
#import "KeychainItemWrapper.h"

// DEFINITIONS
#define kCFCoreFoundationVersionNumber_iOS_7_0 847.20
#define uniqueDomainString @"com.ge0rges.pcfios"
#define uniqueNotificationString @"com.gnos.pcfios.preferences.changed"

/* GLOBAL VARIABLES */
static PCFiOS *pcfios;// Holds the instance of the tweak's main class.
static NSString *passcode = @"";// Contains the user set passcode. Use -getLatestPreferences to fetch.
static BOOL enabled;// Contains the user set BOOL that determines wether or not the tweak should run. Use -getLatestPreferences to fetch.


/* FORWARD DECLARATIONS */
@interface NSUserDefaults (UFS_Category)
- (id)objectForKey:(NSString *)key inDomain:(NSString *)domain;
- (void)setObject:(id)value forKey:(NSString *)key inDomain:(NSString *)domain;
@end


@interface PCFiOS : NSObject// Main Tweak Class
- (void)getLatestPreferences;

@end


/* IMPLEMENTATIONS */
@implementation PCFiOS

// Preferences
- (void)getLatestPreferences {// Fetches the last saved state of the user set preferences: passcode and enabled.
    // Set our prefs variables
    KeychainItemWrapper *keychainItem = [[KeychainItemWrapper alloc] initWithIdentifier:uniqueDomainString accessGroup:nil];

    passcode = [keychainItem objectForKey:(id)kSecValueData];
    [passcode retain];
    [keychainItem release];
    
    HBInfoLog(@"Set passcode to: [%@]", passcode);

    enabled = [[[NSUserDefaults standardUserDefaults] objectForKey:@"enabled" inDomain:uniqueDomainString] boolValue];
}


@end


@implementation UIAlertViewDelegateClass

- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex {}

- (void)alertView:(UIAlertView *)alertView didDismissWithButtonIndex:(NSInteger)buttonIndex {}

@end


static void tweakSettingsChanged(CFNotificationCenterRef center, void *observer, CFStringRef name, const void *object, CFDictionaryRef userInfo) {}



%ctor {// Called when loading the binary.
    // Create a instance of our main class.
    pcfios = [PCFiOS new];
    [pcfios retain];
    
    // Fetch the latest preferences.
    [pcfios getLatestPreferences];
    
    if (!enabled) {// Check if the tweak should run.
      [pcfios release];// Free up memory, tweak is disabled.
    }
  
  // Register for tweak preference changes notifications.
  CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(), NULL, tweakSettingsChanged, (CFStringRef)uniqueNotificationString, NULL, CFNotificationSuspensionBehaviorCoalesce);
}
