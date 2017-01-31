include $(THEOS)/makefiles/common.mk

BUNDLE_NAME = PCFiOSPreferences
PCFiOSPreferences_FILES = PCFiOSPreferences.mm KeychainItemWrapper.m
PCFiOSPreferences_INSTALL_PATH = /Library/PreferenceBundles
PCFiOSPreferences_FRAMEWORKS = UIKit Security
PCFiOSPreferences_PRIVATE_FRAMEWORKS = Preferences

include $(THEOS)/makefiles/bundle.mk

internal-stage::
	$(ECHO_NOTHING)mkdir -p $(THEOS_STAGING_DIR)/Library/PreferenceLoader/Preferences$(ECHO_END)
	$(ECHO_NOTHING)cp entry.plist $(THEOS_STAGING_DIR)/Library/PreferenceLoader/Preferences/PCFiOSPreferences.plist$(ECHO_END)
