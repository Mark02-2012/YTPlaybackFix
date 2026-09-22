/*===========================================================================
 * YouFixPlaybackIssues.xm
 * Versione completa con selezione dinamica TV Simply / TV_SABR
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
//                          PART 2: MORPHE PLAYBACK CLIENTS
// ============================================================================

/* Parametri comuni a TV_SABR e TV_SIMPLY */
static NSString * const kMorpheDeviceMake     = @"Sony";
static NSString * const kMorpheDeviceModel    = @"PS4";
static NSString * const kMorpheOSName         = @"PlayStation 4";
static NSString * const kMorpheOSVersion      = @"";
static NSString * const kMorpheClientPlatform = @"GAME_CONSOLE";
static NSString * const kMorpheUserAgent =
    @"Mozilla/5.0 (PS4; Leanback Shell) "
      @"Gecko/20100101 Firefox/65.0 "
      @"LeanbackShell/01.00.01.75 "
      @"Sony PS4/ (PS4, , no, CH)";

/* TV_SABR */
static NSString * const kTVSABRClientName     = @"TVHTML5";
static NSString * const kTVSABRClientVersion  = @"7.20260707.07.00";
static NSString * const kTVSABRNumericClient  = @"7";

/* TV_SIMPLY */
static NSString * const kTVSimplyClientName    = @"TVHTML5_SIMPLY";
static NSString * const kTVSimplyClientVersion = @"1.1";
static NSString * const kTVSimplyNumericClient = @"75";


// ============================================================================
//                          PART 3: SETTINGS HELPERS
// ============================================================================

static BOOL YTPlaybackFixSpoofEnabled(void)
{
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];

    /*
     * Deve corrispondere al default usato in Settings.xm.
     * Se la chiave non esiste, lo spoof rimane attivo.
     */
    if (![defaults objectForKey:YTPlaybackFixSpoofEnabledKey]) {
        return YES;
    }

    return [defaults boolForKey:YTPlaybackFixSpoofEnabledKey];
}

static NSInteger YTPlaybackFixSpoofClientMode(void)
{
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];

    /*
     * 0 = TV Simply
     * 1 = TV_SABR
     * Qualsiasi valore non valido viene riportato a TV Simply.
     */
    if (![defaults objectForKey:YTPlaybackFixSpoofClientModeKey]) {
        return 0;
    }

    NSInteger mode =
        [defaults integerForKey:YTPlaybackFixSpoofClientModeKey];

    return mode == 1 ? 1 : 0;
}

static BOOL YTPlaybackFixSpoofUsesTVSABR(void)
{
    return YTPlaybackFixSpoofClientMode() == 1;
}

static NSDictionary *YTPlaybackFixClientContext(void)
{
    BOOL usesTVSABR = YTPlaybackFixSpoofUsesTVSABR();

    return @{
        @"clientName":
            usesTVSABR
                ? kTVSABRClientName
                : kTVSimplyClientName,

        @"clientVersion":
            usesTVSABR
                ? kTVSABRClientVersion
                : kTVSimplyClientVersion,

        @"hl":
            @"en",

        @"timeZone":
            @"UTC",

        @"utcOffsetMinutes":
            @0,

        @"deviceMake":
            kMorpheDeviceMake,

        @"deviceModel":
            kMorpheDeviceModel,

        @"osName":
            kMorpheOSName,

        @"osVersion":
            kMorpheOSVersion,

        @"clientPlatform":
            kMorpheClientPlatform,

        @"userAgent":
            kMorpheUserAgent
    };
}

static NSString *YTPlaybackFixNumericClient(void)
{
    return YTPlaybackFixSpoofUsesTVSABR()
        ? kTVSABRNumericClient
        : kTVSimplyNumericClient;
}

static NSString *YTPlaybackFixUserAgent(void)
{
    return kMorpheUserAgent;
}


// ============================================================================
//                          PART 4: PLAYBACK CLIENT
// ============================================================================

@interface YTDirectPlaybackClient : NSObject

