/*
 * Replace all of this with GtkBuilder. Then create a UIManager to handle 
 * accels, action groups, toolbars, menu items, etc. This should define events
 * and signals and delegate the backend labor to objects of the defined classes
 * (Track, Playlist, XesamClient, etc.) in the accompanying files. 
 */

using GLib;
using Gtk;

namespace Hum {
	
	public class UserInterface : GLib.Object {
		string ui_file = Config.UI_FILE;
		public Gtk.Window window;
	
		UserInterface () {
			var ui_definition = new Gtk.Builder ();
			ui_definition.add_from_file (ui_file);
			window = (Gtk.Window) ui_definition.get_object ("main_window");
		}
	
		public void quit () {
			Gtk.main_quit ();
		}

		static int main (string[] args)	{
			Gtk.init (ref args);

			var sample = new UserInterface ();
			sample.window.show_all ();

			Gtk.main ();

			return 0;
		}
	}
}
