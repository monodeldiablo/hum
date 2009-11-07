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

// FIXME: Use TreeView.get_visible_range () to minimize the number of items in the search box.

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
		public Gtk.Entry search_entry;
		public Gtk.Button search_button;
		public Gtk.VPaned view_separator;
		public Gtk.TreeView search_list;
		public Gtk.TreeView track_list;
		public Gtk.ListStore search_store;
		public Gtk.ListStore playlist_store;
		public Gtk.TreeSelection browse_select;

		private Gtk.TreeIter current_iter;
		private double current_progress = 0.0;

		private string ui_file = "main.ui";
		private int update_timeout_id = -1;
		private int update_period = 500;
		
		private DBus.Connection conn;
		private dynamic DBus.Object player;
		private Hum.QueryEngine query_engine;
	
		public UserInterface (string [] args)
		{
			this.conn = DBus.Bus.get (DBus.BusType.SESSION);

			// Fetch the player backend.
			// FIXME: If no backend exists, one should be launched.
			this.player = conn.get_object ("org.washedup.Hum",
				"/org/washedup/Hum",
				"org.washedup.Hum");
			
			this.query_engine = new Hum.QueryEngine ();

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
			this.search_entry = (Gtk.Entry) builder.get_object ("search_entry");
			this.search_button = (Gtk.Button) builder.get_object ("search_button");
			this.view_separator = (Gtk.VPaned) builder.get_object ("view_separator");
			this.track_list = (Gtk.TreeView) builder.get_object ("track_list");
	
			// Create the store that will drive the track list.
			this.playlist_store = new Gtk.ListStore (Columns.NUM_COLUMNS,
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
			this.playlist_store.set_sort_func (Columns.TITLE, (Gtk.TreeIterCompareFunc) title_sort);
			this.playlist_store.set_sort_func (Columns.ARTIST, (Gtk.TreeIterCompareFunc) artist_sort);
			this.playlist_store.set_sort_func (Columns.ALBUM, (Gtk.TreeIterCompareFunc) album_sort);
			this.playlist_store.set_sort_func (Columns.TRACK, (Gtk.TreeIterCompareFunc) track_sort);
			this.playlist_store.set_sort_func (Columns.GENRE, (Gtk.TreeIterCompareFunc) genre_sort);
			this.playlist_store.set_sort_func (Columns.DURATION, (Gtk.TreeIterCompareFunc) duration_sort);
	
			// FIXME: Search panes should be sorted, but not the playlist.
			//this.search_store.set_sort_column_id (Columns.ARTIST, Gtk.SortType.ASCENDING);
	
			// Attach the store to the track list.
			this.track_list.set_model (this.playlist_store);
	
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

			this.progress_slider.value_changed += handle_slider_moved;
			
			// FIXME: Double-clicking on a row in the search pane appends the track to
			//        the playlist.
			//this.search_list.row_activated += handle_play_clicked;
			this.track_list.row_activated += handle_track_list_selected;

			// Signals from hum-player.
			this.player.PlayingTrack += handle_playing_track;
			this.player.PausedPlayback += handle_paused_playback;
			this.player.StoppedPlayback += handle_stopped_playback;
			this.player.RepeatToggled += handle_repeat_toggled;
			this.player.ShuffleToggled += handle_shuffle_toggled;
			this.player.TrackAdded += handle_track_added;
		}

		// Bring the interface up to date with the back end.
		private void set_up_interface ()
		{
			string[] uris = this.player.GetPlaylist ();
			string playback_status = this.player.GetPlaybackStatus ();
			int position = this.player.GetCurrentTrack ();
			bool repeat_toggled = this.player.GetRepeat ();
			bool shuffle_toggled = this.player.GetShuffle ();
			int i = 0;

			// Hide the search view at start up.
			this.view_separator.set_position (0);

			foreach (string uri in uris)
			{
				add_track_to_view (uri, i);
				i++;
			}

			// Clear the player's state.
			set_up_stopped_state ();

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
			Hum.Track track = this.query_engine.make_track (this.player.GetCurrentUri ());
			
			// Set the various text bits to reflect the current song.
			this.window.title = "%s - %s".printf(track.artist, track.title);
			this.track_label.set_markup("<b>%s</b> by <i>%s</i> from <i>%s</i>".printf(track.title, track.artist, track.album));

			// Set the 'playing' icon in the row of the track that's playing.
			Gtk.TreePath path = new Gtk.TreePath.from_indices (position, -1);
			this.playlist_store.get_iter (out this.current_iter, path);
			this.playlist_store.set (this.current_iter,
				Columns.STATUS, "gtk-media-play", -1);

			// Add a timeout to update the track progress.
			// FIXME: We should also remove this timeout when the track stops, to keep
			//        the app from stupidly pinging Hum for updates every half a second.
			this.progress_slider.set_range (0.0, (double) track.duration);
			this.update_timeout_id = (int) GLib.Timeout.add (this.update_period, update_track_progress);

			// Swap the play and pause buttons.
			show_pause_button ();

			// Reactivate the previous and next buttons.
			if (position > 0 || this.repeat_button.active)
			{
				this.prev_button.sensitive = true;
			}
			if (position < this.playlist_store.length - 1 || this.repeat_button.active)
			{
				this.next_button.sensitive = true;
			}
		}

		private void set_up_paused_state (int position)
		{
			Hum.Track track = this.query_engine.make_track (this.player.GetCurrentUri ());
			
			// Set the 'paused' icon in the row of the track that's paused.
			Gtk.TreePath path = new Gtk.TreePath.from_indices (position, -1);
			this.playlist_store.get_iter (out this.current_iter, path);
			this.playlist_store.set (this.current_iter,
				Columns.STATUS, "gtk-media-pause", -1);

			// Set the various text bits to reflect the current song.
			this.window.title = "%s - %s (paused)".printf(track.artist, track.title);
			this.track_label.set_markup("<b>%s</b> by <i>%s</i> from <i>%s</i>".printf(track.title, track.artist, track.album));
			this.progress_slider.set_range (0.0, (float) track.duration);
			update_track_progress ();
			
			// Swap the pause and play buttons.
			show_play_button ();

			// Reactivate the previous and next buttons.
			if (position > 0 || this.repeat_button.active)
			{
				this.prev_button.sensitive = true;
			}
			if (position < this.playlist_store.length - 1 || this.repeat_button.active)
			{
				this.next_button.sensitive = true;
			}
		}

		private void set_up_stopped_state ()
		{
			// Clear the necessary text bits.
			this.window.title = "Music Player";
			this.track_label.set_markup("<b>Not Playing</b>");

			// Swap the pause and play buttons.
			show_play_button ();

			// Deactivate the previous and next buttons.
			this.prev_button.sensitive = false;
			this.next_button.sensitive = false;

			// Remove the timeout and reset the slider.
			if (this.update_timeout_id != -1)
			{
				GLib.Source.remove ((uint) this.update_timeout_id);
				this.update_timeout_id = -1;
			}
			this.progress_slider.set_value (0.0);
			this.progress_slider.set_range (0.0, 1.0);

			// Clear the 'playing'/'paused' icon from any row, if one was present.
			if (this.playlist_store.iter_is_valid (this.current_iter))
			{
				this.playlist_store.set (this.current_iter,	Columns.STATUS, "", -1);

				// Reset the current_iter pointer.
				this.playlist_store.get_iter_first (out this.current_iter);
			}
		}

		private void add_track_to_view (string uri, int position)
		{
			Gtk.TreeIter iter;
			Hum.Track track = this.query_engine.make_track (uri);

			this.playlist_store.insert (out iter, position);
			this.playlist_store.set (iter,
				Columns.URI, track.uri,
				Columns.TITLE, track.title,
				Columns.ARTIST, track.artist,
				Columns.ALBUM, track.album,
				Columns.TRACK, track.track_number.to_string (),
				Columns.GENRE, track.genre,
				Columns.DURATION, usec_to_string (track.duration),
				-1);
		}

		private bool update_track_progress ()
		{
			int64 progress = this.player.GetProgress ();
			GLib.Value duration;

			this.playlist_store.get_value (this.current_iter, Columns.DURATION, out duration);
			this.duration_label.set_text ("%s of %s".printf (usec_to_string (progress), (string) duration));
			
			// FIXME: If we want to hook into the "value_changed" signal later to
			//        control seeking, this could be an issue...
			this.current_progress = (double) progress;
			this.progress_slider.set_value ((double) progress);

			return true;
		}

		public void handle_track_list_selected (Gtk.TreePath path, Gtk.TreeViewColumn column)
		{
			int track = path.to_string ().to_int ();
			this.player.Play (track);
		}

		// Pass along the command to play the current track or resume play.
		// FIXME: If an item is selected in the playlist, play that item instead of
		//        just blindly passing along -1.
		public void handle_play_clicked ()
		{
			Gtk.TreeIter selection;
			Gtk.TreeModel model = (Gtk.TreeModel) this.playlist_store;
			bool is_selected = this.browse_select.get_selected (out model, out selection);
			bool selection_is_valid = this.playlist_store.iter_is_valid (selection);
			string status = this.player.GetPlaybackStatus ();
			int track;
			
			// If playback is currently paused, just resume.
			if (status == "PAUSED" && selection_is_valid && is_selected)
			{
				Gtk.TreePath path = this.playlist_store.get_path (selection);
				track = path.to_string ().to_int ();
			}

			else
			{
				track = -1;
			}

			this.player.Play (track);
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
			
			// Change the sensitivity of the previous and next buttons at the extremes
			// of the playlist to reflect the (dis)ability to loop.
			if (this.playlist_store.iter_is_valid (this.current_iter))
			{
				Gtk.TreePath path = this.playlist_store.get_path (this.current_iter);

				if (path.to_string ().to_int () == 0)
				{
					this.prev_button.sensitive = this.repeat_button.active;
				}

				else if (path.to_string ().to_int () == this.playlist_store.length - 1)
				{
					this.next_button.sensitive = this.repeat_button.active;
				}
			}
		}

		public void handle_shuffle_clicked ()
		{
			this.player.SetShuffle (this.shuffle_button.active);
		}

		public void handle_slider_moved ()
		{
			double position = this.progress_slider.get_value ();

			// If the slider has moved more than it normally does between updates from
			// the back end, then the user probably moved it. If they actually moved it
			// less than this distance, well... they can just wait the extra 500ms.
			if (position > this.current_progress + this.update_period ||
				position < this.current_progress)
			{
				this.player.Seek ((int64) position);
			}
			else
			{
				this.current_progress = position;
			}
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

		public void handle_track_added (dynamic DBus.Object player, string uri, int position)
		{
			add_track_to_view (uri, position);
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
