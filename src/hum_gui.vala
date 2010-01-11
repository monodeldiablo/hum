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

using Config;
using GLib;
using Gtk;
using DBus;

namespace Hum
{
	public enum Columns
	{
		URI,
		STATUS_OR_ADD_TO_PLAYLIST,
		TITLE,
		ARTIST,
		ALBUM,
		TRACK,
		GENRE,
		RELEASE_DATE,
		DURATION,
		BITRATE,
		FILE_SIZE,
		NUM_COLUMNS
	}

	public class UserInterface
	{
		/* Actions */

		public Gtk.Action open_action;
		public Gtk.Action save_action;
		public Gtk.Action save_as_action;
		public Gtk.Action properties_action;
		public Gtk.Action quit_action;
		public Gtk.Action cut_action;
		public Gtk.Action copy_action;
		public Gtk.Action paste_action;
		public Gtk.Action select_all_action;
		public Gtk.Action deselect_all_action;
		public Gtk.Action add_action;
		public Gtk.Action remove_action;
		public Gtk.Action clear_action;
		public Gtk.Action preferences_action;
		public Gtk.Action about_action;

		/* Action Groups */

		public Gtk.ActionGroup global_actions;
		public Gtk.ActionGroup search_actions;
		public Gtk.ActionGroup playlist_actions;
		public Gtk.ActionGroup track_actions;

		/* Widgets */

		public Gtk.Window window;
		public Gtk.AboutDialog about_dialog;
		public Gtk.Dialog properties_dialog;
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
		public Gtk.TreeView search_view;
		public Gtk.TreeView playlist_view;
		public Gtk.ListStore search_store;
		public Gtk.ListStore playlist_store;
		public Gtk.TreeSelection search_select;
		public Gtk.TreeSelection playlist_select;

		private Gtk.TreeIter current_iter;
		private double current_progress = 0.0;

		private int update_timeout_id = -1;
		private int update_period = 500;
		private int animate_timeout_id = -1;
		private int animate_period = 100;
		private int animate_increment = 20;
		private int search_results_height = 100;

		private DBus.Connection conn;
		private dynamic DBus.Object player;
		private Hum.QueryEngine query_engine;
	
		public UserInterface (string [] args)
		{
			try
			{
				this.conn = DBus.Bus.get (DBus.BusType.SESSION);
			}
			catch (DBus.Error e)
			{
				critical ("Error connecting to the Hum daemon: %s", e.message);
				quit ();
			}

			// Fetch the player backend.
			this.player = conn.get_object ("org.washedup.Hum",
				"/org/washedup/Hum",
				"org.washedup.Hum");

			this.query_engine = new Hum.QueryEngine ();

			// Construct the window and its child widgets from the UI definition.
			Gtk.Builder builder = new Gtk.Builder ();
			string path = GLib.Path.build_filename (Config.PACKAGE_DATADIR, "main.ui");

			try
			{
				builder.add_from_file (path);
			}
			catch (GLib.Error e)
			{
				stderr.printf ("Error loading the interface definition file: %s\n", e.message);
				quit ();
			}

			// Create action groups.
			this.global_actions = new Gtk.ActionGroup ("global_actions");
			this.search_actions = new Gtk.ActionGroup ("search_actions");
			this.playlist_actions = new Gtk.ActionGroup ("playlist_actions");
			this.track_actions = new Gtk.ActionGroup ("track_actions");

			// Assign actions to variables for signal handling.
			this.open_action = (Gtk.Action) builder.get_object ("open_action");
			this.save_action = (Gtk.Action) builder.get_object ("save_action");
			this.save_as_action = (Gtk.Action) builder.get_object ("save_as_action");
			this.properties_action = (Gtk.Action) builder.get_object ("properties_action");
			this.quit_action = (Gtk.Action) builder.get_object ("quit_action");
			this.cut_action = (Gtk.Action) builder.get_object ("cut_action");
			this.copy_action = (Gtk.Action) builder.get_object ("copy_action");
			this.paste_action = (Gtk.Action) builder.get_object ("paste_action");
			this.select_all_action = (Gtk.Action) builder.get_object ("select_all_action");
			this.deselect_all_action = (Gtk.Action) builder.get_object ("deselect_all_action");
			this.add_action = (Gtk.Action) builder.get_object ("add_action");
			this.remove_action = (Gtk.Action) builder.get_object ("remove_action");
			this.clear_action = (Gtk.Action) builder.get_object ("clear_action");
			this.preferences_action = (Gtk.Action) builder.get_object ("preferences_action");
			this.about_action = (Gtk.Action) builder.get_object ("about_action");

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
			this.playlist_view = (Gtk.TreeView) builder.get_object ("playlist_view");
			this.search_view = (Gtk.TreeView) builder.get_object ("search_view");

			// Create the store that will drive the track list.
			this.playlist_store = new Gtk.ListStore (Columns.NUM_COLUMNS,
				typeof (string), // uri
				typeof (string), // status
				typeof (string), // title
				typeof (string), // artist
				typeof (string), // album
				typeof (string), // track
				typeof (string), // genre
				typeof (string), // release_date
				typeof (string), // duration
				typeof (string), // bitrate
				typeof (string));// file size

			// Create the store that will drive the search list.
			this.search_store = new Gtk.ListStore (Columns.NUM_COLUMNS,
				typeof (string), // uri
				typeof (string), // add_to_playlist
				typeof (string), // title
				typeof (string), // artist
				typeof (string), // album
				typeof (string), // track
				typeof (string), // genre
				typeof (string), // release_date
				typeof (string), // duration
				typeof (string), // bitrate
				typeof (string));// file size

			// Connect the stores to their corresponding views.
			set_up_list_view (this.playlist_store, this.playlist_view);
			set_up_list_view (this.search_store, this.search_view);

			// Set the selection mode.
			this.search_select = this.search_view.get_selection ();
			this.search_select.set_mode (Gtk.SelectionMode.MULTIPLE);
			this.playlist_select = this.playlist_view.get_selection ();
			this.playlist_select.set_mode (Gtk.SelectionMode.SINGLE);

			// Initialize the actions and action groups.
			set_up_actions ();

			// Hook up some signals.
			set_up_signals ();

			// Update the interface to reflect the backend.
			set_up_interface ();

			// If the application was launched with arguments, try
			// to load them as tracks.
			if (args.length > 1)
			{
				for (int i = 1; i < args.length; i++)
				{
					try
					{
						string uri = GLib.Filename.to_uri (args[i]);
						this.player.AddTrack (uri, -1);
					}
					catch (GLib.ConvertError e)
					{
						critical ("Error converting %s to a URI: %s", args[i], e.message);
					}
				}

				this.player.Play (-1);
			}
		}

