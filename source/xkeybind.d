module xkeybind;

import x11.X;
import x11.keysym;
import x11.Xlib;
import std.string : toStringz;
import std.typecons : NotImplementedError;

///
alias XKeybindHandler = void delegate(ModifierKey mods, int key);

private struct KeyHandlerEntry
{
	ModifierKey mods;
	int key;
	XKeybindHandler handler;
}

/// Use Modifier for binding keys
enum ModifierKey : uint
{
	///
	Shift = ShiftMask,
	///
	Control = ControlMask,
	///
	Mod1 = Mod1Mask,
	///
	Mod2 = Mod2Mask,
	///
	Mod3 = Mod3Mask,
	///
	Mod4 = Mod4Mask,
	///
	Mod5 = Mod5Mask,
	///
	Any = AnyModifier
}

/// Modifier keys in this system (Get assigned after calling XKeyBind.load)
final struct Modifier
{
	///
	static ModifierKey Shift = ModifierKey.Shift;
	///
	static ModifierKey Control = ModifierKey.Control;
	///
	static ModifierKey Alt;
	///
	static ModifierKey AltR;
	///
	static ModifierKey SuperR;
	///
	static ModifierKey SuperL;
	///
	static ModifierKey HyperR;
	///
	static ModifierKey HyperL;
	///
	static ModifierKey MetaR;
	///
	static ModifierKey MetaL;
	///
	static ModifierKey Any = ModifierKey.Any;
}

///
bool parseKey(Display* display, string key, out ModifierKey mods, out int keycode)
{
	import std.string : strip, split, toLower;

	//dfmt off
	ModifierKey[string] modName = [
		"shift" : Modifier.Shift,
		"control" : Modifier.Control,
		"ctrl" : Modifier.Control,
		"alt" : Modifier.Alt,
		"altl" : Modifier.Alt,
		"altgr" : Modifier.AltR,
		"altr" : Modifier.AltR,
		"super" : Modifier.SuperL,
		"superl" : Modifier.SuperL,
		"superr" : Modifier.SuperR,
		"hyper" : Modifier.HyperL,
		"hyperl" : Modifier.HyperL,
		"hyperr" : Modifier.HyperR,
		"meta" : Modifier.MetaL,
		"metal" : Modifier.MetaL,
		"metar" : Modifier.MetaR,
	];
	//dfmt on
	string[] parts = key.split('-');
	ModifierKey _mods;
	if (parts.length > 1)
	{
		foreach (part; parts[0 .. $ - 1])
		{
			if (part.strip.length == 0)
				return false; // A--B
			string mod = part.strip.toLower;
			auto ptr = mod in modName;
			if (!ptr)
				return false;
			_mods |= *ptr;
		}
	}
	auto keysym = XStringToKeysym(cast(char*)(parts[$ - 1] ~ '\0').ptr);
	if (keysym == NoSymbol)
		return false;
	keycode = XKeysymToKeycode(display, keysym);
	mods = _mods;
	return true;
}

///
final class XKeyBind
{
public:
	/// Creates a display and loads XKeyBind
	static void load(string port = ":0")
	{
		load(XOpenDisplay(cast(char*) port.toStringz));
	}