+ (NSDictionary *)apiHeadersForVisitorData:(NSString *)visitorData;
+ (NSDictionary *)activeClientContext;
+ (NSDictionary *)contextBlueprint;

@end

@implementation YTDirectPlaybackClient

+ (NSDictionary *)apiHeadersForVisitorData:(NSString *)visitorData
{
    if (!YTPlaybackFixSpoofEnabled()) {
        return @{};
    }

    NSDictionary *client = YTPlaybackFixClientContext();
    NSMutableDictionary *headers =
        [NSMutableDictionary dictionary];

    headers[@"Accept-Language"] = @"*";
    headers[@"X-YouTube-Client-Name"] =
        YTPlaybackFixNumericClient();

    headers[@"X-YouTube-Client-Version"] =
        client[@"clientVersion"];

    headers[@"User-Agent"] =
        YTPlaybackFixUserAgent();

    headers[@"Origin"] =
        @"https://www.youtube.com";

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
    return @{
        kJSONKeyContext:
            [self activeClientContext]
    };
}

@end


// ============================================================================
//                          PART 5: INNERTUBE SESSION
// ============================================================================

@interface YTInnertubeSession : NSObject

@property (nonatomic, copy) NSString *visitorData;

+ (instancetype)sharedSession;
- (NSDictionary *)buildPayloadWithIncomingBody:
    (NSDictionary *)incomingBody;

@end

@implementation YTInnertubeSession

+ (instancetype)sharedSession
{
    static YTInnertubeSession *shared = nil;
    static dispatch_once_t onceToken;

    dispatch_once(&onceToken, ^{
        shared = [[YTInnertubeSession alloc] init];
    });

    return shared;
}

- (NSDictionary *)buildPayloadWithIncomingBody:
    (NSDictionary *)incomingBody
{
    if (!YTPlaybackFixSpoofEnabled() ||
        ![incomingBody isKindOfClass:[NSDictionary class]])
    {
        return nil;
    }

    NSMutableDictionary *mutatedBody =
        [incomingBody mutableCopy];

    NSDictionary *incomingContext =
        incomingBody[kJSONKeyContext];

    NSMutableDictionary *mutableContext =
        [incomingContext isKindOfClass:[NSDictionary class]]
            ? [incomingContext mutableCopy]
            : [NSMutableDictionary dictionary];

    NSDictionary *incomingClient =
        incomingContext[kJSONKeyClient];

    /*
     * Cattura il visitorData dalla richiesta originale prima di sostituirla.
     */
    if ([incomingClient isKindOfClass:[NSDictionary class]])
    {
        id incomingVisitor =
            incomingClient[kJSONKeyVisitorData];

        if ([incomingVisitor isKindOfClass:[NSString class]] &&
            incomingVisitor.length > 0)
        {
            self.visitorData = incomingVisitor;
        }
    }

    NSMutableDictionary *client =
        (NSMutableDictionary *)
        [[YTDirectPlaybackClient activeClientContext] mutableCopy];

    if (self.visitorData.length > 0)
    {
        client[kJSONKeyVisitorData] =
            self.visitorData;
    }

    mutableContext[kJSONKeyClient] =
        [client copy];

    mutatedBody[kJSONKeyContext] =
        [mutableContext copy];

    return [mutatedBody copy];
}

@end


// ============================================================================
//                          PART 6: URL HELPERS
// ============================================================================

static BOOL YTPathContains(NSURL *URL, NSString *endpoint)
{
    if (!URL || !endpoint || endpoint.length == 0) {
        return NO;
    }

    NSString *path = URL.path.lowercaseString;

    return
        [path containsString:endpoint.lowercaseString];
}

static BOOL YTIsInnertubeRequest(NSURL *URL)
{
    return
        YTPathContains(URL, kEndpointPlayer)       ||
        YTPathContains(URL, kEndpointNext)         ||
        YTPathContains(URL, kEndpointBrowse)       ||
        YTPathContains(URL, kEndpointInitPlayback);
}

static BOOL YTIsVideoPlaybackRequest(NSURL *URL)
{
    return YTPathContains(URL, kEndpointVideoPlayback);
}