		// Set up the actions and action groups.
		private void set_up_actions ()
		{
			// Define globally-accessible actions.
			this.global_actions.add_action_with_accel (this.open_action, "<control>O");
			this.global_actions.add_action_with_accel (this.quit_action, "<control>Q");
			this.global_actions.add_action (this.preferences_action);
			this.global_actions.add_action (this.about_action);

			// Define search-dependent actions.
			this.search_actions.add_action_with_accel (this.select_all_action, "<control>A");
			this.search_actions.add_action_with_accel (this.deselect_all_action, "<shift><control>A");
			this.search_actions.add_action_with_accel (this.add_action, "a");

			// Define playlist-dependent actions.
			this.playlist_actions.add_action_with_accel (this.properties_action, "<alt>Return");
			this.playlist_actions.add_action_with_accel (this.cut_action, "<control>X");
			this.playlist_actions.add_action_with_accel (this.copy_action, "<control>C");
			this.playlist_actions.add_action_with_accel (this.paste_action, "<control>V");
			this.playlist_actions.add_action_with_accel (this.remove_action, "Delete");
			this.playlist_actions.add_action_with_accel (this.clear_action, "<shift>Delete");

			this.global_actions.sensitive = true;
			this.search_actions.sensitive = false;
			this.playlist_actions.sensitive = false;
		}

		// Connect a bunch of signals to their handlers.
		private void set_up_signals ()
		{
			this.window.destroy += quit;
			this.quit_action.activate += quit;

			this.about_action.activate += show_about_dialog;
			this.properties_action.activate += show_properties_dialog;

			this.playlist_select.changed += handle_playlist_select_changed;
			this.search_select.changed += handle_search_select_changed;

			this.play_button.clicked += handle_play_clicked;
			this.pause_button.clicked += handle_pause_clicked;
			this.prev_button.clicked += handle_prev_clicked;
			this.next_button.clicked += handle_next_clicked;
			this.repeat_button.clicked += handle_repeat_clicked;
			this.shuffle_button.clicked += handle_shuffle_clicked;

			this.progress_slider.value_changed += handle_slider_moved;
			this.search_button.clicked += handle_search_requested;
			this.search_entry.changed += handle_search_requested;
			this.search_entry.icon_release += handle_search_cleared;

			this.search_view.row_activated += handle_search_view_selected;
			this.search_view.drag_data_get += handle_drag_data_get;
			this.playlist_view.row_activated += handle_playlist_view_selected;
			this.playlist_view.key_press_event += handle_playlist_view_key_pressed;
			this.playlist_view.drag_data_received += handle_drag_data_received;

			// Signals from hum-player.
			this.player.PlayingTrack += handle_playing_track;
			this.player.PausedPlayback += handle_paused_playback;
			this.player.StoppedPlayback += handle_stopped_playback;
			this.player.Seeked += handle_seeked;
			this.player.RepeatToggled += handle_repeat_toggled;
			this.player.ShuffleToggled += handle_shuffle_toggled;
			this.player.TrackAdded += handle_track_added;
			this.player.TrackRemoved += handle_track_removed;
			this.player.Exiting += quit;
		}

