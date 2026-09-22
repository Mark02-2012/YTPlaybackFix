/*===========================================================================
 * YouFixPlaybackIssues.xm – Versione completa con selezione client Morphe
 *==========================================================================*/

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <objc/NSObjCRuntime.h>
#import "GPBMessage.h"


// ============================================================================
//                               PART 1: CONFIG
// ============================================================================

static NSString * const kEndpointPlayer       = @"/player";
static NSString * const kEndpointNext         = @"/next";
static NSString * const kEndpointBrowse       = @"/browse";
static NSString * const kEndpointInitPlayback  = @"/initplayback";
static NSString * const kEndpointVideoPlayback = @"/videoplayback";

static NSString * const kJSONKeyContext       = @"context";
static NSString * const kJSONKeyClient        = @"client";
static NSString * const kJSONKeyVisitorData   = @"visitorData";
static NSString * const kJSONKeyVideoId       = @"videoId";
static NSString * const kJSONKeyBrowseId      = @"browseId";
static NSString * const kJSONKeyContinuation  = @"continuation";

static NSString * const YTPlaybackFixSpoofEnabledKey   = @"YTPlaybackFixSpoofEnabled";
static NSString * const YTPlaybackFixSpoofClientModeKey = @"YTPlaybackFixSpoofClientMode";


// ============================================================================
//                          PART 2: MORPHE-LIKE PLAYBACK CLIENTS
// ============================================================================

/* Common base */
static NSString * const kMorpheDeviceMake    = @"Sony";
static NSString * const kMorpheDeviceModel   = @"PS4";
static NSString * const kMorpheOSName        = @"PlayStation 4";
static NSString * const kMorpheOSVersion     = @"";
static NSString * const kMorpheClientPlatform= @"GAME_CONSOLE";
static NSString * const kMorpheUserAgent =
    @"Mozilla/5.0 (PS4; Leanback Shell) "
    @"Gecko/20100101 Firefox/65.0 "
    @"LeanbackShell/01.00.01.75 "
    @"Sony PS4/ (PS4, , no, CH)";

/* TV_SABR (aka TVHTML5)  */
static NSString * const kTVSABRClientName    = @"TVHTML5";
static NSString * const kTVSABRClientVersion = @"7.20260707.07.00";
static NSString * const kTVSABRNumericClient = @"7";

/* TV_SIMPLY (aka TVHTML5_SIMPLY) */
static NSString * const kTVSimplyClientName  = @"TVHTML5_SIMPLY";
static NSString * const kTVSimplyClientVersion = @"1.1";
static NSString * const kTVSimplyNumericClient = @"75";


/*===========================================================================
 * HELPER SETTINGS
 *==========================================================================*/

static BOOL YTPlaybackFixSpoofEnabled(void)
{
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    return [defaults boolForKey:YTPlaybackFixSpoofEnabledKey];
}

static NSInteger YTPlaybackFixSpoofClientMode(void)
{
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    if (![defaults objectForKey:YTPlaybackFixSpoofClientModeKey]) return 0;
    NSInteger mode = [defaults integerForKey:YTPlaybackFixSpoofClientModeKey];
    return mode == 1 ? 1 : 0;          // clamp
}

static BOOL YTPlaybackFixSpoofUsesTVSABR(void)
{
    return YTPlaybackFixSpoofClientMode() == 1;
}

/* Dizionario completo del client attivo (usato in header, body e URL) */
static NSDictionary *YTPlaybackFixClientContext(void)
{
    BOOL usesTVSABR = YTPlaybackFixSpoofUsesTVSABR();
    return @{
        @"clientName":     usesTVSABR ? kTVSABRClientName    : kTVSimplyClientName,
        @"clientVersion":  usesTVSABR ? kTVSABRClientVersion : kTVSimplyClientVersion,
        @"hl":             @"en",
        @"timeZone":       @"UTC",
        @"utcOffsetMinutes": @0,
        @"deviceMake":     kMorpheDeviceMake,
        @"deviceModel":    kMorpheDeviceModel,
        @"osName":         kMorpheOSName,
        @"osVersion":      kMorpheOSVersion,
        @"clientPlatform": kMorpheClientPlatform,
        @"userAgent":      kMorpheUserAgent
    };
}

static NSString *YTPlaybackFixNumericClient(void)
{
    return YTPlaybackFixSpoofUsesTVSABR() ? kTVSABRNumericClient : kTVSimplyNumericClient;
}

static NSString *YTPlaybackFixUserAgent(void)
{
    return kMorpheUserAgent;
}


/*===========================================================================
 * YTDirectPlaybackClient – genera header e blueprint del contesto
 *==========================================================================*/

