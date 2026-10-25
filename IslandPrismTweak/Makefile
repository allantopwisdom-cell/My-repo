TARGET := iphone:clang:16.5:16.0
ARCHS = arm64e
THEOS_PACKAGE_SCHEME = roothide
INSTALL_TARGET_PROCESSES = SpringBoard
include $(THEOS)/makefiles/common.mk
TWEAK_NAME = IslandPrism
IslandPrism_FILES = Tweak.xm
IslandPrism_CFLAGS = -fobjc-arc -Wno-deprecated-declarations
IslandPrism_FRAMEWORKS = UIKit QuartzCore AVFoundation ImageIO CoreGraphics Foundation
include $(THEOS_MAKE_PATH)/tweak.mk