		// Bring the interface up to date with the back end.
		private void set_up_interface ()
		{
			string[] uris = this.player.GetPlaylist ();
			string playback_status = this.player.GetPlaybackStatus ();
			int position = this.player.GetCurrentTrack ();
			bool repeat_toggled = this.player.GetRepeat ();
			bool shuffle_toggled = this.player.GetShuffle ();

			// Hide the search view at start up.
			this.view_separator.set_position (0);

			foreach (string uri in uris)
			{
				add_track_to_view (this.playlist_store, uri);
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

		// Set up the search and playlist views.
		private void set_up_list_view (Gtk.ListStore store, Gtk.TreeView view)
		{
			// Define sort functions and hook them up.
			store.set_sort_func (Columns.TITLE, (Gtk.TreeIterCompareFunc) title_sort);
			store.set_sort_func (Columns.ARTIST, (Gtk.TreeIterCompareFunc) artist_sort);
			store.set_sort_func (Columns.ALBUM, (Gtk.TreeIterCompareFunc) album_sort);
			store.set_sort_func (Columns.TRACK, (Gtk.TreeIterCompareFunc) track_sort);
			store.set_sort_func (Columns.GENRE, (Gtk.TreeIterCompareFunc) genre_sort);
			store.set_sort_func (Columns.DURATION, (Gtk.TreeIterCompareFunc) duration_sort);
	
			// Search panes should be sorted by default, but not the playlist.
			if (store == this.search_store)
			{
				store.set_sort_column_id (Columns.ARTIST, Gtk.SortType.ASCENDING);
			}
	
			// Attach the store to the track list.
			view.set_model (store);
	
			// Set up the display columns.
			Gtk.TreeViewColumn uri;
			Gtk.TreeViewColumn status_or_add_to_playlist;
			Gtk.TreeViewColumn title;
			Gtk.TreeViewColumn artist;
			Gtk.TreeViewColumn album;
			Gtk.TreeViewColumn track;
			Gtk.TreeViewColumn genre;
			Gtk.TreeViewColumn release_date;
			Gtk.TreeViewColumn duration;
			Gtk.TreeViewColumn bitrate;
			Gtk.TreeViewColumn file_size;
			Gtk.Image status_or_add_to_playlist_header;

			Gtk.CellRendererText renderer = new Gtk.CellRendererText ();
			renderer.ellipsize = Pango.EllipsizeMode.END;

			uri = new Gtk.TreeViewColumn.with_attributes ("URI", renderer, "text", Columns.URI);
			status_or_add_to_playlist = new Gtk.TreeViewColumn.with_attributes ("", new Gtk.CellRendererPixbuf (), "stock-id", Columns.STATUS_OR_ADD_TO_PLAYLIST);
			title = new Gtk.TreeViewColumn.with_attributes ("Title", renderer, "text", Columns.TITLE);
			artist = new Gtk.TreeViewColumn.with_attributes ("Artist", renderer, "text", Columns.ARTIST);
			album = new Gtk.TreeViewColumn.with_attributes ("Album", renderer, "text", Columns.ALBUM);
			track = new Gtk.TreeViewColumn.with_attributes ("#", renderer, "text", Columns.TRACK);
			genre = new Gtk.TreeViewColumn.with_attributes ("Genre", renderer, "text", Columns.GENRE);
			release_date = new Gtk.TreeViewColumn.with_attributes ("Release Date", renderer, "text", Columns.RELEASE_DATE);
			duration = new Gtk.TreeViewColumn.with_attributes ("Duration", renderer, "text", Columns.DURATION);
			bitrate = new Gtk.TreeViewColumn.with_attributes ("Bitrate", renderer, "text", Columns.BITRATE);
			file_size = new Gtk.TreeViewColumn.with_attributes ("File Size", renderer, "text", Columns.FILE_SIZE);
	
			// Hide the columns we don't need to show to the user.
			uri.set_visible (false);
			release_date.set_visible (false);
			bitrate.set_visible (false);
			file_size.set_visible (false);
	
			// Set up the sizing parameters for each column.
			status_or_add_to_playlist.set_sizing (Gtk.TreeViewColumnSizing.FIXED);
			title.set_sizing (Gtk.TreeViewColumnSizing.FIXED);
			artist.set_sizing (Gtk.TreeViewColumnSizing.FIXED);
			album.set_sizing (Gtk.TreeViewColumnSizing.FIXED);
			track.set_sizing (Gtk.TreeViewColumnSizing.FIXED);
			genre.set_sizing (Gtk.TreeViewColumnSizing.FIXED);
			duration.set_sizing (Gtk.TreeViewColumnSizing.FIXED);

			// Set up DND-related bits.
			TargetEntry other_row = {
				"OTHER_ROW",
				Gtk.TargetFlags.SAME_WIDGET,
				0};
			TargetEntry search_entry = {
				"SEARCH_RESULT",
				Gtk.TargetFlags.SAME_APP,
				0};
			TargetEntry file = {
				"STRING",
				0,
				1};
			TargetEntry file_alt = {
				"text/plain",
				0,
				1};
			TargetEntry uri_list = {
				"text/uri-list",
				0,
				2};

			TargetEntry[] target_list = {
				other_row,
				search_entry,
				file,
				file_alt,
				uri_list};

			// Configure some playlist-specific stuff.
			// FIXME: Set the search column to Columns.TITLE to allow searching within
			//        the playlist.
			if (view == this.playlist_view)
			{
				// Set up the image in the header of the status_or_add_to_playlist column.
				status_or_add_to_playlist_header = new Gtk.Image.from_stock (Gtk.STOCK_MEDIA_PLAY, Gtk.IconSize.MENU);
				view.set_headers_clickable (false);

				// Set up drag and drop receivership. The playlist view should be able to
				// receive dragged items from inside the widget (other rows), other
				// widgets (the search results view), and other apps (tracks dragged from
				// the desktop).
				view.enable_model_drag_source (Gdk.ModifierType.BUTTON1_MASK,
					{target_list[0]},
					Gdk.DragAction.MOVE);
				view.enable_model_drag_dest (target_list,
					Gdk.DragAction.DEFAULT | Gdk.DragAction.MOVE);
			}
			else
			{
				// Set up the image in the header of the status_or_add_to_playlist column.
				status_or_add_to_playlist_header = new Gtk.Image.from_stock (Gtk.STOCK_ADD, Gtk.IconSize.MENU);
				view.set_headers_clickable (true);

				// Set up drag and drop sender capability. Items from here should only be
				// draggable to the playlist.
				Gtk.drag_source_set (view,
					Gdk.ModifierType.BUTTON1_MASK,
					{target_list[1]},
					Gdk.DragAction.MOVE);
			}
			
			status_or_add_to_playlist.set_widget (status_or_add_to_playlist_header);
			status_or_add_to_playlist_header.show ();
	
			// Define the column properties.
			status_or_add_to_playlist.set_fixed_width (22); // GConf? (to remember between sessions)
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
			view.append_column (uri);
			view.append_column (status_or_add_to_playlist);
			view.append_column (title);
			view.append_column (artist);
			view.append_column (album);
			view.append_column (track);
			view.append_column (genre);
			view.append_column (release_date);
			view.append_column (duration);
			view.append_column (bitrate);
			view.append_column (file_size);
		}

		private void show_about_dialog ()
		{
			Gtk.Builder about_ui = new Gtk.Builder ();
			string path = GLib.Path.build_filename (Config.PACKAGE_DATADIR, "about.ui");

			try
			{
				about_ui.add_from_file (path);
			}
			catch (GLib.Error e)
			{
				stderr.printf ("Error loading the interface definition file: %s\n", e.message);
			}

			// Assign the widgets to a variable for manipulation later.
			this.about_dialog = (Gtk.AboutDialog) about_ui.get_object ("about_dialog");

			this.about_dialog.version = Config.VERSION;

			// Hook up the "close" action.
			this.about_dialog.response += handle_about_dialog_response;

			this.about_dialog.show_all ();
		}

		private void handle_about_dialog_response (int response_id)
		{
			// NOTE: Apparently, the response_id for the "Close" button is -6...
			if (response_id == -6)
			{
				this.about_dialog.close ();
			}
		}

		private void show_properties_dialog ()
		{
			// Verify that a track is selected and, if so, fill in the track metadata.
			Gtk.TreeIter selection;
			Gtk.TreeModel model;
			bool is_selected = this.playlist_select.get_selected (out model, out selection);
			bool selection_is_valid = this.playlist_store.iter_is_valid (selection);

			if (is_selected && selection_is_valid)
			{
				// Load the UI description file.
				Gtk.Builder properties_ui = new Gtk.Builder ();
				string path = GLib.Path.build_filename (Config.PACKAGE_DATADIR, "properties.ui");

				try
				{
					properties_ui.add_from_file (path);
				}
				catch (GLib.Error e)
				{
					stderr.printf ("Error loading the interface definition file: %s\n", e.message);
				}

				// Assign the widgets to a variable for manipulation later.
				this.properties_dialog = (Gtk.Dialog) properties_ui.get_object ("properties_dialog");
				Gtk.Action close_action = (Gtk.Action) properties_ui.get_object ("close_action");

				Gtk.Label title_value = (Gtk.Label) properties_ui.get_object ("title_value");
				Gtk.Label artist_value = (Gtk.Label) properties_ui.get_object ("artist_value");
				Gtk.Label album_value = (Gtk.Label) properties_ui.get_object ("album_value");
				Gtk.Label genre_value = (Gtk.Label) properties_ui.get_object ("genre_value");
				Gtk.Label track_value = (Gtk.Label) properties_ui.get_object ("track_value");
				Gtk.Label release_date_value = (Gtk.Label) properties_ui.get_object ("release_date_value");
				Gtk.Label duration_value = (Gtk.Label) properties_ui.get_object ("duration_value");
				Gtk.Label bitrate_value = (Gtk.Label) properties_ui.get_object ("bitrate_value");
				Gtk.Label file_size_value = (Gtk.Label) properties_ui.get_object ("file_size_value");
				Gtk.Label location_value = (Gtk.Label) properties_ui.get_object ("location_value");

				// Pull the values for this track out of the list store.
				GLib.Value uri;
				GLib.Value title;
				GLib.Value artist;
				GLib.Value album;
				GLib.Value genre;
				GLib.Value track;
				GLib.Value release_date;
				GLib.Value duration;
				GLib.Value bitrate;
				GLib.Value file_size;

				this.playlist_store.get_value (selection, Columns.URI, out uri);
				this.playlist_store.get_value (selection, Columns.TITLE, out title);
				this.playlist_store.get_value (selection, Columns.ARTIST, out artist);
				this.playlist_store.get_value (selection, Columns.ALBUM, out album);
				this.playlist_store.get_value (selection, Columns.GENRE, out genre);
				this.playlist_store.get_value (selection, Columns.TRACK, out track);
				this.playlist_store.get_value (selection, Columns.RELEASE_DATE, out release_date);
				this.playlist_store.get_value (selection, Columns.DURATION, out duration);
				this.playlist_store.get_value (selection, Columns.BITRATE, out bitrate);
				this.playlist_store.get_value (selection, Columns.FILE_SIZE, out file_size);

				title_value.set_text ((string) title);
				artist_value.set_text ((string) artist);
				album_value.set_text ((string) album);
				genre_value.set_text ((string) genre);
				track_value.set_text ((string) track);
				release_date_value.set_text ((string) release_date);
				duration_value.set_text ((string) duration);
				bitrate_value.set_text ((string) bitrate);
				file_size_value.set_text ((string) file_size);

				try
				{
					location_value.set_text (GLib.Filename.from_uri ((string) uri));
				}
				catch (GLib.Error e)
				{
					location_value.set_text ("unknown");

					critical ("Error while converting '%s' to a path: %s", (string) uri, e.message);
				}

				this.properties_dialog.set_title ("%s Properties".printf ((string) title));

				// Hook up the "close" action.
				close_action.activate += close_properties_dialog;

				this.properties_dialog.show_all ();
			}
		}

		private void handle_playlist_select_changed ()
		{
			this.playlist_actions.sensitive = true;
		}

		private void handle_search_select_changed ()
		{
			this.search_actions.sensitive = true;
		}

		private void close_properties_dialog ()
		{
			this.properties_dialog.close ();
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

			string title_markup = GLib.Markup.escape_text (track.title);
			string artist_markup = GLib.Markup.escape_text (track.artist);
			string album_markup = GLib.Markup.escape_text (track.album);

			this.track_label.set_markup("<b>%s</b> by <i>%s</i> from <i>%s</i>".printf(title_markup, artist_markup, album_markup));

			// Set the 'playing' icon in the row of the track that's playing.
			Gtk.TreePath path = new Gtk.TreePath.from_indices (position, -1);
			this.playlist_store.get_iter (out this.current_iter, path);
			this.playlist_store.set (this.current_iter,
				Columns.STATUS_OR_ADD_TO_PLAYLIST, "gtk-media-play", -1);

			// Add a timeout to update the track progress.
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
				Columns.STATUS_OR_ADD_TO_PLAYLIST, "gtk-media-pause", -1);

			// Set the various text bits to reflect the current song.
			this.window.title = "%s - %s (paused)".printf(track.artist, track.title);

			string title_markup = GLib.Markup.escape_text (track.title);
			string artist_markup = GLib.Markup.escape_text (track.artist);
			string album_markup = GLib.Markup.escape_text (track.album);

			this.track_label.set_markup("<b>%s</b> by <i>%s</i> from <i>%s</i>".printf(title_markup, artist_markup, album_markup));
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
				this.playlist_store.set (this.current_iter, Columns.STATUS_OR_ADD_TO_PLAYLIST, "", -1);

				// Reset the current_iter pointer.
				this.playlist_store.get_iter_first (out this.current_iter);
			}
		}

