#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

// Definiamo le interfacce per evitare errori di compilazione
@interface YTPlayerTapToRetryResponderEvent : NSObject
+ (id)eventWithFirstResponder:(id)arg1;
- (void)send;
@end

@interface YTLocalPlaybackController : NSObject
- (id)parentResponder;
@end

// Variabile statica per tenere traccia del controller
static __weak YTLocalPlaybackController *sharedPlaybackController = nil;

%hook YTLocalPlaybackController

- (id)init {
    id instance = %orig;
    sharedPlaybackController = instance;
    return instance;
}

// Assicuriamoci che venga aggiornato se il controller cambia
- (void)play {
    sharedPlaybackController = self;
    %orig;
}

%end

%hook NSError

- (id)initWithDomain:(NSString *)domain code:(NSInteger)code userInfo:(NSDictionary *)dict {
    // Intercettiamo l'errore 14
    if ([domain isEqualToString:@"com.google.ios.youtube.ErrorDomain.playback"] && code == 14) {
        
        NSLog(@"[YTPlaybackFix] Errore 14: Iniezione evento di retry sicura...");
        
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 0.5 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
            // Usiamo il responder salvato dal nostro hook, senza cercare finestre o keyWindow
            if (sharedPlaybackController) {
                id responder = [sharedPlaybackController parentResponder];
                if (responder) {
                    // Creiamo l'evento esattamente come fa YTUHD
                    id event = [%c(YTPlayerTapToRetryResponderEvent) eventWithFirstResponder:responder];
                    if (event) {
                        [event send];
                        NSLog(@"[YTPlaybackFix] Evento di Retry inviato correttamente!");
                    }
                }
            }
        });
        
        return %orig;
    }
    return %orig;
}

%end
