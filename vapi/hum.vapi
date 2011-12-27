namespace Hum {

	[DBus (name = "org.washedup.Hum")]
	public interface Player : GLib.Object
	{
		public abstract void quit (string reason = "Normal shutdown.") throws GLib.IOError;

		public abstract void add_track (string uri, int position = -1) throws GLib.IOError;
		public abstract void remove_track (int position) throws GLib.IOError;
		public abstract void clear_playlist () throws GLib.IOError;
		public abstract string[] get_playlist () throws GLib.IOError;
		public abstract void play (int position = -1) throws GLib.IOError;
		public abstract void pause () throws GLib.IOError;
		public abstract void stop () throws GLib.IOError;
		public abstract void next () throws GLib.IOError;
		public abstract void previous () throws GLib.IOError;
		public abstract void seek (int64 usec) throws GLib.IOError;
		public abstract int get_current_track () throws GLib.IOError;
		public abstract string get_current_uri () throws GLib.IOError;
		public abstract int64 get_progress () throws GLib.IOError;
		public abstract string get_playback_status () throws GLib.IOError;
		public abstract int get_volume () throws GLib.IOError;
		public abstract void set_volume (int level) throws GLib.IOError;
		public abstract bool get_repeat () throws GLib.IOError;
		public abstract void set_repeat (bool do_repeat) throws GLib.IOError;
		public abstract bool get_shuffle () throws GLib.IOError;
		public abstract void set_shuffle (bool do_shuffle) throws GLib.IOError;

		public signal void track_added (string uri, int position);
		public signal void track_removed (int position);
		public signal void playlist_cleared ();
		public signal void playing_track (int position);
		public signal void paused_playback ();
		public signal void stopped_playback ();
		public signal void seeked (int64 usec);
		public signal void repeat_toggled (bool do_repeat);
		public signal void shuffle_toggled (bool do_shuffle);
		public signal void exiting ();
	}
}