		private void toggle_play ()
		{
			Gtk.TreeIter selection;
			Gtk.TreeModel model = (Gtk.TreeModel) this.playlist_store;
			bool is_selected = this.playlist_select.get_selected (out model, out selection);
			bool selection_is_valid = this.playlist_store.iter_is_valid (selection);
			string status = this.player.GetPlaybackStatus ();
			int track = -1;

			// If playback is currently paused and the selected track is also the
			// playing track, just resume.
			if (is_selected && selection_is_valid)
			{
				int position = this.playlist_store.get_path (selection).to_string ().to_int ();
				int current_position = this.player.GetCurrentTrack ();

				if (status != "PAUSED" || position != current_position)
				{
					track = position;
				}
			}

			this.player.Play (track);
		}

		private void add_track_to_view (Gtk.ListStore store, string uri, int position = -1)
		{
			Gtk.TreeIter iter;
			Hum.Track track = this.query_engine.make_track (uri);

			if (position == -1)
			{
				store.append (out iter);
			}

			else
			{
				store.insert (out iter, position);
			}

			store.set (iter,
				Columns.URI, track.uri,
				Columns.TITLE, track.title,
				Columns.ARTIST, track.artist,
				Columns.ALBUM, track.album,
				Columns.TRACK, track.track_number.to_string (),
				Columns.GENRE, track.genre,
				Columns.RELEASE_DATE, Time.gm ((time_t) track.release_date.to_int ()).year.to_string (),
				Columns.DURATION, usec_to_string (track.duration),
				Columns.BITRATE, "%d kbps".printf (track.bitrate.to_int () / 1000),
				Columns.FILE_SIZE, "%0.2f MB".printf ((track.file_size.to_int ()) / (1024.0 * 1024.0)),
				-1);
		}

