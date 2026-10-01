/*
 * YouFixPlaybackIssues.xm - TV Client Spoofing Patch
 *
 * Cleaned Objective-C / Logos version.
 */

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <objc/message.h>
#import <objc/NSObjCRuntime.h>
#import "GPBMessage.h"


// ============================================================================
// CONFIG
// ============================================================================

static NSString * const kEndpointPlayer        = @"/player";
static NSString * const kEndpointNext          = @"/next";
static NSString * const kEndpointBrowse        = @"/browse";
static NSString * const kEndpointInitPlayback  = @"/initplayback";
static NSString * const kEndpointVideoPlayback = @"/videoplayback";

static NSString * const kJSONKeyContext       = @"context";
static NSString * const kJSONKeyClient        = @"client";
static NSString * const kJSONKeyVisitorData   = @"visitorData";
static NSString * const kJSONKeyVideoId       = @"videoId";
static NSString * const kJSONKeyBrowseId      = @"browseId";
static NSString * const kJSONKeyContinuation   = @"continuation";
static NSString * const kJSONKeyStreamingData = @"streamingData";

static NSString * const YTPlaybackFixSpoofEnabledKey =
    @"YTPlaybackFixSpoofEnabled";

static NSString * const YTPlaybackFixSpoofClientModeKey =
    @"YTPlaybackFixSpoofClientMode";


// ============================================================================
// PLAYBACK CLIENTS
// ============================================================================

static NSString * const kMorpheDeviceMake  = @"Sony";
static NSString * const kMorpheDeviceModel = @"PS4";
static NSString * const kMorpheOSName      = @"PlayStation 4";
static NSString * const kMorpheOSVersion   = @"7.20260707.07.00";
static NSString * const kMorpheClientPlatform = @"GAME_CONSOLE";

static NSString * const kMorpheUserAgent =
    @"Mozilla/5.0 (PS4; Leanback Shell) "
    @"Gecko/20100101 Firefox/65.0 "
    @"LeanbackShell/01.00.01.75 "
    @"Sony PS4/ (PS4, , no, CH)";

static NSString * const kTVSABRClientName =
    @"TVHTML5";

static NSString * const kTVSABRClientVersion =
    @"7.20260707.07.00";

static NSString * const kTVSABRNumericClient =
    @"7";

static NSString * const kTVSimplyClientName =
    @"TVHTML5_SIMPLY";

static NSString * const kTVSimplyClientVersion =
    @"1.1";

static NSString * const kTVSimplyNumericClient =
    @"75";


// ============================================================================
// SETTINGS
// ============================================================================

static BOOL YTPlaybackFixSpoofEnabled(void)
{
    NSUserDefaults *defaults =
        [NSUserDefaults standardUserDefaults];

    if ([defaults objectForKey:
            YTPlaybackFixSpoofEnabledKey] == nil) {
        return YES;
    }

    return [defaults
        boolForKey:YTPlaybackFixSpoofEnabledKey];
}

static NSInteger YTPlaybackFixSpoofClientMode(void)
{
    NSUserDefaults *defaults =
        [NSUserDefaults standardUserDefaults];

    if ([defaults objectForKey:
            YTPlaybackFixSpoofClientModeKey] == nil) {
        return 0;
    }

    return [defaults
        integerForKey:YTPlaybackFixSpoofClientModeKey];
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
    BOOL usesTVSABR =
        YTPlaybackFixSpoofUsesTVSABR();

    return @{
        @"clientName":
            usesTVSABR
                ? kTVSABRClientName
                : kTVSimplyClientName,

        @"clientVersion":
            usesTVSABR
                ? kTVSABRClientVersion
                : kTVSimplyClientVersion,

        @"hl": @"en",
        @"gl": @"USA",
        @"timeZone": @"UTC",
        @"utcOffsetMinutes": @0,

        @"deviceMake": kMorpheDeviceMake,
        @"deviceModel": kMorpheDeviceModel,
        @"osName": kMorpheOSName,
        @"osVersion": kMorpheOSVersion,
        @"clientPlatform": kMorpheClientPlatform,
        @"userAgent": kMorpheUserAgent
    };
}


