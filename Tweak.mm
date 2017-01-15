#include <CoreFoundation/CFNotificationCenter.h>
#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <SpringBoard/Springboard.h>
#import <GraphicsServices/GraphicsServices.h>
#import "KeychainItemWrapper.h"

#define kCFCoreFoundationVersionNumber_iOS_7_0 847.20
#define domainString "com.ge0rges.pcfios"
#define notificationString "com.gnos.pcfios.preferences.changed"

typedef enum {
    SBIconLocationHomeScreen = 0,
    SBIconLocationDock       = 1,
    SBIconLocationSwitcher   = 2
} SBIconLocation;

@interface NSUserDefaults (UFS_Category)
- (id)objectForKey:(NSString *)key inDomain:(NSString *)domain;
- (void)setObject:(id)value forKey:(NSString *)key inDomain:(NSString *)domain;
@end

@interface SBLockScreenView : UIView <UIScrollViewDelegate>
-(void)setCustomSlideToUnlockText:(id)arg1 animated:(BOOL)arg2;
-(void)setCustomSlideToUnlockText:(id)arg1;//ios 7
-(id)_defaultSlideToUnlockText;
-(void)slideUpGestureDidBegin;
-(id)initWithFrame:(CGRect)arg1;
-(void)scrollViewWillBeginDragging:(id)arg1;
@end
    
@interface SBLockScreenViewControllerBase : UIViewController
- (void)launchEmergencyDialer;
@end

@interface SBLockScreenViewController : SBLockScreenViewControllerBase
@end

@interface SBLockScreenManager : NSObject
@property (nonatomic,readonly) SBLockScreenViewControllerBase *lockScreenViewController;

+(id)sharedInstance;
-(void)_bioAuthenticated:(id)arg1;
@end


#define SBLSM ((SBLockScreenManager*)[%c(SBLockScreenManager) sharedInstance])

static SBApplicationIcon *appIcon = nil;
static SBIconLocation appLocation = SBIconLocationHomeScreen;

static NSString *passcode = @"";

static BOOL enabled;
static BOOL dontDismissAV = NO;
static BOOL wasRecentlyLocked;
static BOOL isLocked = YES;
static BOOL canLaunchCydia = NO;
static BOOL canShowTimeLimitAV = YES;

static NSDate *lastNewDay = nil;

static SBLockScreenView *sbLockScreenView = nil;

static int timeLeft;

static NSTimer *timeAllowedTimer;
static NSTimer *timeLeftTimer;

static void lockStateChanged(CFNotificationCenterRef center, void *observer, CFStringRef name, const void *object, CFDictionaryRef userInfo);
static void settingsChangedNotificationCallback(CFNotificationCenterRef center, void *observer, CFStringRef name, const void *object, CFDictionaryRef userInfo);
static void startTimers(int allowedtime);
static void stopTimers();
static void setupNewDay();

static UIAlertView *passcodeAV;


@interface PCFiOS : NSObject
- (void)setPreferences;
- (void)timerDone;
- (void)updateTimeLeft;
- (void)timeChange;
@end

static PCFiOS *pcfios;

@implementation PCFiOS
//preferences
- (void)setPreferences {
    //set our prefs variables
    KeychainItemWrapper *keychainItem = [[KeychainItemWrapper alloc] initWithIdentifier:@"com.ge0rges.pcfios" accessGroup:nil];

    passcode = [keychainItem objectForKey:(id)kSecValueData];
    [passcode retain];
    [keychainItem release];
    
    NSLog(@"_____________ set passcode to: [%@]", passcode);

    enabled = [[[NSUserDefaults standardUserDefaults] objectForKey:@"enabled" inDomain:@domainString] boolValue];
}

