.PHONY: app run install snapshot clean

app:
	./scripts/build-app.sh

run: app
	open build/Klikr.app

install: app
	-pkill -f "Keyfun.app/Contents/MacOS/Keyfun"
	-pkill -f "Klikr.app/Contents/MacOS/Klikr"
	rm -rf /Applications/Keyfun.app /Applications/Klikr.app
	ditto build/Klikr.app /Applications/Klikr.app
	/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -u build/Klikr.app || true
	open /Applications/Klikr.app

snapshot:
	swift build
	"$$(swift build --show-bin-path)/Klikr" --snapshot build/snapshot.png $(LAYOUT)

clean:
	rm -rf .build build
