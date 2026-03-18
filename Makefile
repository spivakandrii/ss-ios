INSTALL_TARGET_PROCESSES = SabbathSchool

include $(THEOS)/makefiles/common.mk

APPLICATION_NAME = SabbathSchool

SabbathSchool_FILES = main.m SSAppDelegate.m SSAPIClient.m SSLanguageVC.m SSQuarterliesVC.m SSLessonsVC.m SSReadVC.m
SabbathSchool_FRAMEWORKS = UIKit Foundation CoreGraphics Security
SabbathSchool_CFLAGS = -fobjc-arc -Wno-deprecated-declarations -DDEPLOYMENT_TARGET_5=1
SabbathSchool_LDFLAGS = -Wl,-undefined,dynamic_lookup -Wl,-flat_namespace
TARGET_CODESIGN = true

export ARCHS = armv7
export TARGET = iphone:clang:9.3:5.0

include $(THEOS_MAKE_PATH)/application.mk