		private void remove_track_from_view (Gtk.ListStore store, int position)
		{
			Gtk.TreeIter iter;
			
			this.playlist_store.get_iter (out iter, new Gtk.TreePath.from_indices (position, -1));
			string iter_str = this.playlist_store.get_string_from_iter (iter);
			string current_str = this.playlist_store.get_string_from_iter (current_iter);

			store.remove (iter);

			// Reset the "current_iter" pointer.
			if (iter_str == current_str)
			{
				this.playlist_store.get_iter_first (out this.current_iter);
			}
		}

		private void set_track_position (int64 usec)
		{
			GLib.Value duration;

			if (this.playlist_store.iter_is_valid (this.current_iter))
			{
				this.playlist_store.get_value (this.current_iter, Columns.DURATION, out duration);
				this.duration_label.set_text ("%s of %s".printf (usec_to_string (usec), (string) duration));

				this.current_progress = (double) usec;
				this.progress_slider.set_value ((double) usec);
			}
		}

		private bool update_track_progress ()
		{
			string status = this.player.GetPlaybackStatus ();
			int64 progress = this.player.GetProgress ();

			set_track_position (progress);

			if (status == "PLAYING")
			{
				return true;
			}

			else
			{
				// NOTE: Sometimes, I don't know why, but when seeking a track, GStreamer
				//       reports the state as "PAUSED". This can cause the UI to get stuck,
				//       as if it's paused, even though the track keeps playing. Hence the
				//       following sleep hack, which should allow GStreamer to catch up to
				//       the seek and resume the "PLAYING" state.
				GLib.Thread.usleep(50);
				status = this.player.GetPlaybackStatus ();

				if (status == "PLAYING")
				{
					return true;
				}
				else
				{
					return false;
				}
			}
		}

