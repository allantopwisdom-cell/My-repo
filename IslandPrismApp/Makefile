TARGET := iphone:clang:16.5:16.0
ARCHS = arm64e
THEOS_PACKAGE_SCHEME = roothide
include $(THEOS)/makefiles/common.mk
APPLICATION_NAME = IslandPrismApp
IslandPrismApp_FILES = main.m
IslandPrismApp_CFLAGS = -fobjc-arc -Wno-deprecated-declarations
IslandPrismApp_CODESIGN_FLAGS = -Sroothide.entitlements
IslandPrismApp_FRAMEWORKS = UIKit Foundation UniformTypeIdentifiers
include $(THEOS_MAKE_PATH)/application.mk
