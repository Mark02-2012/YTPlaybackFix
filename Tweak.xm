#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

@interface YTPlayerTapToRetryResponderEvent : NSObject
+ (id)eventWithFirstResponder:(id)arg1;
- (void)send;
@end

@interface YTPlayerViewController : UIViewController
- (CGFloat)currentVideoMediaTime;
- (void)seekToTime:(CGFloat)time;
@end

@interface YTMainAppVideoPlayerOverlayViewController : UIViewController
@property (nonatomic, assign) YTPlayerViewController *parentViewController;
@end

static NSTimeInterval gLastRetry = 0;
static CGFloat gLatestTime = 0.0;

%hook YTPlayerViewController

- (CGFloat)currentVideoMediaTime
{
    CGFloat t = %orig;

    if (t > gLatestTime) {
        gLatestTime = t;
    }

    return t;
}

%end

%hook YTMainAppVideoPlayerOverlayViewController

- (void)handleError:(NSError *)error
{
    if (error &&
        [error.domain isEqualToString:@"com.google.ios.youtube.ErrorDomain.playback"] &&
        error.code == 14)
    {
        NSTimeInterval now = [[NSDate date] timeIntervalSince1970];

        if (now - gLastRetry < 1.5) {
            return;
        }

        gLastRetry = now;

        YTPlayerViewController *pvc = nil;

        @try {
            pvc = [self parentViewController];
        } @catch (...) {}

        // usa il timestamp aggiornato continuamente
        CGFloat savedTime = gLatestTime;

        dispatch_after(dispatch_time(DISPATCH_TIME_NOW,
                       (int64_t)(0.15 * NSEC_PER_SEC)),
                       dispatch_get_main_queue(), ^{

            id responder = nil;

            @try {
                if ([self respondsToSelector:@selector(parentResponder)]) {
                    responder = [self performSelector:@selector(parentResponder)];
                }
            } @catch (...) {}

            if (responder) {
                id event =
                    [%c(YTPlayerTapToRetryResponderEvent)
                        eventWithFirstResponder:responder];

                if (event) {
                    [event send];
                }
            }

            if (pvc) {

                dispatch_after(dispatch_time(DISPATCH_TIME_NOW,
                               (int64_t)(0.35 * NSEC_PER_SEC)),
                               dispatch_get_main_queue(), ^{

                    @try {
                        [pvc seekToTime:savedTime];
                    } @catch (...) {}

                });
            }
        });

        return;
    }

    %orig;
}

%end
