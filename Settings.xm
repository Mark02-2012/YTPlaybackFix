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
#import <YouTubeHeader/YTSettingsPickerViewController.h>

#define TweakName @"YTPlaybackFix"

static const NSInteger TweakSection = 'ytpf';

static NSString * const YTPlaybackFixRefreshKey =
    @"YTPlaybackFixRefreshEnabled";

static NSString * const YTPlaybackFixSpoofKey =
    @"YTPlaybackFixSpoofEnabled";

static NSString * const YTPlaybackFixSpoofClientModeKey =
    @"YTPlaybackFixSpoofClientMode";


/* ============================================================================
 * Helpers
 * ============================================================================ */

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


static NSInteger YTPlaybackFixSpoofClientMode(void)
{
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];

    if (![defaults objectForKey:YTPlaybackFixSpoofClientModeKey])
        return 0;

    NSInteger mode =
        [defaults integerForKey:YTPlaybackFixSpoofClientModeKey];

    return mode == 1 ? 1 : 0;
}


static NSString *YTPlaybackFixClientTitle(void)
{
    return YTPlaybackFixSpoofClientMode() == 1
        ? @"TV_SABR"
        : @"TV Simply";
}


/* ============================================================================
 * Settings categories
 * ============================================================================ */

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
                             @selector(tweaks))) {
        return %orig;
    }

    NSArray<NSNumber *> *orig = %orig;
    NSMutableArray<NSNumber *> *categories = [orig mutableCopy];

    if (![categories containsObject:@(TweakSection)]) {
        [categories insertObject:@(TweakSection) atIndex:0];
    }

    return categories.copy;
}

%end


%hook YTAppSettingsPresentationData

+ (NSArray<NSNumber *> *)settingsCategoryOrder
{
    NSArray<NSNumber *> *order = %orig;

    NSUInteger insertIndex = [order indexOfObject:@(1)];

    if (insertIndex != NSNotFound) {

        NSMutableArray<NSNumber *> *categories =
            [order mutableCopy];

        if (![categories containsObject:@(TweakSection)]) {
            [categories insertObject:@(TweakSection)
                            atIndex:insertIndex + 1];
        }

        return categories.copy;
    }

    return order;
}

%end


/* ============================================================================
 * Settings section
 * ============================================================================ */

@interface YTSettingsSectionItemManager (YTPlaybackFix)

- (void)updateYTPlaybackFixSectionWithEntry:(id)entry;

@end


%hook YTSettingsSectionItemManager

%new(v@:@)
- (void)updateYTPlaybackFixSectionWithEntry:(id)entry
{
    NSMutableArray<YTSettingsSectionItem *> *sectionItems =
        [NSMutableArray array];

    Class Item = %c(YTSettingsSectionItem);

    YTSettingsViewController *settingsViewController =
        [self valueForKey:@"_dataDelegate"];

    /* ------------------------------------------------------------------------
     * Version
     * ---------------------------------------------------------------------- */

    YTSettingsSectionItem *version =
        [Item itemWithTitle:@"YTPlaybackFix v1.2b1 by Mark02-2012"
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
        [Item
            switchItemWithTitle:@"Refresh"
            titleDescription:
                @"Fix playback issues by reloading the player every time the error gets detected, but you will see a short black screen. (My method, based on what was YTPlaybackFix in 0.2.2)."
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
        [Item
            switchItemWithTitle:@"Playback Client Spoof"
            titleDescription:
                @"Spoof the YouTube playback client to fix playback issues."
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
     * Playback Client picker
     * ---------------------------------------------------------------------- */

    YTSettingsSectionItem *clientItem =
        [Item
            itemWithTitle:@"Playback Client"
            titleDescription:YTPlaybackFixClientTitle()
            accessibilityIdentifier:@"YTPlaybackFixSpoofClient"
            detailTextBlock:nil
            selectBlock:^BOOL (YTSettingsCell *cell,
                               NSUInteger arg1) {

                NSArray<NSString *> *titles = @[
                    @"TV Simply",
                    @"TV_SABR"
                ];

                NSMutableArray *rows =
                    [NSMutableArray array];

                for (NSInteger i = 0;
                     i < (NSInteger)titles.count;
                     i++) {

                    NSInteger selectedIndex = i;

                    YTSettingsSectionItem *row =
                        [Item
                            checkmarkItemWithTitle:titles[i]
                            selectBlock:^BOOL (
                                YTSettingsCell *pickerCell,
                                NSUInteger pickerArg) {

                                [[NSUserDefaults standardUserDefaults]
                                    setInteger:selectedIndex
                                    forKey:YTPlaybackFixSpoofClientModeKey];

                                return YES;
                            }];

                    [rows addObject:row];
                }

                YTSettingsPickerViewController *picker =
                    [[%c(YTSettingsPickerViewController) alloc]
                        initWithNavTitle:@"Playback Client"
                        pickerSectionTitle:nil
                        rows:rows
                        selectedItemIndex:
                            YTPlaybackFixSpoofClientMode()
                        parentResponder:settingsViewController];

                [settingsViewController.navigationController
                    pushViewController:picker
                    animated:YES];

                return YES;
            }];

    [sectionItems addObject:clientItem];


    /* ------------------------------------------------------------------------
     * Register section
     * ---------------------------------------------------------------------- */

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
 * Section dispatcher
 * ============================================================================ */

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
