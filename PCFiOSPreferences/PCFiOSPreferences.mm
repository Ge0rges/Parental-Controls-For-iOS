#import <Preferences/PSListController.h>
#import <Preferences/PSSpecifier.h>
#import <Preferences/PSTextFieldSpecifier.h>
#import <Preferences/PSSliderTableCell.h>
#import <Preferences/PSEditableTableCell.h>

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import "KeychainItemWrapper.h"

#define domainString "com.ge0rges.pcfios"

@interface NSUserDefaults (UFS_Category)
- (id)objectForKey:(NSString *)key inDomain:(NSString *)domain;
- (void)setObject:(id)value forKey:(NSString *)key inDomain:(NSString *)domain;
@end

@interface ParentalControlsForiOSListController: PSListController <UIAlertViewDelegate>
@end

static NSString *passcode;
static BOOL enabled;
static NSTimer *timeLeftAVTimer;
static UIAlertView *passcodeAV;
static UIAlertView *timeLeftAV;

@implementation ParentalControlsForiOSListController
- (void)getLatestPreferences {
    //set our prefs variables
    KeychainItemWrapper *keychainItem = [[KeychainItemWrapper alloc] initWithIdentifier:@"com.ge0rges.pcfios" accessGroup:nil];
    
    passcode = [keychainItem objectForKey:(id)kSecValueData];
    [passcode retain];
    [keychainItem release];
    
    enabled = [[[NSUserDefaults standardUserDefaults] objectForKey:@"enabled" inDomain:@domainString] boolValue];
}


- (id)specifiers {
	if(_specifiers == nil) {
		_specifiers = [[self loadSpecifiersFromPlistName:@"PCFiOSPreferences" target:self] retain];
	}
    
    //show alertView asking for passcode only if it isn't the first time the user enters the prefs
    //get the passcode
    [self getLatestPreferences];

    if (![passcode isEqualToString:@""] && enabled) {
        //configure the passcodeAV
        passcodeAV = [[UIAlertView alloc] initWithTitle:@"Please Enter your Parent-Pass to access the Parental Controls" message:nil delegate:self cancelButtonTitle:@"Cancel" otherButtonTitles:@"Authenticate", @"Time Left", nil];

        passcodeAV.alertViewStyle = UIAlertViewStyleSecureTextInput;
        [passcodeAV textFieldAtIndex:0].keyboardType = UIKeyboardTypeNumberPad;

        [passcodeAV show];

    }

	return _specifiers;
}

- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex {
    if (buttonIndex == alertView.cancelButtonIndex) {//if user canceled the action
        if (alertView.tag == 4) NSAssert(alertView.tag != 4, @"Closing settings");// we should close settings
            
        //warn user that settings will close
        UIAlertView *av = [[UIAlertView alloc] initWithTitle:@"Closing setting" message:nil delegate:self cancelButtonTitle:@"OK" otherButtonTitles:nil, nil];
        av.tag = 4;
        
        [av show];
        
        if (alertView == timeLeftAV) {
            [timeLeftAVTimer invalidate];
            timeLeftAVTimer = nil;
            [timeLeftAVTimer release];
        }
        
    } else if (buttonIndex == 1){//user pressed authenticate button
        if ([[alertView textFieldAtIndex:0].text isEqualToString:passcode]) {//check the passcode
            //dismiss the alertView
            [alertView dismissWithClickedButtonIndex:buttonIndex animated:YES];

        } else {//incorrect passcode
            //dismiss and reshow the alertView with an empty textfield
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{[passcodeAV show];});
        }
    } else {
        //show the time left alert view, start by gettingt he time left string
        int totalSeconds = [[[NSUserDefaults standardUserDefaults] objectForKey:@"savedTimeLeft" inDomain:@domainString] intValue];
        int seconds = totalSeconds % 60;
        int minutes = (totalSeconds / 60) % 60;
        int hours = totalSeconds / 3600;
        
        NSString *messageString = [NSString stringWithFormat:@"%02d:%02d:%02d",hours, minutes, seconds];
        
        //create the AV
        timeLeftAV = [[UIAlertView alloc] initWithTitle:@"Time Left for today" message:messageString delegate:self cancelButtonTitle:@"Dismiss" otherButtonTitles:nil, nil];
        
        //set the timer to update the displayed timeleft
        timeLeftAVTimer = [NSTimer scheduledTimerWithTimeInterval:1 target:self selector:@selector(updateAV) userInfo:nil repeats:YES];
        
        //show the av
        [timeLeftAV show];
    }
}