//time limit handling
- (void)timerDone {
    //stop the timers
    stopTimers();

    //take one out of timeLeft because of delay
    timeLeft = 0;
    
    //update the saved variables
    [[NSUserDefaults standardUserDefaults] setObject:[NSNumber numberWithInt:timeLeft] forKey:@"savedTimeLeft" inDomain:@domainString];
    [[NSUserDefaults standardUserDefaults] synchronize];
    
    //lock the device. Thanks to L4ys for open sourcing this code at: https://github.com/L4ys/SpotLock
    SpringBoard *sb = (SpringBoard*)[UIApplication sharedApplication];
    __GSEvent* event = NULL;
    struct GSEventRecord record;
    memset(&record, 0, sizeof(record));
    
    record.timestamp = GSCurrentEventTimestamp();
    record.type = kGSEventLockButtonDown;
    
    if (kCFCoreFoundationVersionNumber >= kCFCoreFoundationVersionNumber_iOS_7_0 ) {
        event = GSEventCreateWithEventRecord(&record);
        [sb lockButtonDown:event];
        CFRelease(event);
    }
    
    record.type = kGSEventLockButtonUp;
    
    if (kCFCoreFoundationVersionNumber >= kCFCoreFoundationVersionNumber_iOS_7_0 ) {
        event = GSEventCreateWithEventRecord(&record);
        [sb lockButtonUp:event];
        CFRelease(event);
    }
}

- (void)updateTimeLeft {
    //substract a second from the timeLeft
    timeLeft -= 1;
    
    //update the saved variables
    [[NSUserDefaults standardUserDefaults] setObject:[NSNumber numberWithInt:timeLeft] forKey:@"savedTimeLeft" inDomain:@domainString];
    [[NSUserDefaults standardUserDefaults] synchronize];
    
    //check if the hour in day limit has passed
    float limitHour = ([[[NSCalendar currentCalendar] components: NSWeekdayCalendarUnit fromDate:[NSDate date]] weekday] > 2) ? [[[NSUserDefaults standardUserDefaults] objectForKey:@"hourInDayStopWeekdays" inDomain:@domainString] floatValue] : [[[NSUserDefaults standardUserDefaults] objectForKey:@"hourInDayStopWeekends" inDomain:@domainString] floatValue];
    
    //get int of hour
    NSCalendar *gregorianCal = [[[NSCalendar alloc] initWithCalendarIdentifier:NSGregorianCalendar] autorelease];
    NSDateComponents *dateComps = [gregorianCal components:(NSHourCalendarUnit | NSMinuteCalendarUnit) fromDate:[NSDate date]];
    float currentHour = (int)[dateComps hour] + (float)([dateComps minute]/60);
    
    if (currentHour >= limitHour) [self timerDone];
}

- (void)timeChange {
    setupNewDay();
}

@end

@interface UIAlertViewDelegateClass : NSObject <UIAlertViewDelegate>
@end

static UIAlertViewDelegateClass *avdc;

@implementation UIAlertViewDelegateClass

- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex {
    [pcfios setPreferences];
    
    if (alertView == passcodeAV) {
        if (buttonIndex == alertView.cancelButtonIndex) {//if user canceled the action
            //dismiss the alertView and go back to the main prefs
            [alertView dismissWithClickedButtonIndex:buttonIndex animated:YES];
            
        } else {//user pressed validate button
            if ([[alertView textFieldAtIndex:0].text isEqualToString:passcode]) {//check the passcode
                if (alertView.tag == 2) {//check if we used the alertView for authenticating adding time
                    //remove the tag of the alertView
                    alertView.tag = 0;
                    
                    //add one hour to timeLeft
                    timeLeft = 3600;
                    
                    //show an alertView confirming
                    [[[UIAlertView alloc] initWithTitle:@"Parental Controls" message:@"Your time limit has been extended by one hour today." delegate:nil cancelButtonTitle:@"Ok" otherButtonTitles:nil, nil] show];
                    
                    //update the saved variables
                    [[NSUserDefaults standardUserDefaults] setObject:[NSNumber numberWithInt:timeLeft] forKey:@"savedTimeLeft" inDomain:@domainString];
                    [[NSUserDefaults standardUserDefaults] synchronize];
                    
                } else {
                    //correct passcode dismiss the alertView and launch cydia
                    [alertView dismissWithClickedButtonIndex:buttonIndex animated:YES];
                    
                    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                        //this will allow our hooks to launch Cydia
                        canLaunchCydia = YES;
                        
                        //launch Cydia
                        if (kCFCoreFoundationVersionNumber >= kCFCoreFoundationVersionNumber_iOS_7_0) {
                            [appIcon launchFromLocation:appLocation];
                        }
                        
                        //not allowed to launch cydia anymore
                        canLaunchCydia = NO;
                    });
                }
                
            } else {//incorrect passcode
                //dismiss and reshow the alertView with an empty textfield
                dontDismissAV = YES;
            }
        }
        
        //clear the textfield
        [alertView textFieldAtIndex:0].text = @"";
        
    } else {//otherwise its the unlocking alert view
        if (buttonIndex == 2) {
            //user clicked emergency call
            [SBLSM.lockScreenViewController launchEmergencyDialer];
            
        } else if (buttonIndex == 1){
            //ask for passcode before adding one hour to timeLeft
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.7 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{//we do it after .5 seconds because otherwise it dismisses for some reason
                passcodeAV.tag = 2;
                [passcodeAV show];
                
            });
        }
        
        canShowTimeLimitAV = YES;
    }
}

