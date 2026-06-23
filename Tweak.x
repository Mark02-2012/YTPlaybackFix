#import <UIKit/UIKit.h>

// 1. Interfacciamo le classi che gestiscono i permessi di riproduzione del video
@interface YTIPlayabilityStatus : NSObject
- (int)status;
- (BOOL)isPlayable;
@end

@interface YTPlayerResponse : NSObject
- (BOOL)isPlayable;
- (YTIPlayabilityStatus *)playabilityStatus;
@end

// HOOK 1: Forziamo lo stato del blocco a livello di pacchetto dati (ProtoBuf)
%hook YTIPlayabilityStatus

- (int)status {
    int originalStatus = %orig;
    // Nello standard di YouTube, lo status '1' significa "PLAYABLE" (Riproducibile).
    // Se è diverso da 1, il server sta bloccando il video (es. Errore 14).
    if (originalStatus != 1) {
        NSLog(@"[YTPlaybackFix] ⚠️ Server ha ritornato status di blocco (%d). Forzo a 1 (Playable)!", originalStatus);
        return 1; // Forziamo lo sblocco
    }
    return originalStatus;
}

- (BOOL)isPlayable {
    // Se l'app chiede direttamente se è riproducibile, rispondiamo sempre di sì
    return YES;
}

%end

// HOOK 2: Sicurezza aggiuntiva sulla risposta generale del Player
%hook YTPlayerResponse

- (BOOL)isPlayable {
    return YES;
}

%end


// 2. Costruttore statico per LiveContainer con notifica di avvio
__attribute__((constructor)) static void initYTFixV3() {
    NSLog(@"[YTPlaybackFix] Tweak v3 (Data Layer) caricato con successo!");
    
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        UIWindow *activeWindow = nil;
        for (UIWindowScene *scene in [UIApplication sharedApplication].connectedScenes) {
            if (scene.activationState == UISceneActivationStateForegroundActive) {
                activeWindow = scene.windows.firstObject;
                break;
            }
        }
        
        UIViewController *root = activeWindow.rootViewController;
        if (root) {
            UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"YTPlaybackFix v3 🚀"
                                                                           message:@"Bypass dei dati attivo per YouTube 21.22.4!\nPronto a bloccare l'Errore 14 alla radice."
                                                                    preferredStyle:UIAlertControllerStyleAlert];
            [alert addAction:[UIAlertAction actionWithTitle:@"Andiamo!" style:UIAlertActionStyleDefault handler:nil]];
            [root presentViewController:alert animated:YES completion:nil];
        }
    });
}
