#include <CoreFoundation/CFNotificationCenter.h>
#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <SpringBoard/Springboard.h>
#import <GraphicsServices/GraphicsServices.h>
#import "KeychainItemWrapper.h"

#define kCFCoreFoundationVersionNumber_iOS_7_0 847.20
#define domainString "com.ge0rges.pcfios"
#define notificationString "com.gnos.pcfios.preferences.changed"

@interface NSUserDefaults (UFS_Category)
- (id)objectForKey:(NSString *)key inDomain:(NSString *)domain;
- (void)setObject:(id)value forKey:(NSString *)key inDomain:(NSString *)domain;
@end


@interface PCFiOS : NSObject
- (void)getLatestPreferences;

@end

static PCFiOS *pcfios;

@implementation PCFiOS
// Preferences
- (void)getLatestPreferences {
    // Set our prefs variables
    KeychainItemWrapper *keychainItem = [[KeychainItemWrapper alloc] initWithIdentifier:@"com.ge0rges.pcfios" accessGroup:nil];

    passcode = [keychainItem objectForKey:(id)kSecValueData];
    [passcode retain];
    [keychainItem release];
    
    HBInfoLog(@"Set passcode to: [%@]", passcode);

    enabled = [[[NSUserDefaults standardUserDefaults] objectForKey:@"enabled" inDomain:@domainString] boolValue];
}


@end

@interface UIAlertViewDelegateClass : NSObject <UIAlertViewDelegate>
@end

static UIAlertViewDelegateClass *avdc;

@implementation UIAlertViewDelegateClass

- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex {
}

- (void)alertView:(UIAlertView *)alertView didDismissWithButtonIndex:(NSInteger)buttonIndex {
}

@end


static void settingsChangedNotificationCallback(CFNotificationCenterRef center, void *observer, CFStringRef name, const void *object, CFDictionaryRef userInfo) {
}

%ctor {
    //create a instance of our main class
    pcfios = [PCFiOS new];
    [pcfios retain];
    
    //update the prefs
    [pcfios getLatestPreferences];
    
    if (!enabled) {
      [pcfios release];

    }
}
