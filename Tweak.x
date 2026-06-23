#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

// Definizione del responder event per il retry
@interface YTPlayerTapToRetryResponderEvent : NSObject
+ (id)eventWithFirstResponder:(id)arg1;
- (void)send;
@end

%hook NSError

- (id)initWithDomain:(NSString *)domain code:(NSInteger)code userInfo:(NSDictionary *)dict {
    // Intercettiamo l'errore 14
    if ([domain isEqualToString:@"com.google.ios.youtube.ErrorDomain.playback"] && code == 14) {
        
        NSLog(@"[YTPlaybackFix] Errore 14 rilevato, iniezione evento di retry...");
        
        dispatch_async(dispatch_get_main_queue(), ^{
            // Recuperiamo il player attivo
            UIWindow *window = [UIApplication sharedApplication].keyWindow;
            // Usiamo lo stesso metodo di YTUHD per trovare il controller
            // E forziamo il retry tramite l'evento ufficiale
            id responder = [window firstResponder];
            if (responder) {
                id event = [%c(YTPlayerTapToRetryResponderEvent) eventWithFirstResponder:responder];
                [event send];
            }
        });
        
        // Ritorniamo %orig per non far crashare l'app, 
        // ma l'evento di retry sarà già partito in parallelo
        return %orig;
    }
    return %orig;
}

%end
