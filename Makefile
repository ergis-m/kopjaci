APP      = build/Kopjaci.app
SIGN_ID ?= Apple Development: Ergis Mullai (5AFX9TJ6ZR)

app: ## build release binary and assemble + sign the .app bundle
	swift build -c release
	mkdir -p $(APP)/Contents/MacOS
	cp Info.plist $(APP)/Contents/
	cp .build/release/Kopjaci $(APP)/Contents/MacOS/
	codesign --force --sign "$(SIGN_ID)" $(APP)

run: app
	pkill -x Kopjaci || true
	open $(APP)

clean:
	rm -rf build .build

.PHONY: app run clean
