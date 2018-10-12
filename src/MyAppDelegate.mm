//
//
//

#import "MyAppDelegate.h"
#import "ofApp.h"

static NSString *const AUDIOBUS_API_KEY= @"H4sIAAAAAAAAA03NQQ7CIBAF0LvMuhZrozEcwEuIaWihSqSFDIwpaXp3sWHh9s3/f1bQizeYgB8r6GlWVneznDRwuFlabIIKCG0Xhpfeddz10NRtLUkZ11PgggmWc95hDMDvK8Tkf1lJ+Mxe9krTUcymdBjQ+Gjc/P8qUF+6OXbKMMmZRjlEQo1lI+tHY9ibzfaowKh8EaxgEOytk2Dt5XyF7Qvyo+OM4AAAAA==:vt25hiqENkDuXYKNBZb3bKuPYyguTWdFJMmccJfaVzZWekI2zyOXdGx2BVjMM0pThND6gv54sVy92hhCEJHHA8gXOUhWGiKqhpgxeZoEy5dgy76WCsoYr8VRaYT4SWcF";

@implementation MyAppDelegate 

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    // ofSetLogLevel(OF_LOG_VERBOSE); 
    ofLog(OF_LOG_VERBOSE, "Started App Delegate");
   
    [super applicationDidFinishLaunching:application];

    ofApp *app = new ofApp();
    self.glViewController = [[ofxiOSViewController alloc] initWithFrame:[[UIScreen mainScreen] bounds] app:app ];
    [self.window setRootViewController:self.glViewController];
    ofLog(OF_LOG_VERBOSE, "Set Orientation");
    ofOrientation requested = ofGetOrientation();
    UIInterfaceOrientation interfaceOrientation;
    interfaceOrientation = UIInterfaceOrientationPortrait;
    switch (requested) {
        case OF_ORIENTATION_DEFAULT:
            interfaceOrientation = UIInterfaceOrientationPortrait;
            break;
        case OF_ORIENTATION_180:
            interfaceOrientation = UIInterfaceOrientationPortrait;
            break;
        case OF_ORIENTATION_90_RIGHT:
            interfaceOrientation = UIInterfaceOrientationPortrait;
            break;
        case OF_ORIENTATION_90_LEFT:
            interfaceOrientation = UIInterfaceOrientationPortrait;
            break;
        case OF_ORIENTATION_UNKNOWN:
            interfaceOrientation = UIInterfaceOrientationPortrait;
            break;
    }
    ofLog(OF_LOG_VERBOSE, "Rotate to portrait");
    [self.glViewController rotateToInterfaceOrientation:UIInterfaceOrientationPortrait animated:false];
    ofLog(OF_LOG_VERBOSE, "Set up audio stream");
    app->setupAudioStream();
    SoundOutputStream *stream = app->getSoundStream()->getSoundOutStream();
    /* You need to set the AudioSession settings again, setupSoundStream() I think sets it to AVAudioSessionCategoryPlayAndRecord? In any case, without calling this after setupSoundStream i could not start from within Audiobus without sound issues. */

    [[AVAudioSession sharedInstance] setActive:YES error:NULL];
    AudioOutputUnitStart(stream.audioUnit);
    [[AVAudioSession sharedInstance] setCategory: AVAudioSessionCategoryPlayAndRecord
                                     withOptions: AVAudioSessionCategoryOptionAllowBluetooth|
                                                  AVAudioSessionCategoryOptionMixWithOthers|
                                                  AVAudioSessionCategoryOptionDefaultToSpeaker
                                     error:  NULL];
   
    self.audiobusController = [[ABAudiobusController alloc] initWithApiKey:AUDIOBUS_API_KEY];

    self.audiobusSender = [[ABAudioSenderPort alloc]
                                   initWithName:@"fluxly-out"
                                   title:NSLocalizedString(@"fluxly-out", @"")
                                   audioComponentDescription:(AudioComponentDescription) {
                                        .componentType = kAudioUnitType_RemoteGenerator,
                                        .componentSubType = 'out2', // Note single quotes
                                        //this needs to match the audioComponents entry
                                        .componentManufacturer = 'flux' }
                                   audioUnit:stream.audioUnit];
    [_audiobusController addAudioSenderPort:_audiobusSender];
    
    if (IS_IPHONE) self.audiobusController.connectionPanelPosition = ABConnectionPanelPositionRight;
    if (IS_IPAD) self.audiobusController.connectionPanelPosition = ABConnectionPanelPositionTop;
    ofLog(OF_LOG_VERBOSE, "Finished Audiobus Controller");
    return YES;
    
}

//- (void)applicationDidEnterBackground:(UIApplication *)application {
-(void)applicationDidEnterBackground:(NSNotification *)notification {
    [ofxiOSGetGLView() stopAnimation];
    glFinish();
    //only continue to generate sound when not connected to anything, maybe this needs a check for inter app audio too, but it works with garageband
    if ((dynamic_cast<ofApp*>(ofGetAppPtr())->instrumentIsOff())
        && !_audiobusController.connected && !_audiobusController.memberOfActiveAudiobusSession) {
       // AudioOutputUnitStop(dynamic_cast<ofApp*>(ofGetAppPtr())->getSoundStream()->getSoundOutStream().audioUnit);
       AudioOutputUnitStop(_audiobusSender.audioUnit);
        [[AVAudioSession sharedInstance] setActive:NO error:NULL];
    }
}

- (void)applicationWillEnterForeground:(UIApplication *)application {
    if ((dynamic_cast<ofApp*>(ofGetAppPtr())->instrumentIsOff())) {
      [[AVAudioSession sharedInstance] setActive:YES error:NULL];
      AudioOutputUnitStart(_audiobusSender.audioUnit);
      [[AVAudioSession sharedInstance] setCategory: AVAudioSessionCategoryPlayAndRecord
                                       withOptions:AVAudioSessionCategoryOptionAllowBluetooth|
                                                   AVAudioSessionCategoryOptionMixWithOthers|
                                                   AVAudioSessionCategoryOptionDefaultToSpeaker
                                            error:  NULL];
    }
}

//check for iia connection, i had a problem with fbos not working when started from inside garageband...
-(void) checkIAACon:(int *)iaaCon{
    UInt32 connected;
    UInt32 dataSize = sizeof(UInt32);
    AudioUnitGetProperty(_audiobusSender.audioUnit,
                         kAudioUnitProperty_IsInterAppConnected,
                         kAudioUnitScope_Global, 0, &connected, &dataSize);
    *iaaCon = connected;
}

//can be called from controlThread.h to test for connection
-(void) checkCon:(bool *)iaaCon{
    UInt32 connected;
    UInt32 dataSize = sizeof(UInt32);
    AudioUnitGetProperty(_audiobusSender.audioUnit,
                         kAudioUnitProperty_IsInterAppConnected,
                         kAudioUnitScope_Global, 0, &connected, &dataSize);
    if(_audiobusController.connected || connected == 1){
        *iaaCon = true;
    } else {
        *iaaCon = false;
    }
}
-(void)applicationWillTerminate:(UIApplication *)application {
    [super applicationWillTerminate:application];
}


@end