static BOOL YTShouldMutateRequest(NSURLRequest *request)
{
    if (!request || !YTPlaybackFixSpoofEnabled()) {
        return NO;
    }

    NSURL *URL = request.URL;

    return
        URL &&
        (
            YTIsInnertubeRequest(URL) ||
            YTIsVideoPlaybackRequest(URL)
        );
}

/*
 * Sostituisce un parametro esistente oppure lo aggiunge.
 * È più sicuro della regex usata nella vecchia versione.
 */
static NSURL *YTURLBySettingQueryParameter(
    NSURL *URL,
    NSString *parameter,
    NSString *value
)
{
    if (!URL ||
        !parameter ||
        parameter.length == 0 ||
        !value ||
        value.length == 0)
    {
        return URL;
    }

    NSURLComponents *components =
        [NSURLComponents
            componentsWithURL:URL
            includingQueryItems:YES];

    if (!components) {
        return URL;
    }

    NSMutableArray<NSURLQueryItem *> *queryItems =
        [components.queryItems mutableCopy];

    if (!queryItems) {
        queryItems = [NSMutableArray array];
    }

    NSMutableArray<NSURLQueryItem *> *filteredItems =
        [NSMutableArray array];

    for (NSURLQueryItem *item in queryItems)
    {
        if (!item.name ||
            [item.name caseInsensitiveCompare:parameter] != NSOrderedSame)
        {
            [filteredItems addObject:item];
        }
    }

    NSURLQueryItem *newItem =
        [NSURLQueryItem
            queryItemWithName:parameter
            value:value];

    [filteredItems addObject:newItem];
    components.queryItems = filteredItems;

    NSURL *rewrittenURL = components.URL;

    return rewrittenURL ?: URL;
}

static NSURL *YTRewriteInnertubeURL(NSURL *URL)
{
    if (!URL) {
        return URL;
    }

    NSDictionary *client =
        YTPlaybackFixClientContext();

    NSURL *newURL =
        YTURLBySettingQueryParameter(
            URL,
            @"c",
            client[@"clientName"]
        );

    newURL =
        YTURLBySettingQueryParameter(
            newURL,
            @"cver",
            client[@"clientVersion"]
        );

    return newURL ?: URL;
}

static NSURL *YTRewriteVideoPlaybackURL(NSURL *URL)
{
    return
        YTURLBySettingQueryParameter(
            URL,
            @"user_agent",
            YTPlaybackFixUserAgent()
        );
}


// ============================================================================
//                          PART 7: REQUEST MUTATION
// ============================================================================

static void YTApplyCustomHeaders(
    NSMutableURLRequest *request
)
{
    if (!request || !YTPlaybackFixSpoofEnabled()) {
        return;
    }

    NSDictionary *headers =
        [YTDirectPlaybackClient
            apiHeadersForVisitorData:
                [YTInnertubeSession sharedSession].visitorData];

    [headers
        enumerateKeysAndObjectsUsingBlock:
            ^(NSString *key,
              id value,
              BOOL *stop)
    {
        [request
            setValue:value
            forHTTPHeaderField:key];
    }];
}

/*
 * Riscrive esclusivamente body JSON.
 * I body protobuf vengono lasciati intatti.
 */
static BOOL YTApplyCustomBody(
    NSMutableURLRequest *request
)
{
    if (!request ||
        request.HTTPBody.length == 0 ||
        !YTIsInnertubeRequest(request.URL))
    {
        return NO;
    }

    NSString *contentType =
        [request
            valueForHTTPHeaderField:@"Content-Type"] ?: @"";

    if ([contentType.lowercaseString
            containsString:@"protobuf"])
    {
        return NO;
    }

    NSError *error = nil;

    id parsedBody =
        [NSJSONSerialization
            JSONObjectWithData:request.HTTPBody
            options:0
            error:&error];

    if (error ||
        ![parsedBody isKindOfClass:[NSDictionary class]])
    {
        return NO;
    }

    NSDictionary *mutatedJSON =
        [[YTInnertubeSession sharedSession]
            buildPayloadWithIncomingBody:
                parsedBody];

    if (!mutatedJSON) {
        return NO;
    }

    NSData *mutatedData =
        [NSJSONSerialization
            dataWithJSONObject:mutatedJSON
            options:0
            error:nil];

    if (!mutatedData) {
        return NO;
    }

    request.HTTPBody = mutatedData;

    /*
     * Il body è stato serializzato come JSON: rendiamo coerente
     * il Content-Type. Non sovrascriviamo qui gli header del client.
     */
    [request
        setValue:@"application/json"
        forHTTPHeaderField:@"Content-Type"];

    return YES;
}