		private bool expand_search_pane ()
		{
			int position = this.view_separator.get_position ();

			if (position < search_results_height)
			{
				this.view_separator.set_position (position + animate_increment);
				return true;
			}

			else
			{
				return false;
			}
		}

		private bool shrink_search_pane ()
		{
			int position = this.view_separator.get_position ();

			if (position > 0)
			{
				int new_position = position - animate_increment;
				
				if (new_position > 0)
				{
					this.view_separator.set_position (new_position);
				}
				
				else
				{
					this.view_separator.set_position (0);
				}

				return true;
			}

			else
			{
				return false;
			}
		}

		public void handle_search_view_selected (Gtk.TreePath path, Gtk.TreeViewColumn column)
		{
			Gtk.TreeIter iter;
			GLib.Value uri;

			this.search_store.get_iter (out iter, path);

			if (this.search_store.iter_is_valid (iter))
			{
				this.search_store.get_value (iter, Columns.URI, out uri);
				this.player.AddTrack ((string) uri, -1);
			}
		}

		public void handle_playlist_view_selected (Gtk.TreePath path, Gtk.TreeViewColumn column)
		{
			int track = path.to_string ().to_int ();
			this.player.Play (track);
		}

		public bool handle_playlist_view_key_pressed (Gdk.EventKey event)
		{
			Gtk.TreeIter selection;
			Gtk.TreeModel model = (Gtk.TreeModel) this.playlist_store;
			int position = -1;
			
			this.playlist_select.get_selected (out model, out selection);

			if (this.playlist_store.iter_is_valid (selection))
			{
				position = this.playlist_store.get_path (selection).to_string ().to_int ();
			}

			switch (event.hardware_keycode)
			{
				// "delete" was pressed
				case 119:
					if (position >= 0)
					{
						this.player.RemoveTrack (position);
					}
					break;

				// "enter" was pressed
				case 36:
					if (position >= 0)
					{
						this.player.Play (position);
					}
					break;

				// "space" was pressed
				case 65:
					string status = this.player.GetPlaybackStatus ();
					if (status == "PLAYING")
					{
						this.player.Pause ();
					}

					else if (status == "PAUSED")
					{
						toggle_play ();
					}
					break;

				// "up" or "p" was pressed
				case 111:
				case 33:
					if (position < 0)
					{
						position = 0;
					}

					int new_position = (position - 1) % this.playlist_store.length;
					Gtk.TreePath new_path = new Gtk.TreePath.from_indices (new_position, -1);
					this.playlist_select.select_path (new_path);
					break;

				// "down" or "n" was pressed
				case 116:
				case 57:
					int new_position = (position + 1) % this.playlist_store.length;
					Gtk.TreePath new_path = new Gtk.TreePath.from_indices (new_position, -1);
					this.playlist_select.select_path (new_path);
					break;

				default:
					debug ("%d pressed", event.hardware_keycode);
					break;
			}

			return true;
		}