- (void)alertView:(UIAlertView *)alertView didDismissWithButtonIndex:(NSInteger)buttonIndex {
    if (dontDismissAV && alertView == passcodeAV) {//if we have to represent the alert view
        //reset the bool
        dontDismissAV = NO;
        
        //show the alertView in 0.3 seconds after animation is completely done on the main queue
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{[passcodeAV show];});
    }
}

@end

static void lockStateChanged(CFNotificationCenterRef center, void *observer, CFStringRef name, const void *object, CFDictionaryRef userInfo) {
    
    //the "com.apple.springboard.lockcomplete" notification will always come after the "com.apple.springboard.lockstate" notification
    NSString *lockState = (NSString*)name;
    [pcfios setPreferences];
    
    if([lockState isEqualToString:@"com.apple.springboard.lockcomplete"]) {//locked
        //set our bool to YES then back to NO se we don't confuse the lockstate notification for a unlock
        wasRecentlyLocked = YES;
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{wasRecentlyLocked = NO;});
        
        //stop the timers
        stopTimers();
        
        //change bool
        isLocked = YES;
        
    } else if (!wasRecentlyLocked && timeLeft > 0 && enabled) {//make sure this wasn't a locked status change unlocked
        //start the timers again
        startTimers(timeLeft);
        
        //change bool
        isLocked = NO;
        
    } else if (timeLeft <= 0) {
        //device should be in no time left
        [pcfios timerDone];
    }
}

static void startTimers (int allowedTime) {
    //create a new timer
    timeAllowedTimer = [[NSTimer scheduledTimerWithTimeInterval:allowedTime target:pcfios selector:@selector(timerDone) userInfo:nil repeats:NO] retain];
    
    timeLeftTimer = [[NSTimer scheduledTimerWithTimeInterval:1.0 target:pcfios selector:@selector(updateTimeLeft) userInfo:nil repeats:YES] retain];
    
}

static void stopTimers () {
    if (timeLeftTimer && timeAllowedTimer) {
        //stop the timers
        [timeLeftTimer invalidate];
        [timeAllowedTimer invalidate];
        
        //nil variables out
        timeLeftTimer = nil;
        timeAllowedTimer = nil;
        
        //release the timers
        [timeLeftTimer release];
        [timeAllowedTimer release];
    }
}

