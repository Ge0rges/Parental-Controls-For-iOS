// FRAMEWORKS
#import <Preferences/PSListController.h>
#import <Preferences/PSSpecifier.h>
#import <Preferences/PSTextFieldSpecifier.h>
#import <Preferences/PSSliderTableCell.h>
#import <Preferences/PSEditableTableCell.h>
#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

// DEFINITIONS
#define uniqueDomainString @"com.ge0rges.pcfios"

/* GLOBAL VARIABLES */
static NSString *passcode;
static BOOL enabled;
static NSTimer *timeLeftAVTimer;
static UIAlertView *passcodeAV;
static UIAlertView *timeLeftAV;

@interface NSUserDefaults (UFS_Category)
- (id)objectForKey:(NSString *)key inDomain:(NSString *)domain;
- (void)setObject:(id)value forKey:(NSString *)key inDomain:(NSString *)domain;
@end

@interface ParentalControlsForiOSListController: PSListController <UIAlertViewDelegate>
@end

@interface GKSecureEditTextCell : PSEditableTableCell
@end

@interface GKSliderCell : PSSliderTableCell {
  BOOL tagSet;
}

@end

@implementation ParentalControlsForiOSListController
// Preferences
- (void)getLatestPreferences {// Fetches the last saved state of the user set preferences: passcode and enabled.
  // Get the passcode of the KeychainItem (security).
  passcode = [[NSUserDefaults standardUserDefaults] objectForKey:@"password" inDomain:uniqueDomainString];

  // Get the enabled state out of the UserDefaults.
  enabled = [[[NSUserDefaults standardUserDefaults] objectForKey:@"enabled" inDomain:uniqueDomainString] boolValue];
}


- (NSArray *)specifiers {// Called when preferences load.
  if (!_specifiers) {
    _specifiers = [[self loadSpecifiersFromPlistName:@"PCFiOSPreferences" target:self] retain];
  }

  // Show alertView asking for passcode only if it isn't the first time the user enters the prefs
  [self getLatestPreferences];

  if (passcode.length > 0 && enabled) {
    // Configure the passcodeAV
    passcodeAV = [[UIAlertView alloc] initWithTitle:@"Please Enter your Parent-Pass to access the Parental Controls" message:nil delegate:self cancelButtonTitle:@"Cancel" otherButtonTitles:@"Authenticate", @"Time Left", nil];

    passcodeAV.alertViewStyle = UIAlertViewStyleSecureTextInput;
    [passcodeAV textFieldAtIndex:0].keyboardType = UIKeyboardTypeNumberPad;

    [passcodeAV show];
  }

  return _specifiers;
}

- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex {
  if (buttonIndex == alertView.cancelButtonIndex) {// If user canceled the action
    if (alertView.tag == 4) NSAssert(alertView.tag != 4, @"Closing settings");// We should close settings

    // Warn user that settings will close
    UIAlertView *av = [[UIAlertView alloc] initWithTitle:@"Closing setting" message:nil delegate:self cancelButtonTitle:@"OK" otherButtonTitles:nil, nil];
    av.tag = 4;

    [av show];

    if (alertView == timeLeftAV) {
      [timeLeftAVTimer invalidate];
      timeLeftAVTimer = nil;
      [timeLeftAVTimer release];
    }

  } else if (buttonIndex == 1){// User pressed authenticate button
    if ([[alertView textFieldAtIndex:0].text isEqualToString:passcode]) {// Check the passcode
      // Dismiss the alertView
      [alertView dismissWithClickedButtonIndex:buttonIndex animated:YES];

    } else {// Incorrect passcode
      // Dismiss and reshow the alertView with an empty textfield
      dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{[passcodeAV show];});
    }
  } else {
    // Show the time left alert view, start by gettingt he time left string
    int totalSeconds = [[[NSUserDefaults standardUserDefaults] objectForKey:@"savedTimeLeft" inDomain:uniqueDomainString] intValue];
    int seconds = 0;
    int minutes = 0;
    int hours = 0;

    if (totalSeconds > 0) {
      seconds = totalSeconds % 60;
      minutes = (totalSeconds / 60) % 60;
      hours = totalSeconds / 3600;
    }

    NSString *messageString = [NSString stringWithFormat:@"%02d:%02d:%02d",hours, minutes, seconds];

    // Create the AV
    timeLeftAV = [[UIAlertView alloc] initWithTitle:@"Time Left for today" message:messageString delegate:self cancelButtonTitle:@"Dismiss" otherButtonTitles:nil, nil];

    // Set the timer to update the displayed timeleft
    timeLeftAVTimer = [NSTimer scheduledTimerWithTimeInterval:1 target:self selector:@selector(updateAV) userInfo:nil repeats:YES];

    // Show the av
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

- (void)openDesignerTwitter {
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

- (void)openWebsite {
  if ([[UIApplication sharedApplication] canOpenURL:[NSURL URLWithString:@"ioc:"]]) {
    [[UIApplication sharedApplication] openURL:[NSURL URLWithString:@"ioc://ge0rges.com"]];

  } else {
    [[UIApplication sharedApplication] openURL:[NSURL URLWithString:@"https://ge0rges.com"]];
  }
}

- (void)updateAV {
  int totalSeconds = [[[NSUserDefaults standardUserDefaults] objectForKey:@"savedTimeLeft" inDomain:uniqueDomainString] intValue];
  int seconds = 0;
  int minutes = 0;
  int hours = 0;

  if (totalSeconds > 0) {
    seconds = totalSeconds % 60;
    minutes = (totalSeconds / 60) % 60;
    hours = totalSeconds / 3600;
  }

  NSString *messageString = [NSString stringWithFormat:@"%02d:%02d:%02d",hours, minutes, seconds];

  [timeLeftAV setMessage:messageString];
}

@end

@implementation GKSliderCell

- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)identifier specifier:(PSSpecifier *)spec {
  self = [super initWithStyle:style reuseIdentifier:identifier specifier:spec];
  UISlider *slider = (UISlider *)[self control];

  if (self) {
    //set the sliders track color to purple
    [slider setMinimumTrackTintColor:[UIColor purpleColor]];
    [slider addTarget:self action:@selector(roundSlider:) forControlEvents:UIControlEventValueChanged];

    // Set tags to identify the weekday and weekend sliders
    // Custom slider value logic (since it shows hours and we store seconds)
    if (!tagSet) {
      [(UISlider *)[self control] setTag:1];
      tagSet = YES;

      NSNumber *sliderValueWeekends = [[NSUserDefaults standardUserDefaults] objectForKey:@"hoursWeekends" inDomain:uniqueDomainString];
      [slider setValue:([sliderValueWeekends floatValue]/3600) animated:YES];

      [sliderValueWeekends release];

    } else {
      NSNumber *sliderValueWeekdays = [[NSUserDefaults standardUserDefaults] objectForKey:@"hoursWeekdays" inDomain:uniqueDomainString];
      [slider setValue:([sliderValueWeekdays floatValue]/3600) animated:YES];

      [sliderValueWeekdays release];
    }
  }

  [slider release];

  return self;
}

- (void)roundSlider:(UISlider *)slider {
  // Round the slider to 0.5 intervals
  float sliderValue = roundf(slider.value * 2.0) * 0.5;
  [slider setValue:sliderValue animated:YES];

  //write this value to the plist
  if (slider.tag == 1) {// Check which slider it is
    // Weekday slider
    [[NSUserDefaults standardUserDefaults] setObject:[NSNumber numberWithFloat:(sliderValue*3600)] forKey:@"hoursWeekdays" inDomain:uniqueDomainString];

  } else {
    // Weekend slider
    [[NSUserDefaults standardUserDefaults] setObject:[NSNumber numberWithFloat:(sliderValue*3600)] forKey:@"hoursWeekends" inDomain:uniqueDomainString];
  }
}

@end

@implementation GKSecureEditTextCell
- (void)layoutSubviews {
  [super layoutSubviews];

  // Numbers only keyboard.
  ((UITextField *)[self textField]).keyboardType = UIKeyboardTypeNumberPad;

  // add a gesture recognizer to the superview so user can dismiss keyboard by tapping above it
  UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(dismissKeyboard)];
  [tap setCancelsTouchesInView:NO];

  [(UIView *)self.superview.superview addGestureRecognizer:tap];

  [tap release];

  // Set the keyboard text to the password if there is one
  if (passcode.length > 0) {
    ((UITextField *)[self textField]).text = passcode;
  }
}

- (void)textFieldDidEndEditing:(UITextField *)textField {
  // Save the text to the keychain
  passcode = textField.text;
  [[NSUserDefaults standardUserDefaults] setObject:passcode forKey:@"password" inDomain:uniqueDomainString];
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField {
  [self dismissKeyboard];
  return YES;
}

-(void)dismissKeyboard {
  [(UITextField *)[self textField] resignFirstResponder];
}

@end
