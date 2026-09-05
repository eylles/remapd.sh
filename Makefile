.POSIX:

include config.mk

.PHONY: all bin install uninstall clean

all: bin

bin: remapd remaps set-touchpad set-gamepad

build:
	mkdir build

remapd: build
	cp -f remapd.sh build/$@
	chmod 755 build/$@

remaps: build
	cp -f remaps.sh build/$@
	chmod 755 build/$@

set-touchpad: build
	cp -f set-touchpad.sh build/$@
	chmod 755 build/$@

set-gamepad: build
	cp -f set-gamepad.sh build/$@
	chmod 755 build/$@

install: all
	mkdir -p $(BIN_LOC)
	cp -vf build/remapd        $(BIN_LOC)/remapd
	cp -vf build/remaps        $(BIN_LOC)/remaps
	cp -vf build/set-touchpad  $(BIN_LOC)/set-touchpad
	cp -vf build/set-gamepad  $(BIN_LOC)/set-gamepad

uninstall:
	rm -vf $(BIN_LOC)/remapd
	rm -vf $(BIN_LOC)/remaps
	rm -vf $(BIN_LOC)/set-touchpad
	rm -vf $(BIN_LOC)/set-gamepad

clean:
	rm -vrf build