	/// Loads XKeyBind from an existing display
	static void load(Display* displ)
	{
		display = displ;
		root = DefaultRootWindow(displ);

		XModifierKeymap* modmap = XGetModifierMapping(displ);
		auto key_numlock = XKeysymToKeycode(displ, XK_Num_Lock);
		auto key_alt = XKeysymToKeycode(displ, XK_Alt_L);
		auto key_altr = XKeysymToKeycode(displ, XK_Alt_R);
		auto key_superr = XKeysymToKeycode(displ, XK_Super_R);
		auto key_superl = XKeysymToKeycode(displ, XK_Super_L);
		auto key_hyperl = XKeysymToKeycode(displ, XK_Hyper_L);
		auto key_hyperr = XKeysymToKeycode(displ, XK_Hyper_R);
		auto key_metal = XKeysymToKeycode(displ, XK_Meta_L);
		auto key_metar = XKeysymToKeycode(displ, XK_Meta_R);

		for (int i = 3; i < 8; i++)
		{
			for (int j = 0; j < modmap.max_keypermod; j++)
			{
				auto ckey = modmap.modifiermap[i * modmap.max_keypermod + j];
				if (key_numlock && ckey == key_numlock)
					Numlock = cast(ModifierKey) 1 << i;
				if (key_alt && ckey == key_alt)
					Modifier.Alt = cast(ModifierKey) 1 << i;
				if (key_altr && ckey == key_altr)
					Modifier.AltR = cast(ModifierKey) 1 << i;
				if (key_superr && ckey == key_superr)
					Modifier.SuperR = cast(ModifierKey) 1 << i;
				if (key_superl && ckey == key_superl)
					Modifier.SuperL = cast(ModifierKey) 1 << i;
				if (key_hyperl && ckey == key_hyperl)
					Modifier.HyperL = cast(ModifierKey) 1 << i;
				if (key_hyperr && ckey == key_hyperr)
					Modifier.HyperR = cast(ModifierKey) 1 << i;
				if (key_metal && ckey == key_metal)
					Modifier.MetaL = cast(ModifierKey) 1 << i;
				if (key_metar && ckey == key_metar)
					Modifier.MetaR = cast(ModifierKey) 1 << i;
			}
		}

		ignoreMods = [Lock];
		ignoreMask = Lock;
		if (Numlock)
		{
			ignoreMods = [Numlock, Lock, Numlock | Lock];
			ignoreMask = Numlock | Lock;
		}
		ignoreMask = ~ignoreMask;
	}

	/// Checks for key presses and calls handlers
	static void update()
	{
		while (XCheckWindowEvent(display, root, KeyPressMask, &event))
		{
			if (event.type == KeyPress)
			{
				int key = event.xkey.keycode;
				ModifierKey mods = cast(ModifierKey)(event.xkey.state & ignoreMask);
				foreach (KeyHandlerEntry bind; binds)
				{
					if (bind.key == key && bind.mods == mods)
						bind.handler(mods, key);
				}
			}
		}
	}

	/// Binds the key without binding keys when numlock or lock are active
	static void bindExact(ModifierKey mods, int keycode, XKeybindHandler handler)
	{
		XGrabKey(display, keycode, cast(uint) mods, root, 0, GrabModeAsync, GrabModeAsync);
		binds ~= KeyHandlerEntry(mods, keycode, handler);
	}

	///
	static void bind(ModifierKey mods, int keycode, XKeybindHandler handler)
	{
		bindExact(mods, keycode, handler);
		foreach (mod; ignoreMods)
			bindExact(mod | mods, keycode, handler);
	}

	///
	static void bind(string key, XKeybindHandler handler)
	{
		ModifierKey mods;
		int code;
		parseKey(display, key, mods, code);
		bind(mods, code, handler);
	}

	///
	static void unbindExact(ModifierKey mods, int keycode)
	{
		XUngrabKey(display, keycode, cast(uint) mods, root);
	}

	///
	static void unbind(ModifierKey mods, int keycode)
	{
		unbindExact(mods, keycode);
		foreach (mod; ignoreMods)
			unbindExact(mod | mods, keycode);
	}

	///
	static void unbind(string key)
	{
		ModifierKey mods;
		int code;
		parseKey(display, key, mods, code);
		unbind(mods, code);
	}

private:
	static ModifierKey Numlock;
	static ModifierKey Lock = cast(ModifierKey) LockMask;
	static ModifierKey[] ignoreMods;
	static ModifierKey ignoreMask;
	static KeyHandlerEntry[] binds;
	static Display* display;
	static Window root;
	static XEvent event;
}
