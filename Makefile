TARGET := iphone:clang:latest:15.0
INSTALL_TARGET_PROCESSES = WhatsApp Preferences
THEOS_PACKAGE_SCHEME = rootless

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = TickTint
SUBPROJECTS += ticktintprefs
TickTint_FILES = Tweak.x
TickTint_CFLAGS = -fobjc-arc

include $(THEOS_MAKE_PATH)/tweak.mk
include $(THEOS_MAKE_PATH)/aggregate.mk
