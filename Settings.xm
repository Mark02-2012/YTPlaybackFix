/* Settings.xm */

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

#import <YouTubeHeader/YTSettingsGroupData.h>
#import <YouTubeHeader/YTAppSettingsPresentationData.h>
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
 * Compatibility with the older settings-category system.
 * ========================================================================== */

%hook YTSettingsGroupData

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
     * Refresh
     * ---------------------------------------------------------------------- */

    YTSettingsSectionItem *refreshItem =
        [YTSettingsSectionItemClass
            switchItemWithTitle:@"Refresh"
            titleDescription:@"Automatically retries playback errors and restores the previous playback position."
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
            titleDescription:@"Uses the Android VR playback client for playback requests."
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
