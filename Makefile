APP_NAME := only-ads
PACKAGE := build/$(APP_NAME).zip
ROKU_DEV_TARGET ?=
ROKU_DEV_PASSWORD ?=
ROKU_LOG_PORT ?= 8085

.PHONY: package install install-debug debug logs watch clean

package:
	mkdir -p build
	zip -r $(PACKAGE) manifest source components images -x "*.DS_Store"

install: package
	test -n "$(ROKU_DEV_TARGET)"
	test -n "$(ROKU_DEV_PASSWORD)"
	curl --digest -u rokudev:$(ROKU_DEV_PASSWORD) \
		-F "mysubmit=Install" \
		-F "archive=@$(PACKAGE)" \
		http://$(ROKU_DEV_TARGET)/plugin_install

install-debug: install logs

debug: logs

logs:
	test -n "$(ROKU_DEV_TARGET)"
	nc $(ROKU_DEV_TARGET) $(ROKU_LOG_PORT)

watch: logs

clean:
	rm -rf build