static void YTApplyURLSpoof(
    NSMutableURLRequest *request
)
{
    if (!request) {
        return;
    }

    NSURL *URL = request.URL;

    if (!URL) {
        return;
    }

    if (YTPathContains(URL, kEndpointInitPlayback))
    {
        NSURL *newURL =
            YTRewriteInnertubeURL(URL);

        if (newURL && ![newURL isEqual:URL])
        {
            request.URL = newURL;
        }

        URL = request.URL;
    }

    if (YTIsVideoPlaybackRequest(URL))
    {
        NSURL *newURL =
            YTRewriteVideoPlaybackURL(URL);

        if (newURL && ![newURL isEqual:URL])
        {
            request.URL = newURL;
        }
    }
}

static void YTApplyPlaybackSpoof(
    NSMutableURLRequest *request
)
{
    if (!request || !YTPlaybackFixSpoofEnabled()) {
        return;
    }

    NSURL *URL = request.URL;

    if (!URL) {
        return;
    }

    if (YTIsInnertubeRequest(URL))
    {
        YTApplyCustomBody(request);
        YTApplyCustomHeaders(request);
        YTApplyURLSpoof(request);
        return;
    }

    if (YTIsVideoPlaybackRequest(URL))
    {
        YTApplyCustomHeaders(request);
        YTApplyURLSpoof(request);
    }
}


// ============================================================================
//                          PART 8: HOOKS
// ============================================================================

%hook NSMutableURLRequest

- (id)initWithURL:(NSURL *)URL
{
    self = %orig;

    if (!self) {
        return self;
    }

    YTApplyPlaybackSpoof(self);

    return self;
}

- (id)initWithURL:(NSURL *)URL
      cachePolicy:(NSURLRequestCachePolicy)cachePolicy
  timeoutInterval:(NSTimeInterval)timeoutInterval
{
    self = %orig;

    if (!self) {
        return self;
    }

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
    if (![request isKindOfClass:[NSURLRequest class]])
    {
        return %orig;
    }

    NSURLRequest *typedRequest =
        (NSURLRequest *)request;

    if (!YTShouldMutateRequest(typedRequest))
    {
        return %orig;
    }

    NSMutableURLRequest *mutableRequest = nil;

    if ([typedRequest
            isKindOfClass:[NSMutableURLRequest class]])
    {
        mutableRequest =
            (NSMutableURLRequest *)typedRequest;
    }
    else
    {
        mutableRequest =
            [typedRequest mutableCopy];
    }

    if (!mutableRequest)
    {
        return %orig;
    }

    YTApplyPlaybackSpoof(mutableRequest);

    request = mutableRequest;

    return %orig(request);
}

- (id)initWithRequest:(id)request
      configuration:(id)configuration
{
    if (![request isKindOfClass:[NSURLRequest class]])
    {
        return %orig(request, configuration);
    }

    NSURLRequest *typedRequest =
        (NSURLRequest *)request;

    if (!YTShouldMutateRequest(typedRequest))
    {
        return %orig(request, configuration);
    }

    NSMutableURLRequest *mutableRequest = nil;

    if ([typedRequest
            isKindOfClass:[NSMutableURLRequest class]])
    {
        mutableRequest =
            (NSMutableURLRequest *)typedRequest;
    }
    else
    {
        mutableRequest =
            [typedRequest mutableCopy];
    }

    if (!mutableRequest)
    {
        return %orig(request, configuration);
    }

    YTApplyPlaybackSpoof(mutableRequest);

    request = mutableRequest;

    return %orig(request, configuration);
}