@interface YTDirectPlaybackClient : NSObject
+ (NSDictionary *)apiHeadersForVisitorData:(NSString *)visitorData;
+ (NSDictionary *)activeClientContext;
+ (NSDictionary *)contextBlueprint;
@end

@implementation YTDirectPlaybackClient

+ (NSDictionary *)apiHeadersForVisitorData:(NSString *)visitorData
{
    if (!YTPlaybackFixSpoofEnabled()) return @{};

    NSMutableDictionary *headers = [NSMutableDictionary dictionary];
    headers[@"Accept-Language"] = @"*";
    headers[@"X-YouTube-Client-Name"] = YTPlaybackFixNumericClient();
    headers[@"X-YouTube-Client-Version"] = [YTPlaybackFixClientContext()[@"clientVersion"]];
    headers[@"User-Agent"] = YTPlaybackFixUserAgent();
    headers[@"Origin"] = @"https://www.youtube.com";

    if (visitorData.length > 0) {
        headers[@"X-Goog-Visitor-Id"] = visitorData;
    }
    return [headers copy];
}

+ (NSDictionary *)activeClientContext
{
    return YTPlaybackFixClientContext();
}

+ (NSDictionary *)contextBlueprint
{
    return @{ kJSONKeyContext: [self activeClientContext] };
}
@end


/*===========================================================================
 * YTInnertubeSession – cattura visitorData e riscrive il payload JSON
 *==========================================================================*/

@interface YTInnertubeSession : NSObject
@property (nonatomic, copy) NSString *visitorData;
+ (instancetype)sharedSession;
- (NSDictionary *)buildPayloadWithIncomingBody:(NSDictionary *)incomingBody;
@end

@implementation YTInnertubeSession
+ (instancetype)sharedSession
{
    static YTInnertubeSession *shared = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{ shared = [[YTInnertubeSession alloc] init]; });
    return shared;
}

- (NSDictionary *)buildPayloadWithIncomingBody:(NSDictionary *)incomingBody
{
    if (!YTPlaybackFixSpoofEnabled() || ![incomingBody isKindOfClass:[NSDictionary class]]) return nil;

    NSMutableDictionary *mutatedBody = [incomingBody mutableCopy];
    NSDictionary *incomingContext = incomingBody[kJSONKeyContext];
    NSMutableDictionary *mutableContext = [incomingContext isKindOfClass:[NSDictionary class]]
                                          ? [incomingContext mutableCopy]
                                          : [NSMutableDictionary dictionary];

    NSDictionary *incomingClient = incomingContext[kJSONKeyClient];
    if ([incomingClient isKindOfClass:[NSDictionary class]]) {
        id incomingVisitor = incomingClient[kJSONKeyVisitorData];
        if ([incomingVisitor isKindOfClass:[NSString class]] && incomingVisitor.length > 0) {
            self.visitorData = incomingVisitor;
        }
    }

    NSMutableDictionary *client = [[YTDirectPlaybackClient activeClientContext] mutableCopy];
    if (self.visitorData.length > 0) {
        client[kJSONKeyVisitorData] = self.visitorData;
    }
    mutableContext[kJSONKeyClient] = [client copy];
    mutatedBody[kJSONKeyContext] = [mutableContext copy];
    return [mutatedBody copy];
}
@end


/*==========================================================================
 * URL HELPERS
 *========================================================================*/

static BOOL YTPathContains(NSURL *URL, NSString *endpoint)
{
    if (!URL || !endpoint.length) return NO;
    NSString *path = URL.path.lowercaseString;
    return [path containsString:endpoint.lowercaseString];
}

static BOOL YTIsInnertubeRequest(NSURL *URL)
{
    return YTPathContains(URL, kEndpointPlayer) ||
           YTPathContains(URL, kEndpointNext)   ||
           YTPathContains(URL, kEndpointBrowse) ||
           YTPathContains(URL, kEndpointInitPlayback);
}

static BOOL YTIsVideoPlaybackRequest(NSURL *URL)
{
    return YTPathContains(URL, kEndpointVideoPlayback);
}

static BOOL YTShouldMutateRequest(NSURLRequest *request)
{
    if (!request || !YTPlaybackFixSpoofEnabled()) return NO;
    NSURL *URL = request.URL;
    return URL && (YTIsInnertubeRequest(URL) || YTIsVideoPlaybackRequest(URL));
}

