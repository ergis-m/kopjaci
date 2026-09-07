APP      = build/Kopjaci.app
SIGN_ID ?= Apple Development: Ergis Mullai (5AFX9TJ6ZR)

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

clean:
	rm -rf build .build

.PHONY: app run icon clean
