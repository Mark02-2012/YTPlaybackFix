/* Settings.xm */

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <objc/runtime.h>

#import <YouTubeHeader/YTSettingsGroupData.h>
#import <YouTubeHeader/YTSettingsSectionItem.h>
#import <YouTubeHeader/YTSettingsSectionItemManager.h>
#import <YouTubeHeader/YTSettingsViewController.h>
#import <YouTubeHeader/YTSettingsCell.h>
#import <YouTubeHeader/YTIIcon.h>

#define TweakName @"YTPlaybackFix"

static const NSInteger TweakSection = 'ytpf';

static NSString * const YTPlaybackFixRefreshKey = @"YTPlaybackFixRefreshEnabled";
static NSString * const YTPlaybackFixSpoofKey   = @"YTPlaybackFixSpoofEnabled";


/* ============================================================================
 * Helpers
 * ========================================================================== */

static BOOL YTPlaybackFixRefreshEnabled(void)
{
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];

    if (![defaults objectForKey:YTPlaybackFixRefreshKey])
        return YES;

    return [defaults boolForKey:YTPlaybackFixRefreshKey];
}

static BOOL YTPlaybackFixSpoofEnabled(void)
{
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];

    if (![defaults objectForKey:YTPlaybackFixSpoofKey])
        return YES;

    return [defaults boolForKey:YTPlaybackFixSpoofKey];
}


/* ============================================================================
 * YTSettingsGroupData
 *
 * Compatibility with YouGroupSettings and the older settings-category system.
 * ========================================================================== */

%hook YTSettingsGroupData

+ (NSMutableArray<NSNumber *> *)tweaks
{
    NSMutableArray<NSNumber *> *tweaks = %orig;

    if (tweaks && ![tweaks containsObject:@(TweakSection)]) {
        [tweaks addObject:@(TweakSection)];
    }

    return tweaks;
}

- (NSArray<NSNumber *> *)orderedCategories
{
    if (self.type != 1 ||
        class_getClassMethod(objc_getClass("YTSettingsGroupData"),
                             @selector(tweaks)))
    {
        return %orig;
    }

    NSArray<NSNumber *> *categories = %orig;

    NSMutableArray<NSNumber *> *mutableCategories = [categories mutableCopy];

    NSNumber *sectionNumber = @(TweakSection);

    if (![mutableCategories containsObject:sectionNumber]) {
        [mutableCategories insertObject:sectionNumber atIndex:0];
    }

    return mutableCategories.copy;
}

%end


/* ============================================================================
 * YTAppSettingsPresentationData
 *
 * Required for older YouTube versions, including the 20.21.6 settings system.
 * Inserts our custom section immediately after category 1.
 * ========================================================================== */

%hook YTAppSettingsPresentationData

+ (NSArray<NSNumber *> *)settingsCategoryOrder
{
    NSArray<NSNumber *> *order = %orig;

    NSUInteger insertIndex = [order indexOfObject:@(1)];

    if (insertIndex != NSNotFound) {

        NSMutableArray<NSNumber *> *categories = [order mutableCopy];

        NSNumber *sectionNumber = @(TweakSection);

        if (![categories containsObject:sectionNumber]) {

            [categories insertObject:sectionNumber
                            atIndex:insertIndex + 1];
        }

        return categories.copy;
    }

    return order;
}

%end


/* ============================================================================
 * Settings section
 * ========================================================================== */

@interface YTSettingsSectionItemManager (YTPlaybackFix)

- (void)updateYTPlaybackFixSectionWithEntry:(id)entry;

@end


%hook YTSettingsSectionItemManager

%new(v@:@)
- (void)updateYTPlaybackFixSectionWithEntry:(id)entry
{
    NSMutableArray<YTSettingsSectionItem *> *sectionItems =
        [NSMutableArray array];

    Class YTSettingsSectionItemClass = %c(YTSettingsSectionItem);


    /* ------------------------------------------------------------------------
     * Version
     * ---------------------------------------------------------------------- */

    YTSettingsSectionItem *version =
    [YTSettingsSectionItemClass itemWithTitle:@"YTPlaybackFix v1.0test by Mark02-2012"
       titleDescription:nil
accessibilityIdentifier:nil
        detailTextBlock:nil
            selectBlock:^BOOL (YTSettingsCell *cell,
                               NSUInteger arg1) {

        return NO;

    }];

    [sectionItems addObject:version];

    /* ------------------------------------------------------------------------
     * Refresh
     * ---------------------------------------------------------------------- */

    YTSettingsSectionItem *refreshItem =
        [YTSettingsSectionItemClass
            switchItemWithTitle:@"Refresh"
            titleDescription:@"Fix the playback issues by reloading the player every time the error gets detected, but you will see a short black screen. (My method, based on what was YTPlaybackFix in 0.2.2)."
            accessibilityIdentifier:@"YTPlaybackFixRefresh"
            switchOn:YTPlaybackFixRefreshEnabled()
            switchBlock:^BOOL (YTSettingsCell *cell, BOOL enabled) {

                [[NSUserDefaults standardUserDefaults]
                    setBool:enabled
                    forKey:YTPlaybackFixRefreshKey];

                return YES;
            }
            settingItemId:0];

    [sectionItems addObject:refreshItem];


    /* ------------------------------------------------------------------------
     * Playback Client Spoof
     * ---------------------------------------------------------------------- */

    YTSettingsSectionItem *spoofItem =
        [YTSettingsSectionItemClass
            switchItemWithTitle:@"Playback Client Spoof"
            titleDescription:@"Fix the playback issues by spoofing the YouTube client to Android VR and using an experimental PoToken bypass, but you will not be able to watch restricted videos (i.e age restricted videos) and sometimes the error appears even if the spoof is enabled. (YouFixPlaybackIssues by AppropriateNet)."
            accessibilityIdentifier:@"YTPlaybackFixSpoof"
            switchOn:YTPlaybackFixSpoofEnabled()
            switchBlock:^BOOL (YTSettingsCell *cell, BOOL enabled) {

                [[NSUserDefaults standardUserDefaults]
                    setBool:enabled
                    forKey:YTPlaybackFixSpoofKey];

                return YES;
            }
            settingItemId:0];

    [sectionItems addObject:spoofItem];


    /* ------------------------------------------------------------------------
     * Add section to YouTube Settings
     * ---------------------------------------------------------------------- */

    YTSettingsViewController *settingsViewController =
        [self valueForKey:@"_dataDelegate"];

    if (!settingsViewController)
        return;


    if ([settingsViewController
            respondsToSelector:@selector(
                setSectionItems:
                forCategory:
                title:
                icon:
                titleDescription:
                headerHidden:)])
    {
        YTIIcon *icon = [%c(YTIIcon) new];

        /*
         * Play button icon.
         * YT_SETTINGS is the standard YouTube settings icon.
         */
        icon.iconType = YT_PLAY_ARROW_OUTLINED;

        [settingsViewController
            setSectionItems:sectionItems
            forCategory:TweakSection
            title:TweakName
            icon:icon
            titleDescription:nil
            headerHidden:NO];
    }
    else
    {
        [settingsViewController
            setSectionItems:sectionItems
            forCategory:TweakSection
            title:TweakName
            titleDescription:nil
            headerHidden:NO];
    }
}


/* ============================================================================
 * Section update dispatcher
 * ========================================================================== */

- (void)updateSectionForCategory:(NSUInteger)category
                      withEntry:(id)entry
{
    if (category == TweakSection) {

        [self updateYTPlaybackFixSectionWithEntry:entry];

        return;
    }

    %orig;
}

%end
