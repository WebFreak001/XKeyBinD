import xkeybind;
import std.stdio;

void main()
{
	XKeyBind.load();
	XKeyBind.bind("Ctrl-Shift-X", (mod, key) {
		writeln("Unbound");
		XKeyBind.unbind("Ctrl-Shift-X");
	});

	while (true)
	{
		XKeyBind.update();
	}
}
