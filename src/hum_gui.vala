/*
 * hum_gui.vala
 * 
 * This file is part of Hum, the low calorie music manager.
 * 
 * Copyright (C) 2007-2009 by Brian Davis <brian.william.davis@gmail.com>
 *
 * Hum is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2 of the License, or
 * (at your option) any later version.
 *
 * Hum is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with Hum; if not, write to the Free Software
 * Foundation, Inc., 51 Franklin St, Fifth Floor, 
 * Boston, MA  02110-1301  USA
 */

/*
 * FIXME: Then create a UIManager to 
 *        handle accels, action groups, toolbars, menu items, etc. This should
 *        define events and signals and delegate the backend labor to objects
 *        of the defined classes (Track, Playlist, Store, etc.) in the 
 *        accompanying files. 
 */

using GLib;
using Gtk;
using Config;
using DBus;

namespace Hum
{
	public enum Columns
	{
		URI,
		STATUS,
		TITLE,
		ARTIST,
		ALBUM,
		TRACK,
		GENRE,
		DURATION,
		NUM_COLUMNS
	}

	public class UserInterface
	{
		public Gtk.Window window;
		public Gtk.Statusbar status_bar;
		public Gtk.ToolButton play_button;
		public Gtk.ToolButton pause_button;
		public Gtk.ToolButton prev_button;
		public Gtk.ToolButton next_button;
		public Gtk.ToggleToolButton repeat_button;
		public Gtk.ToggleToolButton shuffle_button;
		public Gtk.Label track_label;
		public Gtk.Label duration_label;
		public Gtk.HScale progress_slider;
		public Gtk.TreeView track_list;
		public Gtk.ListStore list_store;
		public Gtk.TreeSelection browse_select;

		private string ui_file = "main.ui";
		
		private DBus.Connection conn;
		private dynamic DBus.Object player;
		private Hum.Collection playlist;
		private Hum.Store store;
	
		public UserInterface (string [] args)
		{
			this.conn = DBus.Bus.get (DBus.BusType.SESSION);

			// Fetch the player backend.
			// FIXME: If no backend exists, one should be launched.
			this.player = conn.get_object ("org.washedup.Hum",
				"/org/washedup/Hum",
				"org.washedup.Hum");
			
			this.store = new Hum.Store ();
			this.playlist = new Hum.Collection ("test");

			// Construct the window and its child widgets from the UI definition.
			Gtk.Builder builder = new Gtk.Builder ();
			string path = GLib.Path.build_filename (Config.PACKAGE_DATADIR, ui_file);
	
			try
			{
				builder.add_from_file (path);
			}
	
			catch (GLib.Error e)
			{
				stderr.printf ("Shit! %s\n", e.message);
				quit ();
			}
	
			// Assign the widgets to a variable for manipulation later.
			this.window = (Gtk.Window) builder.get_object ("main_window");
			this.status_bar = (Gtk.Statusbar) builder.get_object ("status_bar");
			this.play_button = (Gtk.ToolButton) builder.get_object ("play_button");
			this.pause_button = (Gtk.ToolButton) builder.get_object ("pause_button");
			this.prev_button = (Gtk.ToolButton) builder.get_object ("prev_button");
			this.next_button = (Gtk.ToolButton) builder.get_object ("next_button");
			this.repeat_button = (Gtk.ToggleToolButton) builder.get_object ("repeat_button");
			this.shuffle_button = (Gtk.ToggleToolButton) builder.get_object ("shuffle_button");
			this.track_label = (Gtk.Label) builder.get_object ("track_label");
			this.duration_label = (Gtk.Label) builder.get_object ("duration_label");
			this.progress_slider = (Gtk.HScale) builder.get_object ("progress_slider");
			this.track_list = (Gtk.TreeView) builder.get_object ("track_list");
	
			// Create the store that will drive the track list.
			this.list_store = new Gtk.ListStore (Columns.NUM_COLUMNS,
				typeof (string), // uri
				typeof (string), // status
				typeof (string), // title
				typeof (string), // artist
				typeof (string), // album
				typeof (string), // track
				typeof (string), // genre
				typeof (string));// duration
	
			// Set up the track list, store, and columns.
			set_up_track_list ();
	
			// Set the selection mode.
			this.browse_select = this.track_list.get_selection ();
			this.browse_select.set_mode (Gtk.SelectionMode.SINGLE);
	
			// Hook up some signals.
			set_up_signals ();

			// Update the interface to reflect the backend.
			set_up_interface ();
		}
	