static void setupNewDay() {

    BOOL newDay = YES;
    lastNewDay = [[NSUserDefaults standardUserDefaults] objectForKey:@"savedDay" inDomain:@domainString];
    
    if (lastNewDay) {//if we don't have  a lastNewDay date then that means first launch and newDay should be YES
        
        //check if this is truly a new day
        NSCalendar* calendar = [NSCalendar currentCalendar];
        
        unsigned unitFlags = NSYearCalendarUnit | NSMonthCalendarUnit |  NSDayCalendarUnit;
        NSDateComponents* comp1 = [calendar components:unitFlags fromDate:[NSDate date]];
        NSDateComponents* comp2 = [calendar components:unitFlags fromDate:lastNewDay];
        
        newDay = [comp1 day] != [comp2 day];
    }
    
    if (newDay) {
        
        //refresh our prefs
        [pcfios setPreferences];
        
        //set the lastNewDay variable to this date
        lastNewDay = [NSDate date];
        
        //setup the timer for today
        //first get the date
        NSCalendar *gregorian = [[[NSCalendar alloc] initWithCalendarIdentifier:NSGregorianCalendar] autorelease];
        NSDateComponents *comps = [gregorian components:NSWeekdayCalendarUnit fromDate:lastNewDay];
        int dayInt = [comps weekday];
        
        //next get the allowed time in hours
        //dayInt is: Sat = 1, Sun = 2...
        float allowedTimeHours = (dayInt > 2) ? [[[NSUserDefaults standardUserDefaults] objectForKey:@"hoursWeekdays" inDomain:@domainString] floatValue] : [[[NSUserDefaults standardUserDefaults] objectForKey:@"hoursWeekends" inDomain:@domainString] floatValue];
        
        //convert that time into seconds
        float allowedTimeSeconds = allowedTimeHours * 3600;
        timeLeft = allowedTimeSeconds;
        
        //update the saved variables
        [[NSUserDefaults standardUserDefaults] setObject:[NSNumber numberWithInt:timeLeft] forKey:@"savedTimeLeft" inDomain:@domainString];
        [[NSUserDefaults standardUserDefaults] setObject:lastNewDay forKey:@"savedDay" inDomain:@domainString];
        [[NSUserDefaults standardUserDefaults] synchronize];
        
        //restart the timers with that amount of second
        stopTimers();
        
        if (!isLocked) startTimers(allowedTimeSeconds);//only start the timer if device is unlocked

    } else if (timeLeft > 0 && !timeLeftTimer && !timeAllowedTimer) {//if we are in the same day and still have time and the timers are stopped otherwise nothing is to change
        //start the timers
        if (!isLocked) startTimers(timeLeft);//only start the timer if device is unlocked
        
        //save the savedDay
        lastNewDay = [NSDate date];
        
        [[NSUserDefaults standardUserDefaults] setObject:lastNewDay forKey:@"savedDay" inDomain:@domainString];
        [[NSUserDefaults standardUserDefaults] synchronize];
    }
}


static void settingsChangedNotificationCallback(CFNotificationCenterRef center, void *observer, CFStringRef name, const void *object, CFDictionaryRef userInfo) {
    //refresh the prefs
    [pcfios setPreferences];
    
    //check if tweak enabled
    if (enabled) {
        //set the lastNewDay variable to this date
        lastNewDay = [NSDate date];
        
        //setup the timer for today
        //first get the date
        int dayInt = [[[NSCalendar currentCalendar] components: NSWeekdayCalendarUnit fromDate:lastNewDay] weekday];
        
        //next get the allowed time in hours
        //dayInt is: Sat = 1, Sun = 2...
        float allowedTimeHours = (dayInt > 2) ? [[[NSUserDefaults standardUserDefaults] objectForKey:@"hoursWeekdays" inDomain:@domainString] floatValue] : [[[NSUserDefaults standardUserDefaults] objectForKey:@"hoursWeekends" inDomain:@domainString] floatValue];
        
        //convert that time into seconds
        int allowedTimeSeconds = allowedTimeHours * 3600;
        timeLeft = allowedTimeSeconds;
        
        //update the saved variables
        [[NSUserDefaults standardUserDefaults] setObject:[NSNumber numberWithInt:timeLeft] forKey:@"savedTimeLeft" inDomain:@domainString];
        [[NSUserDefaults standardUserDefaults] setObject:lastNewDay forKey:@"savedDay" inDomain:@domainString];
        [[NSUserDefaults standardUserDefaults] synchronize];
        
        //restart the timers with that amount of second
        stopTimers();
        if (!isLocked) startTimers(allowedTimeSeconds);//only start the timer if device is unlocked
        
    } else {
        stopTimers();
    }
}


