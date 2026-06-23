TARGET := iphone:clang:latest:16.0
ARCHS = arm64 arm64e
THEOS_PACKAGE_SCHEME = rootless

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = YTPlaybackFix

YTPlaybackFix_FILES = Tweak.x
YTPlaybackFix_CFLAGS = -fobjc-arc

include $(THEOS_MAKE_PATH)/tweak.mk