		// Set up the track list.
		private void set_up_track_list ()
		{
			// Define sort functions and hook them up.
			this.list_store.set_sort_func (Columns.TITLE, (Gtk.TreeIterCompareFunc) title_sort);
			this.list_store.set_sort_func (Columns.ARTIST, (Gtk.TreeIterCompareFunc) artist_sort);
			this.list_store.set_sort_func (Columns.ALBUM, (Gtk.TreeIterCompareFunc) album_sort);
			this.list_store.set_sort_func (Columns.TRACK, (Gtk.TreeIterCompareFunc) track_sort);
			this.list_store.set_sort_func (Columns.GENRE, (Gtk.TreeIterCompareFunc) genre_sort);
			this.list_store.set_sort_func (Columns.DURATION, (Gtk.TreeIterCompareFunc) duration_sort);
	
			this.list_store.set_sort_column_id (Columns.ARTIST, Gtk.SortType.ASCENDING);
	
			// Attach the store to the track list.
			this.track_list.set_model (this.list_store);
	
			// Set up the display columns.
			Gtk.TreeViewColumn uri;
			Gtk.TreeViewColumn status;
			Gtk.TreeViewColumn title;
			Gtk.TreeViewColumn artist;
			Gtk.TreeViewColumn album;
			Gtk.TreeViewColumn track;
			Gtk.TreeViewColumn genre;
			Gtk.TreeViewColumn duration;
			Gtk.Image status_header;
	
			uri = new Gtk.TreeViewColumn.with_attributes ("URI", new Gtk.CellRendererText (), "text", Columns.URI);
			status = new Gtk.TreeViewColumn.with_attributes ("", new Gtk.CellRendererPixbuf (), "stock-id", Columns.STATUS);
			title = new Gtk.TreeViewColumn.with_attributes ("Title", new Gtk.CellRendererText (), "text", Columns.TITLE);
			artist = new Gtk.TreeViewColumn.with_attributes ("Artist", new Gtk.CellRendererText (), "text", Columns.ARTIST);
			album = new Gtk.TreeViewColumn.with_attributes ("Album", new Gtk.CellRendererText (), "text", Columns.ALBUM);
			track = new Gtk.TreeViewColumn.with_attributes ("#", new Gtk.CellRendererText (), "text", Columns.TRACK);
			genre = new Gtk.TreeViewColumn.with_attributes ("Genre", new Gtk.CellRendererText (), "text", Columns.GENRE);
			duration = new Gtk.TreeViewColumn.with_attributes ("Duration", new Gtk.CellRendererText (), "text", Columns.DURATION);
	
			// Hide the URI column.
			uri.set_visible (false);
	
			// Set up the sizing parameters for each column.
			status.set_sizing (Gtk.TreeViewColumnSizing.FIXED);
			title.set_sizing (Gtk.TreeViewColumnSizing.FIXED);
			artist.set_sizing (Gtk.TreeViewColumnSizing.FIXED);
			album.set_sizing (Gtk.TreeViewColumnSizing.FIXED);
			track.set_sizing (Gtk.TreeViewColumnSizing.FIXED);
			genre.set_sizing (Gtk.TreeViewColumnSizing.FIXED);
			duration.set_sizing (Gtk.TreeViewColumnSizing.FIXED);
	
			// Set up the image in the header of the status column.
			status_header = new Gtk.Image.from_stock (Gtk.STOCK_MEDIA_PLAY, Gtk.IconSize.MENU);
			status.set_widget (status_header);
			status_header.show ();
	
			// Define the column properties.
			status.set_fixed_width (22); // GConf? (to remember between sessions)
			title.set_expand (true);
			artist.set_expand (true);
			album.set_expand (true);
			track.set_fixed_width (48); // GConf?
			genre.set_expand (true);
			duration.set_fixed_width (72); // GConf?
	
			title.set_resizable (true);
			artist.set_resizable (true);
			album.set_resizable (true);
			track.set_resizable (true);
			genre.set_resizable (true);
			duration.set_resizable (true);
	
			// Glue it all together!
			this.track_list.append_column (uri);
			this.track_list.append_column (status);
			this.track_list.append_column (title);
			this.track_list.append_column (artist);
			this.track_list.append_column (album);
			this.track_list.append_column (track);
			this.track_list.append_column (genre);
			this.track_list.append_column (duration);
		}

