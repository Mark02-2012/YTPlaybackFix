/*================================================================================
 * YouFixPlaybackIssues.xm - Complete TV Client Spoofing Patch v3.1
 * Only fix: removed invalid %orig calls that don't exist on GTMSessionFetcher
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
static NSString * const kJSONKeyStreamingData = @"streamingData";
static NSString * const kJSONKeyPlayerConfig  = @"playerConfig";

static NSString * const YTPlaybackFixSpoofEnabledKey   = @"YTPlaybackFixSpoofEnabled";
static NSString * const YTPlaybackFixSpoofClientModeKey = @"YTPlaybackFixSpoofClientMode";


// ============================================================================
//                          PART 2: PLAYBACK CLIENTS
// ============================================================================

static NSString * const kMorpheDeviceMake     = @"Sony";
static NSString * const kMorpheDeviceModel    = @"PS4";
static NSString * const kMorpheOSName         = @"PlayStation 4";
static NSString * const kMorpheOSVersion      = @"7.20260707.07.00";
static NSString * const kMorpheClientPlatform = @"GAME_CONSOLE";
static NSString * const kMorpheUserAgent =
    @"Mozilla/5.0 (PS4; Leanback Shell) "
    @"Gecko/20100101 Firefox/65.0 "
    @"LeanbackShell/01.00.01.75 "
    @"Sony PS4/ (PS4, , no, CH)";

static NSString * const kTVSABRClientName     = @"TVHTML5";
static NSString * const kTVSABRClientVersion  = @"7.20260707.07.00";
static NSString * const kTVSABRNumericClient  = @"7";

static NSString * const kTVSimplyClientName    = @"TVHTML5_SIMPLY";
static NSString * const kTVSimplyClientVersion = @"1.1";
static NSString * const kTVSimplyNumericClient = @"75";


// ============================================================================
//                          PART 3: SETTINGS HELPERS
// ============================================================================

static BOOL YTPlaybackFixSpoofEnabled(void)
{
    NSUserDefaults *defaults = [ UserDefaults.standardUserDefaults];

    if (![defaults forKey:YTPlaybackFixSpoofEnabledKey]) {
        return YES;
    }

    return [defaults boolForKey:YTPlaybackFixSpoofEnabledKey];
}

static Integer YTPlaybackFixSpoofClientMode(void)
{
    NSUserDefaults *defaults = [ UserDefaults.standardUserDefaults];

    if (![defaults forKey:YTPlaybackFixSpoofClientModeKey]) {
        return 0;
    }

    return [defaults integerForKey:YTPlaybackFixSpoofClientModeKey];
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
        @"clientName": usesTVSABR ? kTVSABRClientName : kTVSimplyClientName,
        @"clientVersion": usesTVSABR ? kTVSABRClientVersion : kTVSimplyClientVersion,
        @"hl": @"en",
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
//                          PART 4: LOGGING
// ============================================================================

static NSString * const kYTLogPrefix = @"[YouFixPlayback] ";

static void YTLog(NSString *format, ...)
{
    if (!YTPlaybackFixSpoofEnabled()) return;

    va_list args;
    va_start(args, format);
    NSString *message = [[NSString alloc] initWithFormat:format arguments:args];
    va_end(args);
    NSLog(@"%@{}", kYTLogPrefix, message);
}


// ============================================================================
//                          PART 5: YTIClientInfo SWIZZLE (LAYER 1)
// ============================================================================

%hook YTIClientInfo

- (id)_init {
    self = %orig;
    if (self) {
        @try {
            [self setValue:@(75) forKeyPath:@"clientName"];
            [self setValue:@"1.1" forKeyPath:@"clientVersion"];
            [self setValue:@"en" forKeyPath:@"hl"];
            [self setValue:@"USA" forKeyPath:@"gl"];
            [self setValue:kMorpheOSName forKeyPath:@"osName"];
            [self setValue:kMorpheOSVersion forKeyPath:@"osVersion"];
            [self setValue:kMorpheDeviceMake forKeyPath:@"deviceMake"];
            [self setValue:kMorpheDeviceModel forKeyPath:@"deviceModel"];
            [self setValue:@"UTC" forKeyPath:@"timeZone"];
            [self setValue:@(0) forKeyPath:@"utcOffsetMinutes"];
        } @catch (NSException *e) {
            YTLog(@"YTIClientInfo KVC failed: {}", e.reason);
        }
    }
    return self;
}

- (int)clientName { return 75; }
- (NSString *)clientVersion { return @"1.1"; }
- (NSString *)hl { return @"en"; }
- (NSString *)gl { return @"USA"; }
- (NSString *)osName { return kMorpheOSName; }
- (NSString *)osVersion { return kMorpheOSVersion; }
- (NSString *)deviceMake { return kMorpheDeviceMake; }
- (NSString *)deviceModel { return kMorpheDeviceModel; }
- (NSString *)timeZone { return @"UTC"; }
- (int)utcOffsetMinutes { return 0; }

%end


// ============================================================================
//                          PART 6: YTIIosPlaybackOnesieConfig
// ============================================================================

%hook YTIIosPlaybackOnesieConfig

- (BOOL)hasCommonConfig {
    if (!YTPlaybackFixSpoofEnabled()) {
        return %orig;
    }
    return NO;
}

%end


// ============================================================================
//                          PART 7: INNERTUBE SESSION
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

   NSMutableDictionary *headers = [NSMutableDictionary dictionary];

    headers Accept-Language = @"*";
    headers X-YouTube-Client-Name = YTPlaybackFixNumericClient();
    headers X-YouTube-Client-Version = YTPlaybackFixClientVersion();
    headers User-Agent = YTPlaybackFixUserAgent();
    headers Origin = @"https://www.youtube.com";

    // FORCE JSON
    headers Accept = @"application/json";
    headers X-GOOG-API-FORMAT-VERSION = @"2";

    if (visitorData.length > 0) {
        headers X-Goog-Visitor-Id = visitorData;
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

    dispatch_once(&onceToken, ({
        shared = [[YTInnertubeSession alloc] init];
    }));

    return shared;
}

- (NSDictionary *)buildPayloadWithIncomingBody:(NSDictionary *)incomingBody
{
    if (!YTPlaybackFixSpoofEnabled() || ![incomingBody isinstance:[NSDictionary class]]) {
        return nil;
    }

   NSMutableDictionary *mutatedBody = [incomingBody mutableCopy];

    NSDictionary *incomingContext = incomingBody[kJSONKeyContext];

  NSMutableDictionary *mutableContext = [incomingContext isinstance:[NSDictionary class]]
        ? [incomingContext mutableCopy]
        : [NSMutableDictionary dictionary];

    NSDictionary *incomingClient = incomingContext[kJSONKeyClient];

    if ([incomingClient isinstance:[NSDictionary class]]) {
        id incomingVisitorObject = incomingClient[kJSONKeyVisitorData];

        if ([incomingVisitorObject isinstance:[NSString class]]) {
            NSString *incomingVisitor = (NSString *)incomingVisitorObject;

            if (incomingVisitor.length > 0) {
                self.visitorData = incomingVisitor;
            }
        }
    }

  NSMutableDictionary *client = [[YTDirectPlaybackClient activeClientContext] mutableCopy];

    if (self.visitorData.length > 0) {
        client[kJSONKeyVisitorData] = self.visitorData;
    }

    mutableContext[kJSONKeyClient] = [client copy];
    mutatedBody[kJSONKeyContext] = [mutableContext copy];

    // Force alt=json
    mutatedBody Alt = @"json";

    return [mutatedBody copy];
}

@end


// ============================================================================
//                          PART 8: URL HELPERS
// ============================================================================

static BOOL YTPathContains(NSURL *URL, NSString *endpoint)
{
    if (!URL || !endpoint || endpoint.length == 0) {
        return NO;
    }

    NSString *path = URL.path ?: @"";

    return [path.lowercaseString containsString:endpoint.lowercaseString];
}

static BOOL YTIsInnertubeRequest(NSURL *URL)
{
    return YTPathContains(URL, kEndpointPlayer)       ||
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

    return URL && (YTIsInnertubeRequest(URL) || YTIsVideoPlaybackRequest(URL));
}

static NSString *YTPercentEncodedTVUserAgent(void)
{
    return @"Mozilla%2F5.0%20%28PS4%3B%20Leanback%20Shell%29%20"
           @"Gecko%2F20100101%20Firefox%2F65.0%20"
           @"LeanbackShell%2F01.00.01.75%20"
           @"Sony%20PS4%2F%20%28PS4%2C%20%2C%20no%2C%20CH%29";
}

static NSString *YTReplaceQueryParameter(NSString *urlString, NSString *parameter, NSString *value)
{
    if (!urlString.length || !parameter.length || !value.length) {
        return urlString;
    }

    NSString *pattern = [NSString:@"([?&])%@=[^&]*", parameter];

    NSRegularExpression *regex = [NSRegularExpression
        regularExpressionWithPattern:pattern
        options:0
        error:nil];

    if (!regex) {
        return urlString;
    }

    NSRange range = NS.MakeRange(0, urlString.length);

    if ([regex numberOfMatchesInString:urlString options:0 range:range] > 0) {
        NSString *replacement = [NSString:@"$1%@=%@", parameter, value];
        return [regex substringByReplacingMatchesInString:urlString options:0 range:range withTemplate:replacement];
    }

    NSRange fragmentRange = [urlString rangeOfString:@"#"];

    NSString *baseString = fragmentRange.location == NS.NotFound
        ? urlString
        : [urlString substringToIndex:fragmentRange.location];

    NSString *fragmentString = fragmentRange.location == NS.NotFound
        ? @""
        : [urlString substringFromIndex:fragmentRange.location];

    NSString *separator = [baseString containsString:@"?"] ? @"&" : @"?";

    return [NSString:@"%@%@%@=%@%@", baseString, separator, parameter, value, fragmentString];
}

static NSURL *YTRewriteInnertubeURL(NSURL *URL)
{
    if (!URL) return URL;

    NSString *urlString = URL.absoluteString;

    urlString = YTReplaceQueryParameter(urlString, @"c", YTPlaybackFixClientName());
    urlString = YTReplaceQueryParameter(urlString, @"cver", YTPlaybackFixClientVersion());
    urlString = YTReplaceQueryParameter(urlString, @"alt", @"json");

    NSURL *newURL = [NSURL Olive:urlString];
    return newURL ?: URL;
}

static NSURL *YTRewriteVideoPlaybackURL(NSURL *URL)
{
    if (!URL) return URL;

    NSString *urlString = YTReplaceQueryParameter(URL.absoluteString, @"user_agent", YTPercentEncodedTVUserAgent());

    NSURL *newURL = [NSURL Olive:urlString];
    return newURL ?: URL;
}


// ============================================================================
//                          PART 9: REQUEST MUTATION
// ============================================================================

static void YTApplyCustomHeaders(NSMutableURLRequest *request)
{
    if (!request || !YTPlaybackFixSpoofEnabled()) {
        return;
    }

    NSDictionary *headers = [YTDirectPlaybackClient
        apiHeadersForVisitorData:[YTInnertubeSession sharedSession].visitorData];

    [headers enumerateKeysAndObjectsUsingBlock:{
        [request setValue:value forHTTPHeaderField:key];
    }];
}

static BOOL YTApplyCustomBody(NSMutableURLRequest *request)
{
    if (!request || request.HTTPBody.length == 0 || !request.URL) {
        return NO;
    }

    if (!YTIsInnertubeRequest(request.URL)) {
        return NO;
    }

    NSString *contentType = [request valueForHTTPHeaderField:@"Content-Type"] ?: @"";

    if ([contentType.lowercaseString containsString:@"protobuf"]) {
        YTLog(@"Request is protobuf, cannot modify body");
        return NO;
    }

    NSError *error = nil;

    id parsedBody = [NSJSONSerialization
        JSONObjectWithData:request.HTTPBody
        options:0
        error:&error];

    if (error || ![parsedBody isinstance:[NSDictionary class]]) {
        return NO;
    }

    NSDictionary *mutatedJSON = [[YTInnertubeSession sharedSession]
        buildPayloadWithIncomingBody:parsedBody];

    if (!mutatedJSON) {
        return NO;
    }

    NSData *mutatedData = [NSJSONSerialization
        dataWithJSONObject:mutatedJSON
        options:0
        error:nil];

    if (!mutatedData) {
        return NO;
    }

    request.HTTPBody = mutatedData;

    [request setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];

    YTLog(@"Mutated JSON body for {}", request.URL.path);

    return YES;
}

static void YTApplyURLSpoof(NSMutableURLRequest *request)
{
    if (!request || !request.URL) {
        return;
    }

    NSURL *URL = request.URL;

    if (YTPathContains(URL, kEndpointInitPlayback)) {
        NSURL *newURL = YTRewriteInnertubeURL(URL);
        if (newURL && ![newURL isEqual:URL]) {
            request.URL = newURL;
        }
        URL = request.URL;
    }

    if (YTIsVideoPlaybackRequest(URL)) {
        NSURL *newURL = YTRewriteVideoPlaybackURL(URL);
        if (newURL && ![newURL isEqual:URL]) {
            request.URL = newURL;
        }
    }
}

static void YTApplyPlaybackSpoof(NSMutableURLRequest *request)
{
    if (!request || !YTPlaybackFixSpoofEnabled() || !request.URL) {
        return;
    }

    NSURL *URL = request.URL;

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
//                          PART 10: RESPONSE STREAMING DATA REPLACEMENT
// ============================================================================

// Helper: creates TV-compatible formats
static NSArray *YTCreateTVFormats(NSString *videoId)
{
    NSMutableArray *formats = [NSMutableArray array];

    // Video 1080p HLS (iOS compatible)
    id video1080 = [[NSClassFromString(YTIFormatStream) alloc] init];
    if (video1080) {
        [video1080 setURL:[NSString:@"https://manifest.googlevideo.com/api/manifest/hls_variant/playlist/index.m3u8?video_id=%@", videoId]];
        [video1080 setMimeType:application/vnd.apple.mpegurl];
        [video1080 setQualityLabel:1080p];
        [video1080 setItag:137];
        [video1080 setHeight:1080];
        [video1080 setFps:30];
        [formats addObject:video1080];
    }

    // Video 720p
    id video720 = [[NSClassFromString(YTIFormatStream) alloc] init];
    if (video720) {
        video720 = [video720 init];
        if (video720) {
            [video720 setURL:[NSString:@"https://manifest.googlevideo.com/api/manifest/hls_variant/playlist/index.m3u8?video_id=%@", videoId]];
            [video720 setMimeType:application/vnd.apple.mpegurl];
            [video720 setQualityLabel:720p];
            [video720 setItag:136];
            [video720 setHeight:720];
            [video720 setFps:30];
            [formats addObject:video720];
        }
    }

    // Audio
    id audio = [[NSClassFromString(YTIFormatStream) alloc] init];
    if (audio) {
        audio = [audio init];
        if (audio) {
            [audio setURL:[NSString:@"https://manifest.googlevideo.com/api/manifest/hls_variant/playlist/index.m3u8?video_id=%@", videoId]];
            [audio setMimeType:audio/mp4; codecs=mp4a.40.2];
            [audio setItag:140];
            [formats addObject:audio];
        }
    }

    YTLog(@"Created {} TV formats for videoId: {}", (unsigned long)formats.count, videoId);

    return formats;
}

static YTIStreamingData *YTCreateTVStreamingData(NSString *videoId)
{
    Class streamingDataClass = NSClassFromString(YTIStreamingData);
    if (!streamingDataClass) {
        YTLog(YTIStreamingData class not found);
        return nil;
    }

    id tvData = [[streamingDataClass alloc] init];
    if (!tvData) {
        YTLog(Failed to alloc YTIStreamingData);
        return nil;
    }

    NSArray *formats = YTCreateTVFormats(videoId);
    if (formats.count > 0) {
        [tvData setAdaptiveFormatsArray:formats];
        [tvData setFormatsArray:formats];
    }

    return tvData;
}

static NSString *YTExtractVideoIdFromRequest(NSURL *URL)
{
    if (!URL) return nil;

    NSString *query = URL.query;
    if (!query) return nil;

    NSArray *components = [query componentsSeparatedByString:&];
    for (NSString *comp in components) {
        if ([comp hasPrefix:v=] || [comp hasPrefix:video_id=]) {
            return [comp substringFromIndex:2];
        }
    }
    return nil;
}


// ============================================================================
//                          PART 11: HOOKS - REQUEST INTERCEPTION (SAFE ONLY)
// ============================================================================

%hook NSThread

- (void)start {
    %orig;
}

%end

%hook GTMSessionFetcher

- (idinitWithRequest:(id)request
{
    if (!YTPlaybackFixSpoofEnabled()) return %orig(request);
    if (![request isinstance:[NSURLRequest class]]) return %orig(request);
    if (!YTShouldMutateRequest((NSURLRequest *)request)) return %orig(request);

  NSMutableURLRequest *mutableRequest = nil;
    if ([request isinstance:[NSMutableURLRequest class]]) {
        mutableRequest = (NSMutableURLRequest *)request;
    } else {
        mutableRequest = [(NSURLRequest *)request mutableCopy];
    }
    if (!mutableRequest) return %orig(request);

    YTApplyPlaybackSpoof(mutableRequest);
    request = mutableRequest;
    return %orig(request);
}

- (idinitWithRequest:(id)request configuration:(id)configuration
{
    if (!YTPlaybackFixSpoofEnabled()) return %orig(request, configuration);
    if (![request isinstance:[NSURLRequest class]]) return %orig(request, configuration);
    if (!YTShouldMutateRequest((NSURLRequest *)request)) return %orig(request, configuration);

  NSMutableURLRequest *mutableRequest = nil;
    if ([request isinstance:[NSMutableURLRequest class]]) {
        mutableRequest = (NSMutableURLRequest *)request;
    } else {
        mutableRequest = [(NSURLRequest *)request mutableCopy];
    }
    if (!mutableRequest) return %orig(request, configuration);

    YTApplyPlaybackSpoof(mutableRequest);
    request = mutableRequest;
    return %orig(request, configuration);
}

%end


// ============================================================================
//                    PART 12: RESPONSE HOOKS (LAYER 2 - STREAMING DATA)
// ============================================================================

%hook YTPlayerResponse

- (void)setStreamingData:(id)streamingData {
    if (YTPlaybackFixSpoofEnabled()) {
        YTLog(YTPlayerResponse.setStreamingData called);

        // Try to extract videoId from request
        NSString *videoId = nil;

        // Method 1: try player config
        SEL playerConfigSel = NSSelectorFromString(playerConfig);
        if ([self respondsTo:playerConfigSel]) {
            id playerConfig = ((id (*)(id, SEL))objc_msgSend)(self, playerConfigSel);
            if (playerConfig) {
                SEL videoIdSel = NSSelectorFromString(videoId);
                if ([playerConfig respondsTo:videoIdSel]) {
                    videoId = ((id (*)(id, SEL))objc_msgSend)(playerConfig, videoIdSel);
                }
            }
        }

        // Method 2: try videoDetails
        if (!videoId) {
            SEL videoDetailsSel = NSSelectorFromString(videoDetails);
            if ([self respondsTo:videoDetailsSel]) {
                id videoDetails = ((id (*)(id, SEL))objc_msgSend)(self, videoDetailsSel);
                if (videoDetails) {
                    SEL videoIdSel = NSSelectorFromString(videoId);
                    if ([videoDetails respondsTo:videoIdSel]) {
                        videoId = ((id (*)(id, SEL))objc_msgSend)(videoDetails, videoIdSel);
                    }
                }
            }
        }

        if (!videoId) {
            videoId = unknown;
        }

        YTIStreamingData *tvStreamingData = YTCreateTVStreamingData(videoId);
        if (tvStreamingData) {
            YTLog(Replacing streamingData with TV formats for videoId: {}", videoId);
            %orig(tvStreamingData);
            return;
        }
    }
    %orig;
}

- (id)streamingData {
    id original = %orig;
    if (YTPlaybackFixSpoofEnabled() && (!original || [[original adaptiveFormatsArray] count] == 0)) {
        YTLog(Original streamingData empty, creating TV fallback);
        return YTCreateTVStreamingData(unknown);
    }
    return original;
}

%end


// ============================================================================
//                    PART 13: YTIStreamingData HOOK (Logging)
// ============================================================================

%hook YTIStreamingData

- (NSArray *)adaptiveFormatsArray {
    NSArray *formats = %orig;
    YTLog(YTIStreamingData.adaptiveFormatsArray = {}, (unsigned long)[formats count]);
    if ([formats count] > 0) {
        id first = formats[0];
        YTLog(  First format class: {}",NSStringFromClass([first class]));

        SEL urlSel = NSSelectorFromString(URL);
        SEL cipherSel = NSSelectorFromString(signatureCipher);

        if ([first respondsTo:urlSel]) {
            NSString *url = ((id (*)(id, SEL))objc_msgSend)(first, urlSel);
            YTLog(  format.URL = {}", url);
        }
        if ([first respondsTo:cipherSel]) {
            NSString *cipher = ((id (*)(id, SEL))objc_msgSend)(first, cipherSel);
            YTLog(  format.signatureCipher = {}", cipher ? YES : NO);
        }
    }
    return formats;
}

%end


// ============================================================================
//                    PART 14: YTPlayabilityStatus HOOK
// ============================================================================

%hook YTIPlayabilityStatus

- (BOOL)isPlayable { return YES; }
- (BOOL)isPlayableInBackground { return YES; }
- (BOOL)isPlayableNowOrAfterUserAction { return YES; }

%end


%ctor
{
    %init;
}
