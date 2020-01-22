install:
	swift build -c release
	install .build/release/xcinfo /usr/local/bin/xcinfo