%ctor {
    //create a instance of our main class
    pcfios = [PCFiOS new];
    [pcfios retain];
    
    //update the prefs
    [pcfios setPreferences];
    
    if (enabled) {//check if the tweak is enabled
        //register to get lock state updates
        CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(), //center
                                        NULL, // observer
                                        lockStateChanged, // callback
                                        CFSTR("com.apple.springboard.lockstate"), // event name
                                        NULL, // object
                                        CFNotificationSuspensionBehaviorDeliverImmediately);
        
        CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(), //center
                                        NULL, // observer
                                        lockStateChanged, // callback
                                        CFSTR("com.apple.springboard.lockcomplete"), // event name
                                        NULL, // object
                                        CFNotificationSuspensionBehaviorDeliverImmediately);
        
        //set a notification for detecting a new day and resettinga llowedTime
        [[NSNotificationCenter defaultCenter] addObserver:pcfios selector:@selector(timeChange) name:UIApplicationSignificantTimeChangeNotification object:nil];
        
        //assign our instances
        avdc = [UIAlertViewDelegateClass new];
        
        //assign the alertView AV
        passcodeAV = [[UIAlertView alloc] initWithTitle:@"Please Enter your Parent-Pass to authenticate this action" message:nil delegate:avdc cancelButtonTitle:@"Cancel" otherButtonTitles:@"Authenticate", nil];
        
        passcodeAV.alertViewStyle = UIAlertViewStyleSecureTextInput;
        [passcodeAV textFieldAtIndex:0].keyboardType = UIKeyboardTypeNumberPad;
        
        //check if there is still some timeLeft for this day
        NSDate *savedDay = [[NSUserDefaults standardUserDefaults] objectForKey:@"savedDay" inDomain:@domainString];
        int savedTimeLeft = [[[NSUserDefaults standardUserDefaults] objectForKey:@"savedTimeLeft" inDomain:@domainString] intValue];
        
        if (savedDay && savedTimeLeft) {
            
            NSCalendar* calendar = [NSCalendar currentCalendar];
            
            unsigned unitFlags = NSYearCalendarUnit | NSMonthCalendarUnit |  NSDayCalendarUnit;
            NSDateComponents* comp1 = [calendar components:unitFlags fromDate:[NSDate date]];
            NSDateComponents* comp2 = [calendar components:unitFlags fromDate:savedDay];
            
            BOOL newDay = [comp1 day] != [comp2 day];
            
            if (savedTimeLeft > 0 && !newDay) {
                //update the timeLeft
                timeLeft = savedTimeLeft;
                
                //we shouldn't restart the timers
                if (!timeLeftTimer && !timeAllowedTimer) stopTimers(); //make sure we don't have double timers
                
                if (!isLocked) startTimers(savedTimeLeft);//only start the timer if device is unlocked
                lastNewDay = [NSDate date];
                
                //update the saved variables
                [[NSUserDefaults standardUserDefaults] setObject:lastNewDay forKey:@"savedDay" inDomain:@domainString];
                [[NSUserDefaults standardUserDefaults] synchronize];
                
                return;
            }
        }
        
        //setup a new day (today)
        setupNewDay();
        
        
    } else {
        //free memory
        [pcfios release];
    }
    
    //register for notifications
    CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(), NULL, settingsChangedNotificationCallback, (CFStringRef)@notificationString, NULL, CFNotificationSuspensionBehaviorCoalesce);
    
}

//hook SBApplicationIcon to prevent unauthorized launch of Cydia
%hook SBApplicationIcon

- (void)launchFromLocation:(SBIconLocation)location {
    //update the prefs
    [pcfios setPreferences];
    
    //if the user is not launching cydia or the tweak is disabled or the passcode has not been set
    if (![[self applicationBundleID] isEqualToString:@"com.saurik.Cydia"] || [passcode isEqualToString:@""] || !enabled || canLaunchCydia) {
        %orig();//default implementation
    } else if (!canLaunchCydia && enabled) {
        //set the appIcon and appLocation so we can launch the app later
        appIcon = self;
        appLocation = location;
        
        //ask for the passcode otherwise
        [passcodeAV show];
    }
}

%end

//hook SBLockScreenView and SBLockScreenManager to prevent user from accessing device after time limit and to update the slide to unlock text when the device is disabled
%hook SBLockScreenView
-(id)initWithFrame:(CGRect)arg1 {
    sbLockScreenView = %orig();
    return sbLockScreenView;
}

