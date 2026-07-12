#import <Foundation/Foundation.h>
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

static NSTimeInterval gLastRetry = 0;
static CGFloat gLatestTime = 0.0;
static int gBurstCount = 1;
static bool gEmergencyCheckRunning = false;

/*** 3. Hook: YTPlayerViewController ***********************************************/

%hook YTPlayerViewController

- (CGFloat)currentVideoMediaTime
{
    CGFloat t = %orig;
    gLatestTime = t;
    return t;
}

- (void)seekToTime:(CGFloat)time
{
    gLatestTime = time;
    %orig;
}

%end

/*** 4. Hook: YTMainAppVideoPlayerOverlayViewController *******************************/

%hook YTMainAppVideoPlayerOverlayViewController

- (void)handleError:(NSError *)error
{
    if (error &&
        [error.domain isEqualToString:@"com.google.ios.youtube.ErrorDomain.playback"] &&
        error.code == 14)
    {
        NSTimeInterval now = [[NSDate date] timeIntervalSince1970];

        if (now - gLastRetry < 1) { // anti-loop
            gBurstCount++;
        } else {
            gBurstCount = 1;
        }

        if (gBurstCount > 2) {
            %orig;
            return;
        }

        gLastRetry = now;

        YTPlayerViewController *pvc = nil;
        @try { pvc = [self parentViewController]; } @catch (...) {}

        CGFloat savedTime = gLatestTime;

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

                    @try { [pvc seekToTime:savedTime]; } @catch (...) {}

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

                                    @try { [pvc seekToTime:savedTime]; } @catch (...) {}

                                    dispatch_after(dispatch_time(DISPATCH_TIME_NOW,
                                                                 (int64_t)(0.20 * NSEC_PER_SEC)),
                                               dispatch_get_main_queue(), ^{
                                        @try { [pvc replay]; } @catch (...) {} // replay di emergenza
                                        // Fine - nessun altro retry
                                    });
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
    gLatestTime = 0.0;
    gLastRetry = 0;
    gBurstCount = 1;
    gEmergencyCheckRunning = false;
}
