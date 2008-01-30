/*
 * Replace all of this with GtkBuilder. Then create a UIManager to handle 
 * accels, action groups, toolbars, menu items, etc. This should define events
 * and signals and delegate the backend labor to objects of the defined classes
 * (Track, Playlist, XesamClient, etc.) in the accompanying files. 
 */

using GLib;
using Gtk;

namespace Hum {
	
	public class UserInterface {
		string dataDir = "/home/brian/Projects/Public/hum.dev/trunk/data/";
		string uiFile = dataDir + "hum_ui.xml";
		public Window window;		
	
		construct {
			var uiDefinition = new Builder (uiFile, null);
			window = (Gtk.Window) uiDefinition.get_object ("main_window");
		}
	}
	
	public void quit () {
		Gtk.main_quit ();
	}
		
	static int main (string[] args)	{
		Gtk.init (out args);
		
		var sample = new UserInterface ();
		sample.window.show_all ();

		Gtk.main ();
		
		return 0;
	}
}
