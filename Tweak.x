#import <UIKit/UIKit.h>

// 1. Dichiariamo al compilatore tutti i metodi (reali o ipotetici) che useremo
@interface YTPlayerViewController : UIViewController
- (void)retryPlayback;
- (void)reloadVideo;
- (void)resetPlayer;
- (void)playVideo;
- (void)showError:(NSError *)error;
- (void)showPlaybackError:(NSError *)error;
- (void)setPlaybackError:(NSError *)error;
- (void)playbackDidFailWithError:(NSError *)error;
- (void)playerViewController:(id)arg1 playbackDidFailWithError:(NSError *)arg2;

// Metodi custom che iniettiamo noi nella classe
- (BOOL)isGoogleBlock:(NSError *)error;
- (void)triggerCountermeasure;
@end


%hook YTPlayerViewController

// --- RETE 1: Il delegato classico ---
- (void)playbackDidFailWithError:(NSError *)error {
    if ([self isGoogleBlock:error]) {
        [self triggerCountermeasure];
        return; // Sopprime la chiamata originale (niente schermata nera)
    }
    %orig;
}

// --- RETE 2: Il delegato moderno con sender ---
- (void)playerViewController:(id)controller playbackDidFailWithError:(NSError *)error {
    if ([self isGoogleBlock:error]) {
        [self triggerCountermeasure];
        return; 
    }
    %orig;
}

// --- RETE 3: Il setter della schermata d'errore ---
- (void)setPlaybackError:(NSError *)error {
    if ([self isGoogleBlock:error]) {
        [self triggerCountermeasure];
        return;
    }
    %orig;
}

// --- RETE 4: Chiamata diretta di rendering UI ---
- (void)showError:(NSError *)error {
    if ([self isGoogleBlock:error]) {
        [self triggerCountermeasure];
        return;
    }
    %orig;
}

// --- RETE 5: Variante Google del render UI ---
- (void)showPlaybackError:(NSError *)error {
    if ([self isGoogleBlock:error]) {
        [self triggerCountermeasure];
        return;
    }
    %orig;
}


// ==========================================
// CERVELLO DEL BYPASS (Iniettato nella classe)
// ==========================================

%new
- (BOOL)isGoogleBlock:(NSError *)error {
    if (!error) return NO;

    // Stampiamo l'identikit completo dell'errore nella console di sistema
    NSLog(@"[YTPlaybackFix PRO] INTERCETTATO -> Domain: %@ | Code: %ld | Desc: %@", 
          error.domain, (long)error.code, error.localizedDescription);

    // -1009 = Dispositivo offline; -1001 = Reale timeout del modem
    if (error.code == -1009 || error.code == -1001) {
        NSLog(@"[YTPlaybackFix PRO] Errore di rete legittimo. Lascio passare.");
        return NO;
    }

    return YES;
}

%new
- (void)triggerCountermeasure {
    static NSTimeInterval lastBypassTime = 0;
    NSTimeInterval now = [[NSDate date] timeIntervalSince1970];

    // DEBOUNCER: Ignora le raffiche di errori per 2.0 secondi per evitare il freeze
    if (now - lastBypassTime < 2.0) {
        NSLog(@"[YTPlaybackFix PRO] Bypass in cooldown, ignoro richiesta...");
        return;
    }
    lastBypassTime = now;

    NSLog(@"[YTPlaybackFix PRO] 🛡️ CONTROMISURA ATTIVATA: Forzo il ricaricamento del flusso...");

    // Ritardo di 0.5s per far chiudere i socket morti prima di riaprirli
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        
        if ([self respondsToSelector:@selector(retryPlayback)]) {
            NSLog(@"[YTPlaybackFix PRO] Comando: retryPlayback");
            [self retryPlayback];
        } 
        else if ([self respondsToSelector:@selector(reloadVideo)]) {
            NSLog(@"[YTPlaybackFix PRO] Comando: reloadVideo");
            [self reloadVideo];
        } 
        else {
            NSLog(@"[YTPlaybackFix PRO] Comando: Hard Reset");
            if ([self respondsToSelector:@selector(resetPlayer)]) [self resetPlayer];
            if ([self respondsToSelector:@selector(playVideo)]) [self playVideo];
        }
    });
}

%end


// 4. Costruttore statico: si avvia da solo appena l'app viene aperta in LiveContainer
__attribute__((constructor)) static void initYTFix() {
    NSLog(@"[YTPlaybackFix] Tweak caricato in memoria con successo!");
    
    // Questo popup conferma al 100% che LiveContainer sta leggendo la dylib!
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        
        UIWindow *activeWindow = nil;
        // Metodo moderno per iOS 13+ per recuperare la finestra attiva senza errori di compilazione
        for (UIWindowScene *scene in [UIApplication sharedApplication].connectedScenes) {
            if (scene.activationState == UISceneActivationStateForegroundActive) {
                activeWindow = scene.windows.firstObject;
                break;
            }
        }
        
        UIViewController *root = activeWindow.rootViewController;
        if (root) {
            UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"YTPlaybackFix v2"
                                                                           message:@"Codice avanzato iniettato. Il tweak è in ascolto degli errori di rete e pronto all'auto-retry."
                                                                    preferredStyle:UIAlertControllerStyleAlert];
            [alert addAction:[UIAlertAction actionWithTitle:@"Inizia il test" style:UIAlertActionStyleDefault handler:nil]];
            [root presentViewController:alert animated:YES completion:nil];
        }
    });
}