// ============================================================================
// DYNAMIC OBJECT HELPERS
// ============================================================================

/*
 * YTIFormatStream is not fully declared in the available headers.
 *
 * The reference sources use objc_msgSend dynamically for the same reason,
 * so these helpers avoid compile-time checking of unknown selectors.
 */

static void YTCallObjectSetter(id object,
                               NSString *selectorName,
                               id value)
{
    if (!object || !selectorName) {
        return;
    }

    SEL selector =
        NSSelectorFromString(selectorName);

    if (![object respondsToSelector:selector]) {
        return;
    }

    ((void (*)(id, SEL, id))objc_msgSend)(
        object,
        selector,
        value
    );
}

static void YTCallIntSetter(id object,
                            NSString *selectorName,
                            int value)
{
    if (!object || !selectorName) {
        return;
    }

    SEL selector =
        NSSelectorFromString(selectorName);

    if (![object respondsToSelector:selector]) {
        return;
    }

    ((void (*)(id, SEL, int))objc_msgSend)(
        object,
        selector,
        value
    );
}


// ============================================================================
// YTIClientInfo
// ============================================================================

/*
 * The available declarations only expose YTIClientInfo as a forward
 * declaration. This minimal declaration allows Logos/Clang to compile
 * the hook without requiring the private YouTube header.
 */

@interface YTIClientInfo : NSObject
@end


%hook YTIClientInfo

- (id)_init
{
    id object = %orig;

    if (object) {
        @try {
            [object setValue:@75
                  forKey:@"clientName"];

            [object setValue:@"1.1"
                  forKey:@"clientVersion"];

            [object setValue:@"en"
                  forKey:@"hl"];

            [object setValue:@"USA"
                  forKey:@"gl"];

            [object setValue:kMorpheOSName
                  forKey:@"osName"];

            [object setValue:kMorpheOSVersion
                  forKey:@"osVersion"];

            [object setValue:kMorpheDeviceMake
                  forKey:@"deviceMake"];

            [object setValue:kMorpheDeviceModel
                  forKey:@"deviceModel"];

            [object setValue:@"UTC"
                  forKey:@"timeZone"];

            [object setValue:@0
                  forKey:@"utcOffsetMinutes"];
        }
        @catch (__unused NSException *exception) {
        }
    }

    return object;
}

- (int)clientName
{
    return 75;
}

- (NSString *)clientVersion
{
    return @"1.1";
}

- (NSString *)hl
{
    return @"en";
}

- (NSString *)gl
{
    return @"USA";
}

- (NSString *)osName
{
    return kMorpheOSName;
}

- (NSString *)osVersion
{
    return kMorpheOSVersion;
}

- (NSString *)deviceMake
{
    return kMorpheDeviceMake;
}

- (NSString *)deviceModel
{
    return kMorpheDeviceModel;
}

- (NSString *)timeZone
{
    return @"UTC";
}

- (int)utcOffsetMinutes
{
    return 0;
}

%end


// ============================================================================
// INNERTUBE SESSION
// ============================================================================

@interface YTDirectPlaybackClient : NSObject

+ (NSDictionary *)apiHeadersForVisitorData:
    (NSString *)visitorData;

+ (NSDictionary *)activeClientContext;

+ (NSDictionary *)contextBlueprint;

@end


@implementation YTDirectPlaybackClient

+ (NSDictionary *)apiHeadersForVisitorData:
    (NSString *)visitorData
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

    headers[@"Accept"] =
        @"application/json";

    headers[@"X-GOOG-API-FORMAT-VERSION"] =
        @"2";

    if (visitorData.length > 0) {
        headers[@"X-Goog-Visitor-Id"] =
            visitorData;
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


@interface YTInnertubeSession : NSObject

@property (nonatomic, copy)
    NSString *visitorData;

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
        shared =
            [[YTInnertubeSession alloc] init];
    });

    return shared;
}

