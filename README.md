# XKeyBinD

Interface for global keyboard shortcuts on X11 in D applications.

## Usage

```d
import xkeybind;

void main() {
    XKeyBind.load(); // Opens a X11 display and initializes virtual modifier locations
    // Alternatively also usable with a Modifier and an integer keycode
    XKeyBind.bind("Ctrl-Shift-X", (mod, key) { // Binds a key from a string (see notation below) with a handler
        writeln("Pressed!");
        XKeyBind.unbind("Ctrl-Shift-X"); // Unbinds all handlers from a key
    });

    while (true) {
        // Handle window events

        XKeyBind.update(); // Handles X11 key press events and calls handlers
    }
}
```

## String key notation

    (Modifiers-)Key

Any number of modifiers combined with hyphens and a key at the end.

Valid modifiers:

* shift
* control
* ctrl
* alt, altl
* altgr, altr
* super, superl
* superr
* hyper, hyperl
* hyperr
* meta, metal
* metar

Keys are parsed using `XStringToKeysym`