		// Deal with an DND source data request.
		// FIXME: The data that this method adds to the selection goes missing later
		//        on, in the method below.
		public void handle_drag_data_get (Gdk.DragContext context, Gtk.SelectionData selection_data, uint info, uint time)
		{
			Gtk.TreeModel model = (Gtk.TreeModel) this.search_store;
			GLib.List<Gtk.TreePath> rows;
			string[] uris;
			int i = 0;

			rows = this.search_select.get_selected_rows (out model);
			uris = new string[this.search_select.count_selected_rows ()];

			foreach (Gtk.TreePath path in rows)
			{
				Gtk.TreeIter iter;
				GLib.Value text;

				this.search_store.get_iter (out iter, path);
				this.search_store.get_value (iter, Columns.URI, out text);
				uris[i] = (string) text;
				debug ("Setting selection_data to %s", uris[i]);

				++i;
			}

			selection_data.set_uris (uris);
		}

		// Handle a DND drop event.
		public void handle_drag_data_received (Gdk.DragContext context, int x, int y, Gtk.SelectionData selection_data, uint info, uint time)
		{
			Gtk.TreePath path;
			Gtk.TreeViewDropPosition pos;
			Gtk.TreeIter iter;
			Gtk.TreeModel model = (Gtk.TreeModel) this.playlist_store;
			int playlist_position;

			this.playlist_view.get_dest_row_at_pos (x, y, out path, out pos);

			if (path != null)
			{
				this.playlist_store.get_iter (out iter, path);
				playlist_position = path.to_string ().to_int ();
			}

			else
			{
				playlist_position = -1;
			}

			debug ("An item was dragged from %s", selection_data.target.name ());

			// If this was dragged from within the playlist view, treat it as a move.
			switch (selection_data.target.name ())
			{
				case "OTHER_ROW":
					Gtk.TreeIter selection;
					GLib.Value uri;

					this.playlist_select.get_selected (out model, out selection);
					this.playlist_store.get_value (selection, Columns.URI, out uri);
					this.player.RemoveTrack (this.playlist_store.get_string_from_iter (selection).to_int ());
					this.player.AddTrack ((string) uri, playlist_position);

					// Signal that the drag has successfully completed.
					Gtk.drag_finish (context, true, false, time);
					break;
				// FIXME: The URIs that I stuck into selection_data in
				//        handle_drag_data_get() are missing! Where did they go? No clue.
				case "SEARCH_RESULT":
					Gtk.TreeModel search_model = (Gtk.TreeModel) this.search_store;
					GLib.List<Gtk.TreePath> rows;

					rows = this.search_select.get_selected_rows (out search_model);

					foreach (Gtk.TreePath search_path in rows)
					{
						Gtk.TreeIter search_iter;
						GLib.Value uri;

						this.search_store.get_iter (out search_iter, search_path);
						this.search_store.get_value (search_iter, Columns.URI, out uri);
						this.player.AddTrack ((string) uri, playlist_position);
					}

					Gtk.drag_finish (context, true, true, time);
					break;
				case "text/uri-list":
					string[] uris = selection_data.get_uris ();

					foreach (string uri in uris)
					{
						this.player.AddTrack (uri, playlist_position);
					}

					Gtk.drag_finish (context, true, true, time);
					break;
				case "STRING":
				case "text/plain":
					string uri = (string) selection_data.data;

					// NOTE: Dragging from the desktop appends a newline to the end of the
					//       uri, which confuses the method AddTrack method.
					uri = uri.strip ();

					debug ("Adding '%s' to the playlist at position %d", uri, playlist_position);
					this.player.AddTrack (uri, playlist_position);

					Gtk.drag_finish (context, true, true, time);
					break;
				default:
					debug ("Hum doesn't know how to handle data from that source!");

					// Signal that the drag has unsuccessfully completed.
					Gtk.drag_finish (context, false, true, time);
					break;
			}
		}

