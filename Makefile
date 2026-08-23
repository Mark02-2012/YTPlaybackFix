TARGET := iphone:clang:latest:15.0
ARCHS = arm64 arm64e
THEOS_PACKAGE_SCHEME = rootless

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = YTPlaybackFix

YTPlaybackFix_FILES = Refresh.xm YouFixPlaybackIssues.xm Settings.xm
YTPlaybackFix_CFLAGS = -fobjc-arc -Wno-unused-function "-I." "-I.." "-I$(THEOS)/include/YouTubeHeader" "-I../../"

include $(THEOS_MAKE_PATH)/tweak.mk
