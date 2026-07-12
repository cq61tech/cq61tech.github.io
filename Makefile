THEOS_PACKAGE_SCHEME = rootless
TARGET = iphone:clang:13.7:13.0
INSTALL_TARGET_PROCESSES = AssistiveTouch assistivetouchd
ARCHS = arm64

PACKAGE_ICON = https://github.com/cq61tech/cq61tech.github.io/blob/main/icons/IHateAT.png

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = IHateAT
IHateAT_FILES = Tweak.x
IHateAT_CFLAGS = -fobjc-arc

include $(THEOS_MAKE_PATH)/tweak.mk
