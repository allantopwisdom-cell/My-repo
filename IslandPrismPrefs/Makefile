TARGET := iphone:clang:16.5:16.0
ARCHS = arm64e
THEOS_PACKAGE_SCHEME = roothide
include $(THEOS)/makefiles/common.mk
BUNDLE_NAME = IslandPrismPrefs
IslandPrismPrefs_FILES = RootListController.m
IslandPrismPrefs_INSTALL_PATH = /Library/PreferenceBundles
IslandPrismPrefs_CFLAGS = -fobjc-arc
IslandPrismPrefs_FRAMEWORKS = UIKit Foundation
IslandPrismPrefs_PRIVATE_FRAMEWORKS = Preferences
include $(THEOS_MAKE_PATH)/bundle.mk
