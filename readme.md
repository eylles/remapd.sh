# remapd

A small shell daemon over udevadm and scripts to apply tweaks and remaps when input devices are connected

Initially based off a pair of scripts in luke smith's [dotfiles](https://github.com/LukeSmithxyz/voidrice)

This includes

| Script | Functionality |
| :--  | :--      |
| `remapd` | hub daemon that leverages udevadm to run the other scripts when input devices are connected |
| `remaps` | script to add keyboard remaps, it changes CapsLock to work as ESC when tapped but as Super when held, right Shift acts as CapsLock when tapped |
| `set-touchpad` | set tapping, natural scrolling, acceleration and transformation matrix for ever connected touchpad |


# install

```sh
git clone https://github.com/eylles/remapd.sh
cd remapd.sh
make install
```