- (NSDictionary *)buildPayloadWithIncomingBody:
    (NSDictionary *)incomingBody
{
    if (!YTPlaybackFixSpoofEnabled() ||
        ![incomingBody
            isKindOfClass:[NSDictionary class]]) {
        return nil;
    }

    NSMutableDictionary *mutatedBody =
        [incomingBody mutableCopy];

    NSDictionary *incomingContext =
        incomingBody[kJSONKeyContext];

    NSDictionary *incomingClient =
        [incomingContext
            isKindOfClass:[NSDictionary class]]
            ? incomingContext[kJSONKeyClient]
            : nil;

    if ([incomingClient
            isKindOfClass:[NSDictionary class]]) {

        id incomingVisitorObject =
            incomingClient[kJSONKeyVisitorData];

        if ([incomingVisitorObject
                isKindOfClass:[NSString class]]) {

            NSString *incomingVisitor =
                (NSString *)incomingVisitorObject;

            if (incomingVisitor.length > 0) {
                self.visitorData =
                    incomingVisitor;
            }
        }
    }

    NSMutableDictionary *mutableContext =
        [incomingContext
            isKindOfClass:[NSDictionary class]]
            ? [incomingContext mutableCopy]
            : [NSMutableDictionary dictionary];

    NSMutableDictionary *client =
        [[YTDirectPlaybackClient
            activeClientContext] mutableCopy];

    if (self.visitorData.length > 0) {
        client[kJSONKeyVisitorData] =
            self.visitorData;
    }

    mutableContext[kJSONKeyClient] =
        [client copy];

    mutatedBody[kJSONKeyContext] =
        [mutableContext copy];

    mutatedBody[@"alt"] =
        @"json";

    return [mutatedBody copy];
}

@end


// ============================================================================
// URL HELPERS
// ============================================================================

static BOOL YTPathContains(NSURL *URL,
                           NSString *endpoint)
{
    if (!URL ||
        !endpoint ||
        endpoint.length == 0) {
        return NO;
    }

    NSString *path =
        URL.path ?: @"";

    return [path.lowercaseString
        containsString:endpoint.lowercaseString];
}

static BOOL YTIsInnertubeRequest(NSURL *URL)
{
    return
        YTPathContains(URL, kEndpointPlayer) ||
        YTPathContains(URL, kEndpointNext) ||
        YTPathContains(URL, kEndpointBrowse) ||
        YTPathContains(URL, kEndpointInitPlayback);
}

static BOOL YTIsVideoPlaybackRequest(NSURL *URL)
{
    return YTPathContains(
        URL,
        kEndpointVideoPlayback
    );
}

static BOOL YTShouldMutateRequest(
    NSURLRequest *request)
{
    if (!request ||
        !YTPlaybackFixSpoofEnabled()) {
        return NO;
    }

    NSURL *URL =
        request.URL;

    return URL &&
        (YTIsInnertubeRequest(URL) ||
         YTIsVideoPlaybackRequest(URL));
}

static NSString *YTPercentEncodedTVUserAgent(void)
{
    return
        @"Mozilla%2F5.0%20%28PS4%3B%20Leanback%20Shell%29%20"
        @"Gecko%2F20100101%20Firefox%2F65.0%20"
        @"LeanbackShell%2F01.00.01.75%20"
        @"Sony%20PS4%2F%20%28PS4%2C%20%2C%20no%2C%20CH%29";
}