		// Connect a bunch of signals to their handlers.
		/*
		 * FIXME: Add signals on events like next, prev, pause, stop, etc.
		 */
		private void set_up_signals ()
		{
			// If the window is closed, what's the point?
			this.window.destroy += quit;

			this.play_button.clicked += handle_play_clicked;
			this.pause_button.clicked += handle_pause_clicked;
			this.prev_button.clicked += handle_prev_clicked;
			this.next_button.clicked += handle_next_clicked;
			this.repeat_button.clicked += handle_repeat_clicked;
			this.shuffle_button.clicked += handle_shuffle_clicked;

			this.player.PlayingTrack += handle_playing_track;
			this.player.PausedPlayback += handle_paused_playback;
			this.player.StoppedPlayback += handle_stopped_playback;
			this.player.RepeatToggled += handle_repeat_toggled;
			this.player.ShuffleToggled += handle_shuffle_toggled;
		}

		// Bring the interface up to date with the back end.
		private void set_up_interface ()
		{
			string[] uris = this.player.GetPlaylist ();
			string playback_status = this.player.GetPlaybackStatus ();
			int position = this.player.GetCurrentTrack ();
			bool repeat_toggled = this.player.GetRepeat ();
			bool shuffle_toggled = this.player.GetShuffle ();

			foreach (string uri in uris)
			{
				this.playlist.append (this.store.make_track (uri));
			}

			switch (playback_status)
			{
				case "PLAYING":
					set_up_playing_state (position);
					break;
				case "PAUSED":
					set_up_paused_state (position);
					break;
				case "READY":
				default:
					set_up_stopped_state ();
					break;
			}

			this.repeat_button.active = repeat_toggled;
			this.shuffle_button.active = shuffle_toggled;
		}

		private void show_pause_button ()
		{
			this.play_button.visible_horizontal = false;
			this.pause_button.visible_horizontal = true;
		}	
		
		private void show_play_button ()
		{
			this.pause_button.visible_horizontal = false;
			this.play_button.visible_horizontal = true;
		}

		private void set_up_playing_state (int position)
		{
			Hum.Track track = this.playlist.index (position);
			this.window.title = "%s - %s".printf(track.artist, track.title);
			this.track_label.set_markup("<b>%s</b> by <i>%s</i> from <i>%s</i>".printf(track.title, track.artist, track.album));
			show_pause_button ();
		}

		private void set_up_paused_state (int position)
		{
			Hum.Track track = this.playlist.index (position);
			this.window.title = "%s - %s (paused)".printf(track.artist, track.title);
			this.track_label.set_markup("<b>%s</b> by <i>%s</i> from <i>%s</i>".printf(track.title, track.artist, track.album));
			show_play_button ();
		}

		private void set_up_stopped_state ()
		{
			this.window.title = "Music Player";
			this.track_label.set_markup("<b>Not Playing</b>");
			show_play_button ();
		}

		// Pass along the command to play the current track or resume play.
		// FIXME: If an item is selected in the playlist, play that item instead of
		//        just blindly passing along -1.
		public void handle_play_clicked ()
		{
			this.player.Play (-1);
		}

		// Pass along the command to pause playback.
		public void handle_pause_clicked ()
		{
			this.player.Pause ();
		}

		// Pass along the command to play the previous track.
		public void handle_prev_clicked ()
		{
			this.player.Previous ();
		}

		// Pass along the command to play the next track.
		public void handle_next_clicked ()
		{
			this.player.Next ();
		}

		public void handle_repeat_clicked ()
		{
			this.player.SetRepeat (this.repeat_button.active);
		}

		public void handle_shuffle_clicked ()
		{
			this.player.SetShuffle (this.shuffle_button.active);
		}

		public void handle_playing_track (dynamic DBus.Object player, int position)
		{
			set_up_playing_state (position);
		}

		public void handle_paused_playback ()
		{
			set_up_paused_state (this.player.GetCurrentTrack ());
		}

		public void handle_stopped_playback ()
		{
			set_up_stopped_state ();
		}

		public void handle_repeat_toggled (dynamic DBus.Object player, bool do_repeat)
		{
			this.repeat_button.active = do_repeat;
		}
		
		public void handle_shuffle_toggled (dynamic DBus.Object player, bool do_shuffle)
		{
			this.shuffle_button.active = do_shuffle;
		}

		public void quit ()
		{
			this.player.Quit ();
			Gtk.main_quit ();
		}
	}
	
	static int main (string[] args)
	{
		Gtk.init (ref args);
		
		var app = new Hum.UserInterface (args);
		app.window.show_all ();
	
		Gtk.main ();
		
		return 0;
	}
}	