- (void)openTwitter {
    NSString *user = @"Ge0rges13";
    
    if ([[UIApplication sharedApplication] canOpenURL:[NSURL URLWithString:@"tweetbot:"]])
        [[UIApplication sharedApplication] openURL:[NSURL URLWithString:[@"tweetbot:///user_profile/" stringByAppendingString:user]]];
    else if ([[UIApplication sharedApplication] canOpenURL:[NSURL URLWithString:@"twitterrific:"]])
        [[UIApplication sharedApplication] openURL:[NSURL URLWithString:[@"twitterrific:///profile?screen_name=" stringByAppendingString:user]]];
    else if ([[UIApplication sharedApplication] canOpenURL:[NSURL URLWithString:@"tweetings:"]])
        [[UIApplication sharedApplication] openURL:[NSURL URLWithString:[@"tweetings:///user?screen_name=" stringByAppendingString:user]]];
    else if ([[UIApplication sharedApplication] canOpenURL:[NSURL URLWithString:@"twitter:"]])
        [[UIApplication sharedApplication] openURL:[NSURL URLWithString:[@"twitter://user?screen_name=" stringByAppendingString:user]]];
    else
        [[UIApplication sharedApplication] openURL:[NSURL URLWithString:[@"https://mobile.twitter.com/" stringByAppendingString:user]]];
}

-(void)openDesignerTwitter {
    NSString *user = @"A_RTX";
    if ([[UIApplication sharedApplication] canOpenURL:[NSURL URLWithString:@"tweetbot:"]])
        [[UIApplication sharedApplication] openURL:[NSURL URLWithString:[@"tweetbot:///user_profile/" stringByAppendingString:user]]];
    else if ([[UIApplication sharedApplication] canOpenURL:[NSURL URLWithString:@"twitterrific:"]])
        [[UIApplication sharedApplication] openURL:[NSURL URLWithString:[@"twitterrific:///profile?screen_name=" stringByAppendingString:user]]];
    else if ([[UIApplication sharedApplication] canOpenURL:[NSURL URLWithString:@"tweetings:"]])
        [[UIApplication sharedApplication] openURL:[NSURL URLWithString:[@"tweetings:///user?screen_name=" stringByAppendingString:user]]];
    else if ([[UIApplication sharedApplication] canOpenURL:[NSURL URLWithString:@"twitter:"]])
        [[UIApplication sharedApplication] openURL:[NSURL URLWithString:[@"twitter://user?screen_name=" stringByAppendingString:user]]];
    else
        [[UIApplication sharedApplication] openURL:[NSURL URLWithString:[@"https://mobile.twitter.com/" stringByAppendingString:user]]];
}

- (void)sendEmail {
    [[UIApplication sharedApplication] openURL:[NSURL URLWithString:@"mailto:ge0rges@ge0rges.com?subject=Parental%20Controls%20For%20iOS"]];
}

- (void)sendEmailFeature {
    [[UIApplication sharedApplication] openURL:[NSURL URLWithString:@"mailto:ge0rges@ge0rges.com?subject=Parental%20Controls%20For%20iOS%20%2D%20Feature%20Request"]];
}

-(void)openWebsite {
    if ([[UIApplication sharedApplication] canOpenURL:[NSURL URLWithString:@"ioc:"]])
        [[UIApplication sharedApplication] openURL:[NSURL URLWithString:@"ioc://ge0rges.com"]];
    else
        [[UIApplication sharedApplication] openURL:[NSURL URLWithString:@"http://ge0rges.com"]];
}