-(void)slideUpGestureDidBegin {
    [pcfios setPreferences];
    
    //set slide to unlock text
    if ([[[UIDevice currentDevice] systemVersion] floatValue] >= 8.0)
        [sbLockScreenView setCustomSlideToUnlockText:[sbLockScreenView _defaultSlideToUnlockText] animated:YES];
    else
        [sbLockScreenView setCustomSlideToUnlockText:[sbLockScreenView _defaultSlideToUnlockText]];
    
    if (timeLeft <= 0 && enabled && canShowTimeLimitAV && ![passcode isEqualToString:@""]) {
        //make sure we don't get more than one alertView
        canShowTimeLimitAV = NO;
        
        //explain to the user what happened
        if ([[UIApplication sharedApplication] canOpenURL:[NSURL URLWithString:@"tel://"]]) {
            [[[UIAlertView alloc] initWithTitle:@"Parental Controls" message:@"Your time limit has been reached. Check back tomorrow for more time!" delegate:avdc cancelButtonTitle:@"Ok" otherButtonTitles:@"Add One Hour", @"Emergency Call", nil] show];
        } else {
            [[[UIAlertView alloc] initWithTitle:@"Parental Controls" message:@"Your time limit has been reached. Check back tomorrow for more time!" delegate:avdc cancelButtonTitle:@"Ok" otherButtonTitles:@"Add One Hour", nil] show];
        }
    }
    
    return %orig();
}

-(void)scrollViewWillBeginDragging:(id)arg1 {
    [pcfios setPreferences];
    
    //set slide to unlock text
    if ([[[UIDevice currentDevice] systemVersion] floatValue] >= 8.0)
        [sbLockScreenView setCustomSlideToUnlockText:[sbLockScreenView _defaultSlideToUnlockText] animated:YES];
    else
        [sbLockScreenView setCustomSlideToUnlockText:[sbLockScreenView _defaultSlideToUnlockText]];

    if (timeLeft <= 0 && enabled && canShowTimeLimitAV && ![passcode isEqualToString:@""]) {
        //make sure we don't get more than one alertView
        canShowTimeLimitAV = NO;
        
        //explain to the user what happened
        if ([[UIApplication sharedApplication] canOpenURL:[NSURL URLWithString:@"tel://"]]) {
            [[[UIAlertView alloc] initWithTitle:@"Parental Controls" message:@"Your time limit has been reached. Check back tomorrow for more time!" delegate:avdc cancelButtonTitle:@"Ok" otherButtonTitles:@"Add One Hour", @"Emergency Call", nil] show];
        } else {
            [[[UIAlertView alloc] initWithTitle:@"Parental Controls" message:@"Your time limit has been reached. Check back tomorrow for more time!" delegate:avdc cancelButtonTitle:@"Ok" otherButtonTitles:@"Add One Hour", nil] show];
        }
    }
 
    return %orig();
}

-(void)setCustomSlideToUnlockText:(NSString *)unlockText {
    if(enabled && timeLeft <= 0) {//check if the tweak is enabled and the user has no more time left
        //then put our custom text
        unlockText = @"time limit reached";
    }
    %orig(unlockText);
}

-(void)setCustomSlideToUnlockText:(NSString *)unlockText animated:(BOOL)arg2 {
    if(enabled && timeLeft <= 0) {//check if the tweak is enabled and the user has no more time left
        //then put our custom text
        unlockText = @"time limit reached";
    }
    %orig(unlockText, arg2);
}

-(NSString *)_defaultSlideToUnlockText {
    if(enabled && timeLeft <= 0) //check if the tweak is enabled and the user has no more time left
        //then put our custom text
        return @"time limit reached";
     else
        return %orig();
}

%end

%hook SBLockScreenManager
-(void)_bioAuthenticated:(id)arg1 {
    [pcfios setPreferences];
    if (timeLeft <= 0 && enabled && canShowTimeLimitAV) {
        //make sure we don't get more than one alertView
        canShowTimeLimitAV = NO;
        
        //explain to the user what happened
        if ([[UIApplication sharedApplication] canOpenURL:[NSURL URLWithString:@"tel://"]]) {
            [[[UIAlertView alloc] initWithTitle:@"Parental Controls" message:@"Your time limit has been reached. Check back tomorrow for more time!" delegate:avdc cancelButtonTitle:@"Ok" otherButtonTitles:@"Add One Hour", @"Emergency Call", nil] show];
        } else {
            [[[UIAlertView alloc] initWithTitle:@"Parental Controls" message:@"Your time limit has been reached. Check back tomorrow for more time!" delegate:avdc cancelButtonTitle:@"Ok" otherButtonTitles:@"Add One Hour", nil] show];
        }
    }
    
    return %orig();
}

%end