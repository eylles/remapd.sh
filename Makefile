.POSIX:

include config.mk

.PHONY: all bin install uninstall clean

all: bin

bin: remapd remaps set-touchpad

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

install: all
	mkdir -p $(BIN_LOC)
	cp -vf build/remapd        $(BIN_LOC)/remapd
	cp -vf build/remaps        $(BIN_LOC)/remaps
	cp -vf build/set-touchpad  $(BIN_LOC)/set-touchpad

uninstall:
	rm -vf $(BIN_LOC)/remapd
	rm -vf $(BIN_LOC)/remaps
	rm -vf $(BIN_LOC)/set-touchpad

clean:
	rm -vrf build