-(void)updateAV {
    int totalSeconds = [[[NSUserDefaults standardUserDefaults] objectForKey:@"savedTimeLeft" inDomain:@domainString] intValue];
    int seconds = totalSeconds % 60;
    int minutes = (totalSeconds / 60) % 60;
    int hours = totalSeconds / 3600;
    
    NSString *messageString = [NSString stringWithFormat:@"%02d:%02d:%02d",hours, minutes, seconds];
    
    [timeLeftAV setMessage:messageString];
}

@end

@interface GKSliderCell : PSSliderTableCell {
    BOOL tagSet;
}

@end

@implementation GKSliderCell

-(id)initWithStyle:(int)style reuseIdentifier:(NSString *)identifier specifier:(PSSpecifier *)spec {
    self = [super initWithStyle:style reuseIdentifier:identifier specifier:spec];
    
    if (self) {
        //set the sliders track color to purple
        [(UISlider *)[self control] setMinimumTrackTintColor:[UIColor purpleColor]];
        [(UISlider *)[self control] addTarget:self action:@selector(roundSlider:) forControlEvents:UIControlEventValueChanged];
        
        //set tags to identify the weekday and weekend sliders
        if (!tagSet) {
            [(UISlider *)[self control] setTag:1];
            tagSet = YES;
        }
    }
    
    return self;
}

-(void)roundSlider:(UISlider *)slider {
    //round the slider to 0.5 intervals
    float sliderValue = roundf(slider.value * 2.0) * 0.5;
    [slider setValue:sliderValue animated:YES];
    
    //write this value to the plist
    if (slider.tag == 1) {//check which slider it is
        //weekday slider
        [[NSUserDefaults standardUserDefaults] setObject:[NSNumber numberWithFloat:sliderValue] forKey:@"hoursWeekdays" inDomain:@"com.ge0rges.pcfios"];
    } else {
        //weekend slider
        [[NSUserDefaults standardUserDefaults] setObject:[NSNumber numberWithFloat:sliderValue] forKey:@"hoursWeekends" inDomain:@"com.ge0rges.pcfios"];

    }
}

@end

@interface GKSecureEditTextCell : PSEditableTableCell
@end

@implementation GKSecureEditTextCell
-(void)layoutSubviews {
    [super layoutSubviews];
    
    //make the keyboard be only numbers
    ((UITextField *)[self textField]).keyboardType = UIKeyboardTypeNumberPad;
    
    //add a gesture recognizer to the superview so user can dismiss keyboard by tapping above it
    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(dismissKeyboard)];
    [tap setCancelsTouchesInView:NO];
    
    [(UIView *)self.superview.superview addGestureRecognizer:tap];
    
    [tap release];
    
    //set the keyboard text to the password if there is one
    KeychainItemWrapper *keychainItem = [[KeychainItemWrapper alloc] initWithIdentifier:@"com.ge0rges.pcfios" accessGroup:nil];
    NSString *password = [keychainItem objectForKey:(id)kSecValueData];
    
    if (password.length > 0) {
        ((UITextField *)[self textField]).text = password;
    }
    
    [keychainItem release];
}

-(void)textFieldDidEndEditing:(UITextField *)textField {
    //save the text to the keychain
    KeychainItemWrapper *keychainItem = [[KeychainItemWrapper alloc] initWithIdentifier:@"com.ge0rges.pcfios" accessGroup:nil];
    
    [keychainItem setObject:textField.text forKey:(id)kSecValueData];
    
    [keychainItem release];
}

-(BOOL)textFieldShouldReturn:(UITextField *)textField {
    [self dismissKeyboard];
    
    return YES;
}

-(void)dismissKeyboard {
    [(UITextField *)[self textField] resignFirstResponder];
}

@end
