include $(THEOS)/makefiles/common.mk

TWEAK_NAME = ParentalControlsForiOS
ParentalControlsForiOS_FILES = Tweak.xm KeychainItemWrapper.m
ParentalControlsForiOS_FRAMEWORKS = UIKit Security
ParentalControlsForiOS_PRIVATE_FRAMEWORKS = GraphicsServices

SUBPROJECTS += pcfiospreferences

include $(THEOS)/makefiles/tweak.mk
include $(THEOS)/makefiles/aggregate.mk

after-install::
	install.exec "killall -9 backboardd"