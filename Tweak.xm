#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

@interface MLPlayerReloadContext : NSObject

* (instancetype)initWithStartPlayback:(BOOL)startPlayback
  refreshStreamingData:(BOOL)refreshStreamingData;
  @end

@interface YTSingleVideoController : NSObject

* (void)reloadPlayerWithContext:(MLPlayerReloadContext *)context;
  @end

@interface YTPlayerViewController : UIViewController

* (YTSingleVideoController *)activeVideo;
* (CGFloat)currentVideoMediaTime;
* (void)seekToTime:(CGFloat)time;
  @end

static __weak YTPlayerViewController *gCurrentPlayerVC = nil;
static NSTimer *gReloadTimer = nil;

static void PerformAutoReload(void)
{
YTPlayerViewController *pvc = gCurrentPlayerVC;

```
if (!pvc)
    return;

YTSingleVideoController *video = [pvc activeVideo];

if (!video)
    return;

CGFloat oldTime = [pvc currentVideoMediaTime];

MLPlayerReloadContext *ctx =
    [[%c(MLPlayerReloadContext) alloc]
        initWithStartPlayback:YES
         refreshStreamingData:YES];

if (!ctx)
    return;

[video reloadPlayerWithContext:ctx];

dispatch_after(dispatch_time(DISPATCH_TIME_NOW,
               (int64_t)(1.0 * NSEC_PER_SEC)),
               dispatch_get_main_queue(), ^{

    if (gCurrentPlayerVC) {
        [gCurrentPlayerVC seekToTime:oldTime];
    }

});
```

}

%hook YTPlayerViewController

* (YTSingleVideoController *)activeVideo
  {
  gCurrentPlayerVC = self;
  return %orig;
  }

* (void)viewDidAppear:(BOOL)animated
  {
  %orig;

  gCurrentPlayerVC = self;

  if (gReloadTimer) {
  [gReloadTimer invalidate];
  gReloadTimer = nil;
  }

  gReloadTimer =
  [NSTimer scheduledTimerWithTimeInterval:25.0
  repeats:YES
  block:^(NSTimer *timer)
  {
  PerformAutoReload();
  }];
  }

* (void)viewDidDisappear:(BOOL)animated
  {
  %orig;

  if (gReloadTimer) {
  [gReloadTimer invalidate];
  gReloadTimer = nil;
  }
  }

%end
