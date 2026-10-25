TARGET := iphone:clang:16.5:16.0
ARCHS = arm64e
THEOS_PACKAGE_SCHEME = roothide
SUBPROJECTS += IslandPrismTweak IslandPrismApp IslandPrismPrefs
include $(THEOS)/makefiles/common.mk
include $(THEOS_MAKE_PATH)/aggregate.mk
