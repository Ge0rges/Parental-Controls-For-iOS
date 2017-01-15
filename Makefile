export ARCHS = armv7 armv7s arm64
export THEOS_BUILD_DIR = packages

include theos/makefiles/common.mk

TWEAK_NAME = ParentalControlsForiOS
ParentalControlsForiOS_FILES = Tweak.xm KeychainItemWrapper.m
ParentalControlsForiOS_FRAMEWORKS = UIKit Security
ParentalControlsForiOS_PRIVATE_FRAMEWORKS = GraphicsServices

include $(THEOS_MAKE_PATH)/tweak.mk

after-install::
	install.exec "killall -9 backboardd"

SUBPROJECTS += pcfiospreferences
include $(THEOS_MAKE_PATH)/aggregate.mk
