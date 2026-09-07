APP      = build/Kopjaci.app
SIGN_ID ?= Apple Development: Ergis Mullai (5AFX9TJ6ZR)
VERSION := $(shell /usr/libexec/PlistBuddy -c 'Print CFBundleShortVersionString' Info.plist)
ZIP      = build/Kopjaci-$(VERSION).zip

app: ## build release binary and assemble + sign the .app bundle
	swift build -c release
	mkdir -p $(APP)/Contents/MacOS
	cp Info.plist $(APP)/Contents/
	mkdir -p $(APP)/Contents/Resources && cp Assets/Kopjaci.icns $(APP)/Contents/Resources/
	cp .build/release/Kopjaci $(APP)/Contents/MacOS/
	codesign --force --sign "$(SIGN_ID)" $(APP)

run: app
	pkill -x Kopjaci || true
	open $(APP)

icon: ## regenerate the placeholder icon (drop a real Kopjaci.icns into Assets/ to replace it)
	swift Assets/icon.swift Assets/Kopjaci && iconutil -c icns Assets/Kopjaci.iconset && rm -r Assets/Kopjaci.iconset

release: ## ad-hoc signed zip for a GitHub release; syncs version + sha256 into the cask
	$(MAKE) app SIGN_ID=-
	rm -f $(ZIP) && ditto -c -k --keepParent $(APP) $(ZIP)
	sed -i '' -e 's/^  version .*/  version "$(VERSION)"/' \
	          -e 's/^  sha256 .*/  sha256 "'$$(shasum -a 256 $(ZIP) | cut -d' ' -f1)'"/' Casks/kopjaci.rb
	@echo "→ gh release create v$(VERSION) $(ZIP) --title v$(VERSION)   then commit Casks/kopjaci.rb"

clean:
	rm -rf build .build

.PHONY: app run icon release clean
