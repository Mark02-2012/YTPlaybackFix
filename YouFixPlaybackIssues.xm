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

static NSString * const kJSONKeyContext      = @"context";
static NSString * const kJSONKeyClient       = @"client";
static NSString * const kJSONKeyVisitorData  = @"visitorData";
static NSString * const kJSONKeyVideoId      = @"videoId";
static NSString * const kJSONKeyBrowseId     = @"browseId";
static NSString * const kJSONKeyContinuation = @"continuation";
static NSString * const kJSONKeyStreamingData = @"streamingData";

static NSString * const YTPlaybackFixSpoofEnabledKey =
    @"YTPlaybackFixSpoofEnabled";
static NSString * const YTPlaybackFixSpoofClientModeKey =
    @"YTPlaybackFixSpoofClientMode";


// ============================================================================
// PLAYBACK CLIENTS
// ============================================================================
