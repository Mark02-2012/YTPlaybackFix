/*================================================================================
 * YouFixPlaybackIssues.xm (will change the name soon)
 * Credits: github.com/MorpheApp/morphe-patches and
 * github.com/AppropriateNet2928/YTLitePlusRenewed/tree/main/YouFixPlaybackIssues
 *================================================================================*/

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
//                          PART 2: PLAYBACK CLIENTS
// ============================================================================

/* Common parameters for TV_SABR and TV_SIMPLY */
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
    NSUserDefaults *defaults =
        [NSUserDefaults standardUserDefaults];

    /*
     * Deve corrispondere al default di Settings.xm.
     * Se la chiave non esiste, lo spoof rimane attivo.
     */
    if (![defaults objectForKey:YTPlaybackFixSpoofEnabledKey]) {
        return YES;
    }

    return [defaults boolForKey:YTPlaybackFixSpoofEnabledKey];
}

static NSInteger YTPlaybackFixSpoofClientMode(void)
{
    NSUserDefaults *defaults =
        [NSUserDefaults standardUserDefaults];

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

static NSString *YTPlaybackFixClientName(void)
{
    return YTPlaybackFixSpoofUsesTVSABR()
        ? kTVSABRClientName
        : kTVSimplyClientName;
}

static NSString *YTPlaybackFixClientVersion(void)
{
    return YTPlaybackFixSpoofUsesTVSABR()
        ? kTVSABRClientVersion
        : kTVSimplyClientVersion;
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

    NSMutableDictionary *headers =
        [NSMutableDictionary dictionary];

    headers[@"Accept-Language"] = @"*";
    headers[@"X-YouTube-Client-Name"] =
        YTPlaybackFixNumericClient();
    headers[@"X-YouTube-Client-Version"] =
        YTPlaybackFixClientVersion();
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
        id incomingVisitorObject =
            incomingClient[kJSONKeyVisitorData];

        if ([incomingVisitorObject
                isKindOfClass:[NSString class]])
        {
            NSString *incomingVisitor =
                (NSString *)incomingVisitorObject;

            if (incomingVisitor.length > 0)
            {
                self.visitorData = incomingVisitor;
            }
        }
    }

    NSMutableDictionary *client =
        [[YTDirectPlaybackClient activeClientContext]
            mutableCopy];

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

    NSString *path = URL.path ?: @"";

    return
        [path.lowercaseString
            containsString:endpoint.lowercaseString];
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
 * User-Agent già percent-encoded, come nella vecchia versione.
 */
static NSString *YTPercentEncodedTVUserAgent(void)
{
    return
        @"Mozilla%2F5.0%20%28PS4%3B%20Leanback%20Shell%29%20"
        @"Gecko%2F20100101%20Firefox%2F65.0%20"
        @"LeanbackShell%2F01.00.01.75%20"
        @"Sony%20PS4%2F%20%28PS4%2C%20%2C%20no%2C%20CH%29";
}

/*
 * Sostituisce un parametro esistente oppure lo aggiunge.
 * Evita NSURLComponents, che nel tuo SDK non era disponibile.
 */
static NSString *YTReplaceQueryParameter(
    NSString *urlString,
    NSString *parameter,
    NSString *value
)
{
    if (!urlString.length ||
        !parameter.length ||
        !value.length)
    {
        return urlString;
    }

    NSString *pattern =
        [NSString stringWithFormat:
            @"([?&])%@=[^&]*",
            parameter];

    NSRegularExpression *regex =
        [NSRegularExpression
            regularExpressionWithPattern:pattern
            options:0
            error:nil];

    if (!regex) {
        return urlString;
    }

    NSRange range =
        NSMakeRange(0, urlString.length);

    if ([regex
            numberOfMatchesInString:urlString
            options:0
            range:range] > 0)
    {
        NSString *replacement =
            [NSString stringWithFormat:
                @"$1%@=%@",
                parameter,
                value];

        return
            [regex stringByReplacingMatchesInString:urlString
                                            options:0
                                              range:range
                                    withTemplate:replacement];
    }

    /*
     * Il parametro non esiste: aggiungilo prima dell'eventuale fragment.
     */
    NSRange fragmentRange =
        [urlString rangeOfString:@"#"];

    NSString *baseString =
        fragmentRange.location == NSNotFound
            ? urlString
            : [urlString substringToIndex:fragmentRange.location];

    NSString *fragmentString =
        fragmentRange.location == NSNotFound
            ? @""
            : [urlString substringFromIndex:fragmentRange.location];

    NSString *separator =
        [baseString containsString:@"?"]
            ? @"&"
            : @"?";

    return
        [NSString stringWithFormat:
            @"%@%@%@=%@%@",
            baseString,
            separator,
            parameter,
            value,
            fragmentString];
}

static NSURL *YTRewriteInnertubeURL(NSURL *URL)
{
    if (!URL) {
        return URL;
    }

    NSString *urlString = URL.absoluteString;

    urlString =
        YTReplaceQueryParameter(
            urlString,
            @"c",
            YTPlaybackFixClientName()
        );

    urlString =
        YTReplaceQueryParameter(
            urlString,
            @"cver",
            YTPlaybackFixClientVersion()
        );

    NSURL *newURL =
        [NSURL URLWithString:urlString];

    return newURL ?: URL;
}

static NSURL *YTRewriteVideoPlaybackURL(NSURL *URL)
{
    if (!URL) {
        return URL;
    }

    NSString *urlString =
        YTReplaceQueryParameter(
            URL.absoluteString,
            @"user_agent",
            YTPercentEncodedTVUserAgent()
        );

    NSURL *newURL =
        [NSURL URLWithString:urlString];

    return newURL ?: URL;
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
        !request.URL)
    {
        return NO;
    }

    if (!YTIsInnertubeRequest(request.URL)) {
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
     * Il body è stato riscritto come JSON.
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
    if (!request || !request.URL) {
        return;
    }

    NSURL *URL = request.URL;

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
    if (!request ||
        !YTPlaybackFixSpoofEnabled() ||
        !request.URL)
    {
        return;
    }

    NSURL *URL = request.URL;

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
      cachePolicy:(unsigned long long)cachePolicy
  timeoutInterval:(double)timeoutInterval
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
    if (!YTPlaybackFixSpoofEnabled()) {
        return %orig(request);
    }

    if (![request isKindOfClass:[NSURLRequest class]]) {
        return %orig(request);
    }

    if (!YTShouldMutateRequest((NSURLRequest *)request)) {
        return %orig(request);
    }

    NSMutableURLRequest *mutableRequest = nil;

    if ([request
            isKindOfClass:[NSMutableURLRequest class]])
    {
        mutableRequest =
            (NSMutableURLRequest *)request;
    }
    else
    {
        mutableRequest =
            [(NSURLRequest *)request mutableCopy];
    }

    if (!mutableRequest) {
        return %orig(request);
    }

    YTApplyPlaybackSpoof(mutableRequest);

    request = mutableRequest;

    return %orig(request);
}

- (id)initWithRequest:(id)request
      configuration:(id)configuration
{
    if (!YTPlaybackFixSpoofEnabled()) {
        return %orig(request, configuration);
    }

    if (![request isKindOfClass:[NSURLRequest class]]) {
        return %orig(request, configuration);
    }

    if (!YTShouldMutateRequest((NSURLRequest *)request)) {
        return %orig(request, configuration);
    }

    NSMutableURLRequest *mutableRequest = nil;

    if ([request
            isKindOfClass:[NSMutableURLRequest class]])
    {
        mutableRequest =
            (NSMutableURLRequest *)request;
    }
    else
    {
        mutableRequest =
            [(NSURLRequest *)request mutableCopy];
    }

    if (!mutableRequest) {
        return %orig(request, configuration);
    }

    YTApplyPlaybackSpoof(mutableRequest);

    request = mutableRequest;

    return %orig(request, configuration);
}

- (void)updateMutableRequest:(id)request
{
    if (!YTPlaybackFixSpoofEnabled()) {
        %orig(request);
        return;
    }

    if (![request
            isKindOfClass:[NSMutableURLRequest class]])
    {
        %orig(request);
        return;
    }

    YTApplyPlaybackSpoof(
        (NSMutableURLRequest *)request
    );

    %orig(request);
}

- (void)setRequestValue:(id)value
       forHTTPHeaderField:(id)field
{
    if (!YTPlaybackFixSpoofEnabled()) {
        %orig(value, field);
        return;
    }

    if (![self
            respondsToSelector:
                @selector(mutableRequestForTesting)])
    {
        %orig(value, field);
        return;
    }

    NSMutableURLRequest *request =
        [self mutableRequestForTesting];

    if (!request) {
        %orig(value, field);
        return;
    }

    BOOL shouldMutate =
        YTShouldMutateRequest(request);

    /*
     * Prima esegue il setter originale, poi ripristina gli header.
     */
    %orig(value, field);

    if (shouldMutate)
    {
        YTApplyURLSpoof(request);
        YTApplyCustomHeaders(request);
    }
}

- (void)setBodyData:(id)data
{
    if (!YTPlaybackFixSpoofEnabled()) {
        %orig(data);
        return;
    }

    if (![self
            respondsToSelector:
                @selector(mutableRequestForTesting)])
    {
        %orig(data);
        return;
    }

    NSMutableURLRequest *request =
        [self mutableRequestForTesting];

    if (!request) {
        %orig(data);
        return;
    }

    BOOL shouldMutate =
        request.URL &&
        YTIsInnertubeRequest(request.URL);

    /*
     * Prima installa il body originale, poi lo riscrive.
     */
    %orig(data);

    if (shouldMutate)
    {
        YTApplyCustomBody(request);
        YTApplyCustomHeaders(request);
        YTApplyURLSpoof(request);
    }
}

%end


%hook GTMSessionFetcherSessionDelegateDispatcher

- (id)connection:(id)connection
willSendRequest:(id)request
redirectResponse:(id)redirectResponse
{
    if (!YTPlaybackFixSpoofEnabled()) {
        return %orig(connection, request, redirectResponse);
    }

    if (![request isKindOfClass:[NSURLRequest class]]) {
        return %orig(connection, request, redirectResponse);
    }

    if (!YTShouldMutateRequest((NSURLRequest *)request)) {
        return %orig(connection, request, redirectResponse);
    }

    NSMutableURLRequest *mutableRequest =
        [(NSURLRequest *)request mutableCopy];

    if (!mutableRequest) {
        return %orig(connection, request, redirectResponse);
    }

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
    if (!YTPlaybackFixSpoofEnabled()) {
        %orig(session, task, response, newRequest,
              completionHandler);
        return;
    }

    if (![newRequest
            isKindOfClass:[NSURLRequest class]])
    {
        %orig(session, task, response, newRequest,
              completionHandler);
        return;
    }

    if (!YTShouldMutateRequest((NSURLRequest *)newRequest)) {
        %orig(session, task, response, newRequest,
              completionHandler);
        return;
    }

    NSMutableURLRequest *mutableRequest =
        [(NSURLRequest *)newRequest mutableCopy];

    if (!mutableRequest) {
        %orig(session, task, response, newRequest,
              completionHandler);
        return;
    }

    YTApplyPlaybackSpoof(mutableRequest);

    newRequest = mutableRequest;

    %orig(session, task, response, newRequest,
          completionHandler);
}

- (void)URLSession:(id)session
              task:(id)task
 needNewBodyStream:(id)completionHandler
{
    %orig(session, task, completionHandler);
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
    if (!YTPlaybackFixSpoofEnabled()) {
        return %orig;
    }

    return NO;
}

%end

%ctor
{
    %init;
}
