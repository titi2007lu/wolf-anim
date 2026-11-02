TARGET := iphone:clang:latest:11.0
ARCHS = arm64
INSTALL_TARGET_PROCESSES = FacebookApp

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = WolfAnimatedProfile
WolfAnimatedProfile_FILES = Tweak.xm
WolfAnimatedProfile_FRAMEWORKS = UIKit AVFoundation ImageIO MobileCoreServices
WolfAnimatedProfile_CFLAGS = -fobjc-arc -Wno-deprecated-declarations

include $(THEOS_MAKE_PATH)/tweak.mk