static NSString *YTReplaceQueryParameter(
    NSString *urlString,
    NSString *parameter,
    NSString *value)
{
    if (!urlString.length ||
        !parameter.length ||
        !value.length) {
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
        NSMakeRange(
            0,
            urlString.length
        );

    if ([regex
            numberOfMatchesInString:urlString
            options:0
            range:range] > 0) {

        NSString *replacement =
            [NSString stringWithFormat:
                @"$1%@=%@",
                parameter,
                value];

        return
            [regex
                stringByReplacingMatchesInString:urlString
                options:0
                range:range
                withTemplate:replacement];
    }

    NSRange fragmentRange =
        [urlString rangeOfString:@"#"];

    NSString *baseString =
        fragmentRange.location == NSNotFound
            ? urlString
            : [urlString
                substringToIndex:
                    fragmentRange.location];

    NSString *fragmentString =
        fragmentRange.location == NSNotFound
            ? @""
            : [urlString
                substringFromIndex:
                    fragmentRange.location];

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

    NSString *urlString =
        URL.absoluteString;

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

    urlString =
        YTReplaceQueryParameter(
            urlString,
            @"alt",
            @"json"
        );

    NSURL *newURL =
        [NSURL URLWithString:urlString];

    return newURL ?: URL;
}

static NSURL *YTRewriteVideoPlaybackURL(
    NSURL *URL)
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
// REQUEST MUTATION
// ============================================================================

static void YTApplyCustomHeaders(
    NSMutableURLRequest *request)
{
    if (!request ||
        !YTPlaybackFixSpoofEnabled()) {
        return;
    }

    NSDictionary *headers =
        [YTDirectPlaybackClient
            apiHeadersForVisitorData:
                [YTInnertubeSession
                    sharedSession].visitorData];

    [headers
        enumerateKeysAndObjectsUsingBlock:
            ^(NSString *key,
              NSString *value,
              BOOL *stop) {

        [request setValue:value
              forHTTPHeaderField:key];
    }];
}

static BOOL YTApplyCustomBody(
    NSMutableURLRequest *request)
{
    if (!request ||
        request.HTTPBody.length == 0 ||
        !request.URL) {
        return NO;
    }

    if (!YTIsInnertubeRequest(request.URL)) {
        return NO;
    }

    NSString *contentType =
        [request
            valueForHTTPHeaderField:@"Content-Type"]
            ?: @"application/json";

    if ([contentType.lowercaseString
            containsString:@"protobuf"]) {
        return NO;
    }

    NSError *error = nil;

    id parsedBody =
        [NSJSONSerialization
            JSONObjectWithData:request.HTTPBody
            options:0
            error:&error];

    if (error ||
        ![parsedBody
            isKindOfClass:[NSDictionary class]]) {
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

    request.HTTPBody =
        mutatedData;

    [request setValue:@"application/json"
        forHTTPHeaderField:@"Content-Type"];

    return YES;
}

static void YTApplyURLSpoof(
    NSMutableURLRequest *request)
{
    if (!request ||
        !request.URL) {
        return;
    }

    NSURL *URL =
        request.URL;

    if (YTPathContains(
            URL,
            kEndpointInitPlayback)) {

        NSURL *newURL =
            YTRewriteInnertubeURL(URL);

        if (newURL &&
            ![newURL isEqual:URL]) {
            request.URL =
                newURL;
        }

        URL =
            request.URL;
    }

    if (YTIsVideoPlaybackRequest(URL)) {

        NSURL *newURL =
            YTRewriteVideoPlaybackURL(URL);

        if (newURL &&
            ![newURL isEqual:URL]) {
            request.URL =
                newURL;
        }
    }
}

static void YTApplyPlaybackSpoof(
    NSMutableURLRequest *request)
{
    if (!request ||
        !YTPlaybackFixSpoofEnabled() ||
        !request.URL) {
        return;
    }

    NSURL *URL =
        request.URL;

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


// ============================================================================
// STREAMING DATA HELPERS
// ============================================================================

static NSArray *YTCreateTVFormats(
    NSString *videoId)
{
    if (videoId.length == 0) {
        return @[];
    }

    Class formatClass =
        NSClassFromString(@"YTIFormatStream");

    if (!formatClass) {
        return @[];
    }

    NSMutableArray *formats =
        [NSMutableArray array];

    NSString *manifestURLString =
        [NSString stringWithFormat:
            @"https://manifest.googlevideo.com/api/manifest/"
             "hls_variant/playlist/index.m3u8?video_id=%@",
            videoId];

    NSURL *manifestURL =
        [NSURL URLWithString:
            manifestURLString];

    if (!manifestURL) {
        return @[];
    }


    // ------------------------------------------------------------------------
    // 1080p
    // ------------------------------------------------------------------------

    id video1080 =
        [[formatClass alloc] init];

    if (video1080) {

        YTCallObjectSetter(
            video1080,
            @"setURL:",
            manifestURL
        );

        YTCallObjectSetter(
            video1080,
            @"setMimeType:",
            @"application/vnd.apple.mpegurl"
        );

        YTCallObjectSetter(
            video1080,
            @"setQualityLabel:",
            @"1080p"
        );

        YTCallIntSetter(
            video1080,
            @"setItag:",
            137
        );

        YTCallIntSetter(
            video1080,
            @"setHeight:",
            1080
        );

        YTCallIntSetter(
            video1080,
            @"setFps:",
            30
        );

        [formats addObject:video1080];
    }


    // ------------------------------------------------------------------------
    // 720p
    // ------------------------------------------------------------------------

    id video720 =
        [[formatClass alloc] init];

    if (video720) {

        YTCallObjectSetter(
            video720,
            @"setURL:",
            manifestURL
        );

        YTCallObjectSetter(
            video720,
            @"setMimeType:",
            @"application/vnd.apple.mpegurl"
        );

        YTCallObjectSetter(
            video720,
            @"setQualityLabel:",
            @"720p"
        );

        YTCallIntSetter(
            video720,
            @"setItag:",
            136
        );

        YTCallIntSetter(
            video720,
            @"setHeight:",
            720
        );

        YTCallIntSetter(
            video720,
            @"setFps:",
            30
        );

        [formats addObject:video720];
    }


    // ------------------------------------------------------------------------
    // Audio
    // ------------------------------------------------------------------------

    id audio =
        [[formatClass alloc] init];

    if (audio) {

        YTCallObjectSetter(
            audio,
            @"setURL:",
            manifestURL
        );

        YTCallObjectSetter(
            audio,
            @"setMimeType:",
            @"audio/mp4; codecs=mp4a.40.2"
        );

        YTCallIntSetter(
            audio,
            @"setItag:",
            140
        );

        [formats addObject:audio];
    }

    return [formats copy];
}


static id YTCreateTVStreamingData(
    NSString *videoId)
{
    Class streamingDataClass =
        NSClassFromString(@"YTIStreamingData");

    if (!streamingDataClass ||
        videoId.length == 0) {
        return nil;
    }

    id tvData =
        [[streamingDataClass alloc] init];

    if (!tvData) {
        return nil;
    }

    NSArray *formats =
        YTCreateTVFormats(videoId);

    if (formats.count > 0) {

        YTCallObjectSetter(
            tvData,
            @"setAdaptiveFormatsArray:",
            formats
        );

        YTCallObjectSetter(
            tvData,
            @"setFormatsArray:",
            formats
        );
    }

    return tvData;
}


static NSString *YTExtractVideoIdFromRequest(
    NSURL *URL)
{
    if (!URL) {
        return nil;
    }

    NSString *query =
        URL.query;

    if (!query.length) {
        return nil;
    }

    NSArray *components =
        [query
            componentsSeparatedByString:@"&"];

    for (NSString *component in components) {

        if ([component
                hasPrefix:@"v="]) {

            return
                [component
                    substringFromIndex:2];
        }

        if ([component
                hasPrefix:@"video_id="]) {

            return
                [component
                    substringFromIndex:
                        [@"video_id=" length]];
        }
    }

    return nil;
}


// ============================================================================
// HOOKS
// ============================================================================

%hook NSMutableURLRequest

- (id)initWithURL:(NSURL *)URL
      cachePolicy:(unsigned long long)cachePolicy
  timeoutInterval:(double)timeoutInterval
{
    id object = %orig;

    if (!object) {
        return object;
    }

    YTApplyPlaybackSpoof(
        (NSMutableURLRequest *)object
    );

    return object;
}

%end


// ============================================================================
// GTMSessionFetcher
// ============================================================================

@interface GTMSessionFetcher : NSObject

- (id)mutableRequestForTesting;

@end


%hook GTMSessionFetcher

- (id)initWithRequest:(id)request
{
    if (!YTPlaybackFixSpoofEnabled()) {
        return %orig(request);
    }

    if (![request
            isKindOfClass:[NSURLRequest class]]) {
        return %orig(request);
    }

    if (!YTShouldMutateRequest(
            (NSURLRequest *)request)) {
        return %orig(request);
    }

    NSMutableURLRequest *mutableRequest =
        nil;

    if ([request
            isKindOfClass:
                [NSMutableURLRequest class]]) {

        mutableRequest =
            (NSMutableURLRequest *)request;

    } else {

        mutableRequest =
            [(NSURLRequest *)request
                mutableCopy];
    }

    if (!mutableRequest) {
        return %orig(request);
    }

    YTApplyPlaybackSpoof(
        mutableRequest
    );

    request =
        mutableRequest;

    return %orig(request);
}

- (id)initWithRequest:(id)request
         configuration:(id)configuration
{
    if (!YTPlaybackFixSpoofEnabled()) {
        return %orig(
            request,
            configuration
        );
    }

    if (![request
            isKindOfClass:[NSURLRequest class]]) {
        return %orig(
            request,
            configuration
        );
    }

    if (!YTShouldMutateRequest(
            (NSURLRequest *)request)) {
        return %orig(
            request,
            configuration
        );
    }

    NSMutableURLRequest *mutableRequest =
        nil;

    if ([request
            isKindOfClass:
                [NSMutableURLRequest class]]) {

        mutableRequest =
            (NSMutableURLRequest *)request;

    } else {

        mutableRequest =
            [(NSURLRequest *)request
                mutableCopy];
    }

    if (!mutableRequest) {
        return %orig(
            request,
            configuration
        );
    }

    YTApplyPlaybackSpoof(
        mutableRequest
    );

    request =
        mutableRequest;

    return %orig(
        request,
        configuration
    );
}

- (void)updateMutableRequest:(id)request
{
    if (!YTPlaybackFixSpoofEnabled()) {
        %orig(request);
        return;
    }

    if (![request
            isKindOfClass:
                [NSMutableURLRequest class]]) {

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
                @selector(
                    mutableRequestForTesting)]) {

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

    %orig(value, field);

    if (shouldMutate) {
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
                @selector(
                    mutableRequestForTesting)]) {

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

    %orig(data);

    if (shouldMutate) {

        YTApplyCustomBody(request);
        YTApplyCustomHeaders(request);
        YTApplyURLSpoof(request);
    }
}

%end


// ============================================================================
// GTMSessionFetcherSessionDelegateDispatcher
// ============================================================================

%hook GTMSessionFetcherSessionDelegateDispatcher

- (id)connection:(id)connection
willSendRequest:(id)request
redirectResponse:(id)redirectResponse
{
    if (!YTPlaybackFixSpoofEnabled()) {

        return %orig(
            connection,
            request,
            redirectResponse
        );
    }

    if (![request
            isKindOfClass:[NSURLRequest class]]) {

        return %orig(
            connection,
            request,
            redirectResponse
        );
    }

    if (!YTShouldMutateRequest(
            (NSURLRequest *)request)) {

        return %orig(
            connection,
            request,
            redirectResponse
        );
    }

    NSMutableURLRequest *mutableRequest =
        [(NSURLRequest *)request
            mutableCopy];

    if (!mutableRequest) {

        return %orig(
            connection,
            request,
            redirectResponse
        );
    }

    YTApplyPlaybackSpoof(
        mutableRequest
    );

    request =
        mutableRequest;

    return %orig(
        connection,
        request,
        redirectResponse
    );
}

- (void)URLSession:(id)session
              task:(id)task
willPerformHTTPRedirection:(id)response
        newRequest:(id)newRequest
 completionHandler:(id)completionHandler
{
    if (!YTPlaybackFixSpoofEnabled()) {

        %orig(
            session,
            task,
            response,
            newRequest,
            completionHandler
        );

        return;
    }

    if (![newRequest
            isKindOfClass:[NSURLRequest class]]) {

        %orig(
            session,
            task,
            response,
            newRequest,
            completionHandler
        );

        return;
    }

    if (!YTShouldMutateRequest(
            (NSURLRequest *)newRequest)) {

        %orig(
            session,
            task,
            response,
            newRequest,
            completionHandler
        );

        return;
    }

    NSMutableURLRequest *mutableRequest =
        [(NSURLRequest *)newRequest
            mutableCopy];

    if (!mutableRequest) {

        %orig(
            session,
            task,
            response,
            newRequest,
            completionHandler
        );

        return;
    }

    YTApplyPlaybackSpoof(
        mutableRequest
    );

    newRequest =
        mutableRequest;

    %orig(
        session,
        task,
        response,
        newRequest,
        completionHandler
    );
}

- (void)URLSession:(id)session
              task:(id)task
 needNewBodyStream:(id)completionHandler
{
    %orig(
        session,
        task,
        completionHandler
    );
}

%end


// ============================================================================
// EXPERIMENTAL PoToken HOOK
// ============================================================================

@interface YTIIosPlaybackOnesieConfig : GPBMessage

- (BOOL)hasCommonConfig;

@end


%hook YTIIosPlaybackOnesieConfig

- (BOOL)hasCommonConfig
{
    if (!YTPlaybackFixSpoofEnabled()) {
        return %orig;
    }

    return NO;
}

%end


// ============================================================================
// STREAMING DATA REPLACEMENT
// ============================================================================

static id YTGetObjectProperty(id object, NSString *selectorName)
{
    if (!object || selectorName.length == 0) {
        return nil;
    }

    SEL selector = NSSelectorFromString(selectorName);

    if (![object respondsToSelector:selector]) {
        return nil;
    }

    return ((id (*)(id, SEL))objc_msgSend)(
        object,
        selector
    );
}


static NSString *YTGetVideoIdFromPlayerResponse(id response)
{
    if (!response) {
        return nil;
    }

    id playerConfig =
        YTGetObjectProperty(
            response,
            @"playerConfig"
        );

    if (playerConfig) {

        id videoId =
            YTGetObjectProperty(
                playerConfig,
                @"videoId"
            );

        if ([videoId isKindOfClass:[NSString class]] &&
            [(NSString *)videoId length] > 0) {

            return (NSString *)videoId;
        }
    }

    id videoDetails =
        YTGetObjectProperty(
            response,
            @"videoDetails"
        );

    if (videoDetails) {

        id videoId =
            YTGetObjectProperty(
                videoDetails,
                @"videoId"
            );

        if ([videoId isKindOfClass:[NSString class]] &&
            [(NSString *)videoId length] > 0) {

            return (NSString *)videoId;
        }
    }

    return nil;
}


%hook YTPlayerResponse

- (void)setStreamingData:(id)streamingData
{
    if (!YTPlaybackFixSpoofEnabled()) {
        %orig(streamingData);
        return;
    }

    NSString *videoId =
        YTGetVideoIdFromPlayerResponse(self);

    if (videoId.length > 0) {

        id replacement =
            YTCreateTVStreamingData(videoId);

        if (replacement) {
            %orig(replacement);
            return;
        }
    }

    %orig(streamingData);
}


- (id)streamingData
{
    id original = %orig;

    if (!YTPlaybackFixSpoofEnabled()) {
        return original;
    }

    /*
     * Recover the video ID from the player response.
     * We deliberately use objc_msgSend helpers because
     * YTPlayerResponse is only forward-declared here.
     */

    NSString *videoId =
        YTGetVideoIdFromPlayerResponse(self);

    if (videoId.length > 0) {

        id replacement =
            YTCreateTVStreamingData(videoId);

        if (replacement) {
            return replacement;
        }
    }

    return original;
}

%end

// ============================================================================
// YTIStreamingData
// ============================================================================

%hook YTIStreamingData

- (NSArray *)adaptiveFormatsArray
{
    return %orig;
}

%end


// ============================================================================
// PLAYABILITY
// ============================================================================

%hook YTIPlayabilityStatus

- (BOOL)isPlayable
{
    return YES;
}

- (BOOL)isPlayableInBackground
{
    return YES;
}

- (BOOL)isPlayableNowOrAfterUserAction
{
    return YES;
}

%end


// ============================================================================
// CONSTRUCTOR
// ============================================================================

%ctor
{
    %init;
}
