/*
 * hum_gui.vala
 *
 * This file is part of Hum, the low calorie music manager.
 *
 * Copyright (C) 2007-2010 by Brian Davis <brian.william.davis@gmail.com>
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
		public Hum.SearchView search_view;
		public Hum.PlayListView playlist_view;
		public Gtk.ListStore search_store;
		public Gtk.ListStore playlist_store;
		public Gtk.CellRendererText text_renderer;
		public Gtk.CellRendererPixbuf pixbuf_renderer;

		private Gtk.TreeIter current_iter;
		private double current_progress = 0.0;

		// FIXME: It seems like the behavior here is switched. In other words, when
		//        a user presses the "page down" key, the step action fires. When a
		//        user clicks on the slider, the page action fires. Odd.
		private double slider_page_increment = 10000000000.0; // 10 seconds step
		private double slider_step_increment = 60000000000.0; // 60 seconds page

		private int update_timeout_id = -1;
		private int update_period = 500;
		private int animate_timeout_id = -1;
		private int animate_period = 50;
		private int animate_increment = 10;

		private int max_search_results_in_view = 5;
		private int search_results_height = 0;

		private Hum.QueryEngine query_engine;
		private Hum.Player player;

		/* DND-related bits. */
		private const Gtk.TargetEntry[] target_list = {
			{ "OTHER_ROW", Gtk.TargetFlags.SAME_WIDGET, 0 },
			{ "SEARCH_RESULT", Gtk.TargetFlags.SAME_APP, 0 },
			{ "STRING", 0, 1 },
			{ "text/plain", 0, 1 },
			{ "text/uri-list", 0, 2 }
		};

		public UserInterface (string [] args)
		{
			try
			{
				// Fetch the player backend.
				this.player = GLib.Bus.get_proxy_sync (BusType.SESSION,
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

				this.playlist_store = (Gtk.ListStore) builder.get_object ("playlist_store");
				this.search_store = (Gtk.ListStore) builder.get_object ("search_store");

				// Setup the search results list view.
				this.search_view = new Hum.SearchView ();
				this.search_view.set_model (this.search_store);
				Gtk.ScrolledWindow scrolledwindow1 = (Gtk.ScrolledWindow) builder.get_object ("scrolledwindow1");
				scrolledwindow1.add (this.search_view);

				// Setup the play list view.
				// FIXME: The playlist should not need to know the Player class.
				this.playlist_view = new PlayListView (this.player, this.search_view);
				this.playlist_view.set_model (this.playlist_store);
				Gtk.ScrolledWindow scrolledwindow2 = (Gtk.ScrolledWindow) builder.get_object ("scrolledwindow2");
				scrolledwindow2.add (this.playlist_view);

				this.text_renderer = (Gtk.CellRendererText) builder.get_object ("text_renderer");
				this.pixbuf_renderer = (Gtk.CellRendererPixbuf) builder.get_object ("pixbuf_renderer");

				// Connect the stores to their corresponding views.
				// FIXME: should be moved into the SearchView and PlayListView classes.
				set_up_list_view (this.playlist_store, this.playlist_view);
				set_up_list_view (this.search_store, this.search_view);

				// Update the interface to reflect the backend.
				set_up_interface ();

				// Initialize the actions and action groups.
				set_up_actions ();

				// Hook up some signals.
				set_up_signals ();

				// If the application was launched with arguments, try
				// to load them as tracks.
				if (args.length > 1)
				{
					for (int i = 1; i < args.length; i++)
					{
						try
						{
							string uri = GLib.Filename.to_uri (args[i]);
							this.player.add_track (uri, -1);
						}
						catch (GLib.ConvertError e)
						{
							critical ("Error converting %s to a URI: %s", args[i], e.message);
						}
					}

					this.player.play (-1);
				}
			}
			catch (GLib.IOError e)
			{
				critical ("Error connecting to the Hum daemon: %s", e.message);
				quit ();
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
			this.window.destroy.connect (quit);
			this.quit_action.activate.connect (quit);

			this.about_action.activate.connect (show_about_dialog);
			this.properties_action.activate.connect (show_properties_dialog);

			Gtk.TreeSelection playlist_select = this.playlist_view.get_selection ();
			playlist_select.changed.connect (handle_playlist_select_changed);

			Gtk.TreeSelection search_select = this.search_view.get_selection ();
			search_select.changed.connect (handle_search_select_changed);

			this.play_button.clicked.connect (handle_play_clicked);
			this.pause_button.clicked.connect (handle_pause_clicked);
			this.prev_button.clicked.connect (handle_prev_clicked);
			this.next_button.clicked.connect (handle_next_clicked);
			this.repeat_button.clicked.connect (handle_repeat_clicked);
			this.shuffle_button.clicked.connect (handle_shuffle_clicked);

			this.progress_slider.value_changed.connect (handle_slider_value_changed);
			this.search_button.clicked.connect (handle_search_requested);
			this.search_entry.activate.connect (handle_search_requested);
			this.search_entry.icon_release.connect (handle_search_cleared);

			this.search_view.row_activated.connect (handle_search_view_selected);
			this.playlist_view.row_activated.connect (handle_playlist_view_selected);
			this.playlist_view.key_press_event.connect (handle_playlist_view_key_pressed);

			// Signals from hum-player.
			this.player.playing_track.connect (handle_playing_track);
			this.player.paused_playback.connect (handle_paused_playback);
			this.player.stopped_playback.connect (handle_stopped_playback);
			this.player.seeked.connect (handle_seeked);
			this.player.repeat_toggled.connect (handle_repeat_toggled);
			this.player.shuffle_toggled.connect (handle_shuffle_toggled);
			this.player.track_added.connect (handle_track_added);
			this.player.track_removed.connect (handle_track_removed);
			this.player.exiting.connect (quit);
		}

		// Bring the interface up to date with the back end.
		private void set_up_interface ()
		{
			string[] uris = this.player.get_playlist ();
			string playback_status = this.player.get_playback_status ();
			int position = this.player.get_current_track ();
			bool repeat_toggled = this.player.get_repeat ();
			bool shuffle_toggled = this.player.get_shuffle ();

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
			store.set_sort_func (Columns.TITLE, title_sort);
			store.set_sort_func (Columns.ARTIST, artist_sort);
			store.set_sort_func (Columns.ALBUM, album_sort);
			store.set_sort_func (Columns.TRACK, track_sort);
			store.set_sort_func (Columns.GENRE, genre_sort);
			store.set_sort_func (Columns.DURATION, duration_sort);

			// Search panes should be sorted by default, but not the playlist.
			if (store == this.search_store)
			{
				store.set_sort_column_id (Columns.ARTIST, Gtk.SortType.ASCENDING);
			}

			// Attach the store to the track list.
			//view.set_model (store);

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

			uri = new Gtk.TreeViewColumn.with_attributes ("URI", this.text_renderer, "text", Columns.URI);
			status_or_add_to_playlist = new Gtk.TreeViewColumn.with_attributes ("", this.pixbuf_renderer, "stock-id", Columns.STATUS_OR_ADD_TO_PLAYLIST);
			title = new Gtk.TreeViewColumn.with_attributes ("Title", this.text_renderer, "text", Columns.TITLE);
			artist = new Gtk.TreeViewColumn.with_attributes ("Artist", this.text_renderer, "text", Columns.ARTIST);
			album = new Gtk.TreeViewColumn.with_attributes ("Album", this.text_renderer, "text", Columns.ALBUM);
			track = new Gtk.TreeViewColumn.with_attributes ("#", this.text_renderer, "text", Columns.TRACK);
			genre = new Gtk.TreeViewColumn.with_attributes ("Genre", this.text_renderer, "text", Columns.GENRE);
			release_date = new Gtk.TreeViewColumn.with_attributes ("Release Date", this.text_renderer, "text", Columns.RELEASE_DATE);
			duration = new Gtk.TreeViewColumn.with_attributes ("Duration", this.text_renderer, "text", Columns.DURATION);
			bitrate = new Gtk.TreeViewColumn.with_attributes ("Bitrate", this.text_renderer, "text", Columns.BITRATE);
			file_size = new Gtk.TreeViewColumn.with_attributes ("File Size", this.text_renderer, "text", Columns.FILE_SIZE);

			// Hide the columns we don't need to show to the user.
			uri.set_visible (false);
			release_date.set_visible (false);
			bitrate.set_visible (false);
			file_size.set_visible (false);

			// Set up the sizing parameters for each column.
			uri.set_sizing (Gtk.TreeViewColumnSizing.FIXED);
			status_or_add_to_playlist.set_sizing (Gtk.TreeViewColumnSizing.FIXED);
			title.set_sizing (Gtk.TreeViewColumnSizing.FIXED);
			artist.set_sizing (Gtk.TreeViewColumnSizing.FIXED);
			album.set_sizing (Gtk.TreeViewColumnSizing.FIXED);
			track.set_sizing (Gtk.TreeViewColumnSizing.FIXED);
			genre.set_sizing (Gtk.TreeViewColumnSizing.FIXED);
			release_date.set_sizing (Gtk.TreeViewColumnSizing.FIXED);
			duration.set_sizing (Gtk.TreeViewColumnSizing.FIXED);
			bitrate.set_sizing (Gtk.TreeViewColumnSizing.FIXED);
			file_size.set_sizing (Gtk.TreeViewColumnSizing.FIXED);

			// Configure some playlist-specific stuff.
			if (view == this.playlist_view)
			{
				// Set up the image in the header of the status_or_add_to_playlist column.
				status_or_add_to_playlist_header = new Gtk.Image.from_stock (Gtk.Stock.MEDIA_PLAY, Gtk.IconSize.MENU);

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
				status_or_add_to_playlist_header = new Gtk.Image.from_stock (Gtk.Stock.ADD, Gtk.IconSize.MENU);

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
			this.about_dialog.response.connect (handle_about_dialog_response);

			this.about_dialog.show_all ();
		}

		private void handle_about_dialog_response (int response_id)
		{
			if (response_id == Gtk.ResponseType.CANCEL)
			{
				this.about_dialog.close ();
			}
		}

		private void show_properties_dialog ()
		{
			// Verify that a track is selected and, if so, fill in the track metadata.
			Gtk.TreeIter selection;
			Gtk.TreeModel model;
			Gtk.TreeSelection playlist_select = this.playlist_view.get_selection ();
			bool is_selected = playlist_select.get_selected (out model, out selection);
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
				close_action.activate.connect (close_properties_dialog);

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
			Hum.Track track = this.query_engine.make_track (this.player.get_current_uri ());

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

			// Initialize the slider position.
			this.progress_slider.set_range (0.0, (double) track.duration);
			this.progress_slider.set_increments (slider_step_increment, slider_page_increment);

			// Add a timeout to update the track progress.
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
			Hum.Track track = this.query_engine.make_track (this.player.get_current_uri ());

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
			this.progress_slider.set_increments (slider_step_increment, slider_page_increment);
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
			Gtk.TreeSelection playlist_select = this.playlist_view.get_selection ();
			bool is_selected = playlist_select.get_selected (out model, out selection);
			bool selection_is_valid = this.playlist_store.iter_is_valid (selection);
			string status = this.player.get_playback_status ();
			int track = -1;

			// If playback is currently paused and the selected track is also the
			// playing track, just resume.
			if (is_selected && selection_is_valid)
			{
				int position = int.parse (this.playlist_store.get_path (selection).to_string ());
				int current_position = this.player.get_current_track ();

				if (status != "PAUSED" || position != current_position)
				{
					track = position;
				}
			}

			this.player.play (track);
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
				Columns.RELEASE_DATE, Time.gm ((time_t) int.parse (track.release_date)).year.to_string (),
				Columns.DURATION, usec_to_string (track.duration),
				Columns.BITRATE, "%d kbps".printf (int.parse (track.bitrate) / 1000),
				Columns.FILE_SIZE, "%0.2f MB".printf (int.parse (track.file_size) / (1024.0 * 1024.0)),
				-1);
		}

		private void add_track_to_view_from_array (Gtk.ListStore store, string[] track, int position = -1)
		{
			Gtk.TreeIter iter;

			if (position == -1)
			{
				store.append (out iter);
			}

			else
			{
				store.insert (out iter, position);
			}

			// Structure of a Track array:
			// url, title, artist, album, genre, track, duration

			// Create a MM:SS string for the duration
			int seconds = int.parse (track[6]);
			int minutes = seconds / 60;
			string duration = "%d:%02d".printf (minutes, seconds % 60);

			store.set (iter,
				Columns.URI, track[0],
				Columns.TITLE, track[1],
				Columns.ARTIST, track[2],
				Columns.ALBUM, track[3],
				Columns.TRACK, track[5],
				Columns.GENRE, track[4],
				Columns.DURATION, duration,
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
			string status = this.player.get_playback_status ();
			int64 progress = this.player.get_progress ();

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
				status = this.player.get_playback_status ();

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
			// If the search pane hasn't started descending yet...
			if (this.search_results_height == 0)
			{
				int num_results = this.search_store.length;
				Gtk.TreePath first_row = new Gtk.TreePath.from_indices (0, -1);
				Gdk.Rectangle row_dims;
				int row_height;

				this.search_view.get_cell_area (first_row, this.search_view.get_column (1), out row_dims);
				row_height = row_dims.height;

				// Expand the search pane to either the number of rows returned or, if
				// there are more than "max_search_results_in_view", that number.
				if (row_height > 0)
				{
					if (num_results < this.max_search_results_in_view)
					{
						this.search_results_height = row_height * num_results;
					}
					else
					{
						this.search_results_height = row_height * this.max_search_results_in_view;
					}

					// NOTE: We have to add the size of the header to the search view size to
					//       accurately capture its viewable area.
					this.search_results_height += row_height;
				}
			}

			if (this.view_separator.position < search_results_height || search_results_height == 0)
			{
				this.view_separator.position += animate_increment;
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
				this.player.add_track ((string) uri, -1);
			}
		}

		public void handle_playlist_view_selected (Gtk.TreePath path, Gtk.TreeViewColumn column)
		{
			int track = int.parse (path.to_string ());
			this.player.play (track);
		}

		// FIXME: Replace this with global keybindings, because this totally screws
		//        up standard TreeView keybindings (up, down, search, etc.)
		public bool handle_playlist_view_key_pressed (Gdk.EventKey event)
		{
			Gtk.TreeIter selection;
			Gtk.TreeModel model = (Gtk.TreeModel) this.playlist_store;
			Gtk.TreeSelection playlist_select = this.playlist_view.get_selection ();
			int position = -1;

			playlist_select.get_selected (out model, out selection);

			if (this.playlist_store.iter_is_valid (selection))
			{
				position = int.parse (this.playlist_store.get_path (selection).to_string ());
			}

			switch (event.hardware_keycode)
			{
				// "delete" was pressed
				case 119:
					if (position >= 0)
					{
						this.player.remove_track (position);
					}
					break;

				// "enter" was pressed
				case 36:
					if (position >= 0)
					{
						this.player.play (position);
					}
					break;

				// "space" was pressed
				case 65:
					string status = this.player.get_playback_status ();
					if (status == "PLAYING")
					{
						this.player.pause ();
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
					playlist_select.select_path (new_path);
					break;

				// "down" or "n" was pressed
				case 116:
				case 57:
					int new_position = (position + 1) % this.playlist_store.length;
					Gtk.TreePath new_path = new Gtk.TreePath.from_indices (new_position, -1);
					playlist_select.select_path (new_path);
					break;

				default:
					debug ("%d pressed", event.hardware_keycode);
					return false;
			}

			return true;
		}

		// Pass along the command to play the current track or resume play.
		public void handle_play_clicked ()
		{
			toggle_play ();
		}

		// Pass along the command to pause playback.
		public void handle_pause_clicked ()
		{
			this.player.pause ();
		}

		// Pass along the command to play the previous track.
		public void handle_prev_clicked ()
		{
			this.player.previous ();
		}

		// Pass along the command to play the next track.
		public void handle_next_clicked ()
		{
			this.player.next ();
		}

		public void handle_repeat_clicked ()
		{
			this.player.set_repeat (this.repeat_button.active);

			// Change the sensitivity of the previous and next buttons at the extremes
			// of the playlist to reflect the (dis)ability to loop.
			if (this.playlist_store.iter_is_valid (this.current_iter))
			{
				Gtk.TreePath path = this.playlist_store.get_path (this.current_iter);

				if (int.parse (path.to_string ()) == 0)
				{
					this.prev_button.sensitive = this.repeat_button.active;
				}

				else if (int.parse (path.to_string ()) == this.playlist_store.length - 1)
				{
					this.next_button.sensitive = this.repeat_button.active;
				}
			}
		}

		public void handle_shuffle_clicked ()
		{
			this.player.set_shuffle (this.shuffle_button.active);
		}

		public void handle_slider_value_changed ()
		{
			double position = this.progress_slider.get_value ();

			// If the slider has moved more than it normally does between updates from
			// the back end, then the user probably moved it. If they actually moved it
			// less than this distance, well... they can just wait the extra 500ms.
			if (position > (this.current_progress + this.update_period) ||
				position < this.current_progress)
			{
				this.player.seek ((int64) position);
			}
			else
			{
				this.current_progress = position;
			}
		}

		// FIXME: Investigate live search.
		public void handle_search_requested ()
		{
			this.search_entry.set_progress_fraction (0.0);
			this.search_store.clear ();
			this.search_results_height = 0;
			this.view_separator.position = 0;

			string terms = this.search_entry.text;
			// don't search for very small strings
			if (terms.length < 3)
			{
				return;
			}
			string[,]? tracks = this.query_engine.search (terms);

			if (tracks.length[0] > 0)
			{
				double step = 1.0 / (double) tracks.length[0];

				for (int i = 0; i < tracks.length[0]; i++)
				{
					// FIXME: This must be done because Vala has no support for getting one-
					//        dimensional arrays from multi-dimensional arrays.
					string[] temp_track = {};

					for (int j = 0; j < tracks.length[1]; j++)
					{
						temp_track += tracks[i,j];
					}

					add_track_to_view_from_array (this.search_store, temp_track);

					// FIXME: The progress is hardly visible since only one fast query is used.
					this.search_entry.set_progress_fraction (this.search_entry.get_progress_fraction () + step);
				}
				this.search_entry.set_progress_fraction (0.0);

				this.animate_timeout_id = (int) GLib.Timeout.add (this.animate_period, expand_search_pane);
			}
/* This causes jiggling of the view separator, since the two timeouts can get
   crossed, creating an infinite loop.

			else
			{
				this.animate_timeout_id = (int) GLib.Timeout.add (this.animate_period, shrink_search_pane);
			}
*/
		}

		public void handle_search_cleared ()
		{
			this.search_entry.text = "";
			this.search_store.clear ();
			this.animate_timeout_id = (int) GLib.Timeout.add (this.animate_period, shrink_search_pane);
		}

		public void handle_playing_track (Hum.Player player, int position)
		{
			set_up_playing_state (position);
		}

		public void handle_paused_playback ()
		{
			set_up_paused_state (this.player.get_current_track ());
		}

		public void handle_stopped_playback ()
		{
			set_up_stopped_state ();
		}

		public void handle_seeked (Hum.Player player, int64 usec)
		{
			set_track_position (usec);
		}

		public void handle_repeat_toggled (Hum.Player player, bool do_repeat)
		{
			this.repeat_button.active = do_repeat;
		}

		public void handle_shuffle_toggled (Hum.Player player, bool do_shuffle)
		{
			this.shuffle_button.active = do_shuffle;
		}

		public void handle_track_added (Hum.Player player, string uri, int position)
		{
			add_track_to_view (this.playlist_store, uri, position);
		}

		public void handle_track_removed (Hum.Player player, int position)
		{
			remove_track_from_view (this.playlist_store, position);
		}

		public void quit ()
		{
			this.player.quit ();
			Gtk.main_quit ();
		}
	}

	static int main (string[] args)
	{
		Gtk.init (ref args);

		var app = new Hum.UserInterface (args);

		app.window.show_all ();

		// Hide the search view at start up.
		app.view_separator.set_position (0);

		Gtk.main ();

		return 0;
	}
}