- (void)updateMutableRequest:(id)request
{
    if (![request
            isKindOfClass:[NSMutableURLRequest class]])
    {
        %orig;
        return;
    }

    YTApplyPlaybackSpoof(
        (NSMutableURLRequest *)request
    );

    %orig;
}

- (void)setRequestValue:(id)value
       forHTTPHeaderField:(id)field
{
    if (!YTPlaybackFixSpoofEnabled())
    {
        %orig;
        return;
    }

    if (![self
            respondsToSelector:
                @selector(mutableRequestForTesting)])
    {
        %orig;
        return;
    }

    NSMutableURLRequest *request =
        [self mutableRequestForTesting];

    if (!request)
    {
        %orig;
        return;
    }

    BOOL shouldMutate =
        YTShouldMutateRequest(request);

    /*
     * Prima lasciamo eseguire il setter originale.
     * Dopo, ripristiniamo gli header del client spoofato.
     */
    %orig;

    if (shouldMutate)
    {
        YTApplyCustomHeaders(request);
    }
}

- (void)setBodyData:(id)data
{
    if (![self
            respondsToSelector:
                @selector(mutableRequestForTesting)])
    {
        %orig;
        return;
    }

    NSMutableURLRequest *request =
        [self mutableRequestForTesting];

    if (!request)
    {
        %orig;
        return;
    }

    BOOL shouldMutate =
        YTShouldMutateRequest(request);

    /*
     * Prima installiamo il body originale, poi lo riscriviamo.
     */
    %orig;

    if (shouldMutate)
    {
        YTApplyCustomBody(request);
        YTApplyCustomHeaders(request);
    }
}

%end


%hook GTMSessionFetcherSessionDelegateDispatcher

- (id)connection:(id)connection
      willSendRequest:(id)request
    redirectResponse:(id)redirectResponse
{
    if (![request isKindOfClass:[NSURLRequest class]])
    {
        return %orig;
    }

    NSURLRequest *typedRequest =
        (NSURLRequest *)request;

    if (!YTShouldMutateRequest(typedRequest))
    {
        return %orig;
    }

    NSMutableURLRequest *mutableRequest =
        [typedRequest mutableCopy];

    if (!mutableRequest)
    {
        return %orig;
    }

    YTApplyPlaybackSpoof(mutableRequest);

    request = mutableRequest;

    return %orig(request);
}

- (void)URLSession:(id)session
              task:(id)task
willPerformHTTPRedirection:(id)response
        newRequest:(id)newRequest
 completionHandler:(id)completionHandler
{
    if (![newRequest
            isKindOfClass:[NSURLRequest class]])
    {
        %orig;
        return;
    }

    NSURLRequest *typedRequest =
        (NSURLRequest *)newRequest;

    if (!YTShouldMutateRequest(typedRequest))
    {
        %orig;
        return;
    }

    NSMutableURLRequest *mutableRequest =
        [typedRequest mutableCopy];

    if (!mutableRequest)
    {
        %orig;
        return;
    }

    YTApplyPlaybackSpoof(mutableRequest);

    newRequest = mutableRequest;

    %orig;
}

- (void)URLSession:(id)session
              task:(id)task
 needNewBodyStream:(id)completionHandler
{
    %orig;
}

%end


// ============================================================================
//                    PART 9: EXPERIMENTAL PoToken HOOK
// ============================================================================

@interface YTIIosPlaybackOnesieConfig : GPBMessage
- (BOOL)hasCommonConfig;
@end

%hook YTIIosPlaybackOnesieConfig

- (BOOL)hasCommonConfig
{
    /*
     * Il comportamento sperimentale viene disattivato insieme
     * allo spoof principale.
     */
    if (!YTPlaybackFixSpoofEnabled())
    {
        return %orig;
    }

    return NO;
}

%end

%ctor
{
    %init;
}