		// Pass along the command to play the current track or resume play.
		public void handle_play_clicked ()
		{
			toggle_play ();
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

		// FIXME: Instead of having this expand to a specified height, it should
		//        expand to the number of results, stopping at some sane maximum.
		//        Investigate the use of Gtk.TreeView.get_cell_area () to do this.
		// FIXME: Investigate live search.
		public void handle_search_requested ()
		{
			this.search_entry.set_progress_fraction (0.0);
			this.search_store.clear ();

			string terms = this.search_entry.text;
			string[] uris = this.query_engine.search (terms);

			if (uris.length > 0)
			{
				double step = 1.0 / (double) uris.length;

				foreach (string uri in uris)
				{
					add_track_to_view (this.search_store, uri);
					this.search_entry.set_progress_fraction (this.search_entry.get_progress_fraction () + step);
				}

				this.animate_timeout_id = (int) GLib.Timeout.add (this.animate_period, expand_search_pane);
			}

			else
			{
				this.animate_timeout_id = (int) GLib.Timeout.add (this.animate_period, shrink_search_pane);
			}
		}

		public void handle_search_cleared ()
		{
			this.search_entry.text = "";
			this.search_store.clear ();
			this.animate_timeout_id = (int) GLib.Timeout.add (this.animate_period, shrink_search_pane);
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

		public void handle_seeked (dynamic DBus.Object player, int64 usec)
		{
			set_track_position (usec);
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
			add_track_to_view (this.playlist_store, uri, position);
		}

		public void handle_track_removed (dynamic DBus.Object player, int position)
		{
			remove_track_from_view (this.playlist_store, position);
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
