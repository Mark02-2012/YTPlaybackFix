#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <objc/message.h>

// Definiamo il controller fuori dagli hook per usarlo
static __weak id sharedPlaybackController = nil;

%hook YTPlaybackController
- (id)init {
    id instance = %orig;
    sharedPlaybackController = instance;
    return instance;
}

- (void)play {
    sharedPlaybackController = self;
    %orig;
}
%end

%hook NSError

- (id)initWithDomain:(NSString *)domain code:(NSInteger)code userInfo:(NSDictionary *)dict {
    // Se è l'errore 14, lasciamo passare l'errore originale ma forziamo il retry
    if ([domain isEqualToString:@"com.google.ios.youtube.ErrorDomain.playback"] && code == 14) {
        
        NSLog(@"[YTPlaybackFix] Errore 14 rilevato, avvio procedura di invisibilità...");
        
        dispatch_async(dispatch_get_main_queue(), ^{
            if (sharedPlaybackController) {
                // Usiamo performSelector per invocare 'retry' in sicurezza
                [sharedPlaybackController performSelector:@selector(retry)];
            }
        });
        
        return %orig;
    }
    return %orig;
}

%end