/* Sostituisce o aggiunge un parametro query preservando l’URL */
static NSURL *YTURLBySettingQueryParameter(NSURL *URL, NSString *parameter, NSString *value)
{
    if (!URL || !parameter.length || !value.length) return URL;

    NSURLComponents *components = [NSURLComponents componentsWithURL:URL includingQueryItems:YES];
    if (!components) return URL;

    NSMutableArray<NSURLQueryItem *> *queryItems = [components.queryItems mutableCopy];
    if (!queryItems) queryItems = [NSMutableArray array];

    NSMutableArray<NSURLQueryItem *> *filtered = [NSMutableArray array];
    for (NSURLQueryItem *item in queryItems) {
        if ([item.name caseInsensitiveCompare:parameter] != NSOrderedSame) {
            [filtered addObject:item];
        }
    }
    [filtered addObject:[NSURLQueryItem queryItemWithName:parameter value:value]];
    components.queryItems = filtered;

    NSURL *rewritten = components.URL;
    return rewritten ?: URL;
}

static NSURL *YTRewriteInnertubeURL(NSURL *URL)
{
    NSDictionary *client = YTPlaybackFixClientContext();
    NSURL *newURL = YTURLBySettingQueryParameter(URL, @"c", client[@"clientName"]);
    newURL = YTURLBySettingQueryParameter(newURL, @"cver", client[@"clientVersion"]);
    return newURL;
}

static NSURL *YTRewriteVideoPlaybackURL(NSURL *URL)
{
    return YTURLBySettingQueryParameter(URL, @"user_agent", YTPlaybackFixUserAgent());
}


/*==========================================================================
 * REQUEST MUTATION HELPERS
 *========================================================================*/

static void YTApplyCustomHeaders(NSMutableURLRequest *request)
{
    if (!request || !YTPlaybackFixSpoofEnabled()) return;

    NSDictionary *headers = [YTDirectPlaybackClient apiHeadersForVisitorData:
                                [YTInnertubeSession sharedSession].visitorData];
    [headers enumerateKeysAndObjectsUsingBlock:^(NSString *key, id value, BOOL *stop) {
        [request setValue:value forHTTPHeaderField:key];
    }];
}

