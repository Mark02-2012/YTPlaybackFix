#import <UIKit/UIKit.h>
#import <objc/runtime.h>

/*** 1. Interfacce esterne *************************************************************/

@interface YTPlayerTapToRetryResponderEvent : NSObject
+ (id)eventWithFirstResponder:(id)arg1;
- (void)send;
@end

@interface YTPlayerViewController : UIViewController
- (CGFloat)currentVideoMediaTime;
- (void)seekToTime:(CGFloat)time;
- (void)replay;
@end

@interface YTMainAppVideoPlayerOverlayViewController : UIViewController
@property (nonatomic, assign) YTPlayerViewController *parentViewController;
@end

/*** 2. Stato globale ******************************************************************/

static CGFloat gTime;
static CGFloat gSavedTime;
static BOOL gIsTimeToRetry = NO;
static bool gEmergencyCheckRunning = false;

/*** 3. Hook: YTPlayerViewController ***********************************************/

%hook YTPlayerViewController

- (CGFloat)currentVideoMediaTime
    {
        CGFloat currentVideoMediaTime = %orig;
        gTime = currentVideoMediaTime;
        gSavedTime = gTime;
        return currentVideoMediaTime;
    }

- (void)seekToTime:(CGFloat)time
{
     gSavedTime = gTime;
    %orig;
}

%end

/*** 4. Hook: YTMainAppVideoPlayerOverlayViewController *******************************/

%hook YTMainAppVideoPlayerOverlayViewController

- (void)handleError:(NSError *)error
{ 

// Anti-loop new logic
if (gIsTimeToRetry) {
    %orig;
    return;
}
    if (error &&
        [error.domain isEqualToString:@"com.google.ios.youtube.ErrorDomain.playback"] &&
        (error.code == 14 || error.code == 0))
    {
          gIsTimeToRetry = YES;

        YTPlayerViewController *pvc = nil;
        @try { pvc = [self parentViewController]; } @catch (...) {}

        CGFloat savedTime = gSavedTime;

        dispatch_after(dispatch_time(DISPATCH_TIME_NOW,
                                     (int64_t)(0.10 * NSEC_PER_SEC)),
                       dispatch_get_main_queue(), ^{

            id responder = nil;
            @try {
                if ([self respondsToSelector:@selector(parentResponder)]) {
                    responder = [self performSelector:@selector(parentResponder)];
                }
            } @catch (...) {}

            if (responder) {
                id event = [%c(YTPlayerTapToRetryResponderEvent)
                              eventWithFirstResponder:responder];
                if (event) { [event send]; }
            }

            if (pvc) {
                dispatch_after(dispatch_time(DISPATCH_TIME_NOW,
                                             (int64_t)(0.20 * NSEC_PER_SEC)),
                               dispatch_get_main_queue(), ^{

                    @try { [pvc seekToTime:gSavedTime]; } @catch (...) {}

                    dispatch_after(dispatch_time(DISPATCH_TIME_NOW,
                                                 (int64_t)(0.10 * NSEC_PER_SEC)),
                                   dispatch_get_main_queue(), ^{

                        @try { [pvc replay]; } @catch (...) {} // replay principale

                        // === Controllo di emergenza conservativo ===
                        if (!gEmergencyCheckRunning) {
                            gEmergencyCheckRunning = true;

                            dispatch_after(dispatch_time(DISPATCH_TIME_NOW,
                                                         (int64_t)(1.00 * NSEC_PER_SEC)), // 1 secondo
                                       dispatch_get_main_queue(), ^{

                                CGFloat currentTime = [pvc currentVideoMediaTime];
                                // Controllo robusto: il video è ancora fermo?
                                if (currentTime <= savedTime + 0.05) {

                                    id emergencyResponder = nil;
                                    @try {
                                        if ([self respondsToSelector:@selector(parentResponder)]) {
                                            emergencyResponder = [self performSelector:@selector(parentResponder)];
                                        }
                                    } @catch (...) {}

                                    if (emergencyResponder) {
                                        id emergencyEvent = [%c(YTPlayerTapToRetryResponderEvent)
                                                              eventWithFirstResponder:emergencyResponder];
                                        if (emergencyEvent) { [emergencyEvent send]; }
                                    }

                                    @try { [pvc seekToTime:gSavedTime]; } @catch (...) {}

                                    dispatch_after(dispatch_time(DISPATCH_TIME_NOW,
                                                                 (int64_t)(0.20 * NSEC_PER_SEC)),
                                               dispatch_get_main_queue(), ^{
                                        @try { [pvc replay]; } @catch (...) {} // replay di emergenza
                                         gIsTimeToRetry = NO;
                                        // Fine - nessun altro retry
                            
                                    });
                                     } else { 
                                         gIsTimeToRetry = NO;
                                }

                                gEmergencyCheckRunning = false;
                            });
                        }
                    });
                });
            }
        });

        return;
    }

    %orig;
}


%end

/*** 5. Costruttore ********************************************************************/

%ctor
{
    gSavedTime = 0;
    gTime = 0.0;
    gIsTimeToRetry = NO;
    gEmergencyCheckRunning = false;
}
