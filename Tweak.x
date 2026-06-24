#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

// --- Interfacce ---
@interface YTPlayerTapToRetryResponderEvent : NSObject
+ (id)eventWithFirstResponder:(id)arg1;
- (void)send;
@end

@interface YTSingleVideoController : NSObject
- (id)parentResponder;
@end

@interface MLHAMQueuePlayer : NSObject
@property (nonatomic, weak) id delegate;
- (NSInteger)state;
@end

// --- Variabile di sicurezza (Anti-Spam) ---
static NSDate *lastRetryTime = nil;

static void performRetry(id responder) {
    if (!responder) return;
    
    // Evita di inviare più di un retry ogni 3 secondi (fondamentale per non essere bannati dai server)
    if (lastRetryTime && [[NSDate date] timeIntervalSinceDate:lastRetryTime] < 3.0) {
        return;
    }
    lastRetryTime = [NSDate date];
    
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        id event = [%c(YTPlayerTapToRetryResponderEvent) eventWithFirstResponder:responder];
        if (event) {
            [event send];
            NSLog(@"[YTPlaybackFix] Retry inviato con successo!");
        }
    });
}

// --- Hook 1: Motore (Playback Engine) ---
%hook MLHAMQueuePlayer

- (void)setState:(NSInteger)state {
    %orig;
    
    // Stati 5, 6, 8 = Blocchi/Errori critici
    if (state == 5 || state == 6 || state == 8) {
        id delegate = [self delegate];
        if ([delegate respondsToSelector:@selector(parentResponder)]) {
            performRetry([delegate parentResponder]);
        }
    }
}

%end

// --- Hook 2: UI (Gestione Alert Errore 14) ---
%hook YTSingleVideoController

- (void)showErrorAlertWithError:(id)arg1 {
    %orig; // Importante: chiamiamo l'originale per non rompere la catena logica dell'app
    
    NSLog(@"[YTPlaybackFix] Errore UI rilevato, tentativo di retry automatico...");
    
    if ([self respondsToSelector:@selector(parentResponder)]) {
        performRetry([self parentResponder]);
    }
}

%end