/* Riscrive il body SOLO per le richieste Innertube JSON */
static BOOL YTApplyCustomBody(NSMutableURLRequest *request)
{
    if (!request || !request.HTTPBody.length) return NO;
    if (!YTIsInnertubeRequest(request.URL)) return NO;

    NSString *contentType = [request valueForHTTPHeaderField:@"Content-Type"] ?: @"";
    if ([contentType.lowercaseString containsString:@"protobuf"]) return NO;

    NSError *error = nil;
    id parsed = [NSJSONSerialization JSONObjectWithData:request.HTTPBody options:0 error:&error];
    if (error || ![parsed isKindOfClass:[NSDictionary class]]) return NO;

    NSDictionary *mutated = [[YTInnertubeSession sharedSession] buildPayloadWithIncomingBody:parsed];
    if (!mutated) return NO;

    NSData *data = [NSJSONSerialization dataWithJSONObject:mutated options:0 error:nil];
    if (!data) return NO;

    request.HTTPBody = data;
    /* imposta content-type solo dopo una riscrittura JSON */
    [request setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
    return YES;
}

static void YTApplyURLSpoof(NSMutableURLRequest *request)
{
    if (!request) return;
    NSURL *URL = request.URL;
    if (!URL) return;

    if (YTPathContains(URL, kEndpointInitPlayback)) {
        NSURL *newURL = YTRewriteInnertubeURL(URL);
        if (newURL && ![newURL isEqual:URL]) request.URL = newURL;
        URL = request.URL;
    }
    if (YTIsVideoPlaybackRequest(URL)) {
        NSURL *newURL = YTRewriteVideoPlaybackURL(URL);
        if (newURL && ![newURL isEqual:URL]) request.URL = newURL;
    }
}

static void YTApplyPlaybackSpoof(NSMutableURLRequest *request)
{
    if (!request || !YTPlaybackFixSpoofEnabled()) return;
    NSURL *URL = request.URL;
    if (!URL) return;

    if (YTIsInnertubeRequest(URL)) {
        YTApplyCustomBody(request);
        YTApplyCustomHeaders(request);
        YTApplyURLSpoof(request);
        return;
    }
    if (YTIsVideoPlaybackRequest(URL)) {
        YTApplyCustomHeaders(request);
        YTApplyURLSpoof(request);
    }
}


/*==========================================================================
 * HOOKS
 *========================================================================*/

%hook NSMutableURLRequest

- (id)initWithURL:(NSURL *)URL
{
    self = %orig(URL);
    if (!self) return self;
    YTApplyPlaybackSpoof(self);
    return self;
}

- (id)initWithURL:(NSURL *)URL cachePolicy:(NSURLRequestCachePolicy)cachePolicy timeoutInterval:(NSTimeInterval)timeoutInterval
{
    self = %orig(URL, cachePolicy, timeoutInterval);
    if (!self) return self;
    YTApplyPlaybackSpoof(self);
    return self;
}
%end


@interface GTMSessionFetcher : NSObject
- (id)mutableRequestForTesting;
@end

%hook GTMSessionFetcher

- (id)initWithRequest:(id)request
{
    if (![request isKindOfClass:[NSURLRequest class]]) return %orig(request);
    NSURLRequest *typed = (NSURLRequest *)request;
    if (!YTShouldMutateRequest(typed)) return %orig(request);

    NSMutableURLRequest *mutableRequest = [typed isKindOfClass:[NSMutableURLRequest class]]
                                        ? (NSMutableURLRequest *)typed
                                        : [typed mutableCopy];
    YTApplyPlaybackSpoof(mutableRequest);
    request = mutableRequest;
    return %orig(request);
}

- (id)initWithRequest:(id)request configuration:(id)configuration
{
    if (![request isKindOfClass:[NSURLRequest class]]) return %orig(request, configuration);
    NSURLRequest *typed = (NSURLRequest *)request;
    if (!YTShouldMutateRequest(typed)) return %orig(request, configuration);

    NSMutableURLRequest *mutableRequest = [typed isKindOfClass:[NSMutableURLRequest class]]
                                        ? (NSMutableURLRequest *)typed
                                        : [typed mutableCopy];
    YTApplyPlaybackSpoof(mutableRequest);
    request = mutableRequest;
    return %orig(request, configuration);
}

- (void)updateMutableRequest:(id)request
{
    if (![request isKindOfClass:[NSMutableURLRequest class]]) {
        %orig(request);
        return;
    }
    YTApplyPlaybackSpoof((NSMutableURLRequest *)request);
    %orig(request);
}

- (void)setRequestValue:(id)value forHTTPHeaderField:(id)field
{
    if (!YTPlaybackFixSpoofEnabled()) { %orig(value, field); return; }
    if (![self respondsToSelector:@selector(mutableRequestForTesting)]) { %orig(value, field); return; }
    NSMutableURLRequest *req = [self mutableRequestForTesting];
    if (!req) { %orig(value, field); return; }

    BOOL should = YTShouldMutateRequest(req);
    %orig(value, field);
    if (should) YTApplyCustomHeaders(req);
}

- (void)setBodyData:(id)data
{
    if (![self respondsToSelector:@selector(mutableRequestForTesting)]) { %orig(data); return; }
    NSMutableURLRequest *req = [self mutableRequestForTesting];
    if (!req) { %orig(data); return; }

    BOOL should = YTShouldMutateRequest(req);
    %orig(data);
    if (should) { YTApplyCustomBody(req); YTApplyCustomHeaders(req); }
}
%end


%hook GTMSessionFetcherSessionDelegateDispatcher

- (id)connection:(id)connection willSendRequest:(id)request redirectResponse:(id)redirectResponse
{
    if (![request isKindOfClass:[NSURLRequest class]]) return %orig(connection, request, redirectResponse);
    NSURLRequest *typed = (NSURLRequest *)request;
    if (!YTShouldMutateRequest(typed)) return %orig(connection, request, redirectResponse);

    NSMutableURLRequest *mutableRequest = [(NSURLRequest *)request mutableCopy];
    if (!mutableRequest) return %orig(connection, request, redirectResponse);
    YTApplyPlaybackSpoof(mutableRequest);
    request = mutableRequest;
    return %orig(connection, request, redirectResponse);
}

- (void)URLSession:(id)session
              task:(id)task
willPerformHTTPRedirection:(id)response
        newRequest:(id)newRequest
 completionHandler:(id)completionHandler
{
    if (![newRequest isKindOfClass:[NSURLRequest class]]) {
        %orig(session, task, response, newRequest, completionHandler);
        return;
    }
    NSURLRequest *typed = (NSURLRequest *)newRequest;
    if (!YTShouldMutateRequest(typed)) {
        %orig(session, task, response, newRequest, completionHandler);
        return;
    }

    NSMutableURLRequest *mutableRequest = [(NSURLRequest *)newRequest mutableCopy];
    if (!mutableRequest) {
        %orig(session, task, response, newRequest, completionHandler);
        return;
    }
    YTApplyPlaybackSpoof(mutableRequest);
    newRequest = mutableRequest;
    %orig(session, task, response, newRequest, completionHandler);
}

- (void)URLSession:(id)session task:(id)task needNewBodyStream:(id)completionHandler
{
    %orig(session, task, completionHandler);
}
%end


/*==========================================================================
 * EXPERIMENTAL PoToken BYPASS
 *========================================================================*/

@interface YTIIosPlaybackOnesieConfig : GPBMessage
- (BOOL)hasCommonConfig;
@end

%hook YTIIosPlaybackOnesieConfig
- (BOOL)hasCommonConfig
{
    if (!YTPlaybackFixSpoofEnabled()) return %orig;
    return NO;
}
%end


%ctor { %init; }
