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
//using DBus;

public class Hum.UserInterface
{
	public Gtk.Window window;
	public Gtk.Statusbar status_bar;
	public Gtk.ToolButton play_button;
	public Gtk.ToolButton stop_button;
	public Gtk.ToolButton prev_button;
	public Gtk.ToolButton next_button;
	public Gtk.Label track_label;
	public Gtk.Label duration_label;
	public Gtk.HScale slider;
	public Gtk.TreeView track_list;
	public Gtk.ListStore list_store;
	public Gtk.TreeSelection browse_select;

	private string ui_file = "main.ui";
	private DBus.Connection conn;
	private enum Columns
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

	public UserInterface (string [] args)
	{
		string path = GLib.Path.build_filename (Config.PACKAGE_DATADIR, ui_file);
		conn = DBus.Bus.get (DBus.BusType.SESSION);

		// Construct the window and its child widgets from the UI definition.
		Gtk.Builder builder = new Gtk.Builder ();

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
		window = (Gtk.Window) builder.get_object ("main_window");
		status_bar = (Gtk.Statusbar) builder.get_object ("status_bar");
		play_button = (Gtk.ToolButton) builder.get_object ("play_button");
		stop_button = (Gtk.ToolButton) builder.get_object ("stop_button");
		prev_button = (Gtk.ToolButton) builder.get_object ("prev_button");
		next_button = (Gtk.ToolButton) builder.get_object ("next_button");
		track_label = (Gtk.Label) builder.get_object ("track_label");
		duration_label = (Gtk.Label) builder.get_object ("duration_label");
		slider = (Gtk.HScale) builder.get_object ("slider");
		track_list = (Gtk.TreeView) builder.get_object ("track_list");

		// Create the store that will drive the track list.
		list_store = new Gtk.ListStore (Columns.NUM_COLUMNS,
			typeof (string), // uri
			typeof (string), // status
			typeof (string), // title
			typeof (string), // artist
			typeof (string), // album
			typeof (string), // track
			typeof (string), // genre
			typeof (string));// duration

		// Define sort functions and hook them up.
		list_store.set_sort_func (Columns.TITLE, (Gtk.TreeIterCompareFunc) title_sort);
		list_store.set_sort_func (Columns.ARTIST, (Gtk.TreeIterCompareFunc) artist_sort);
		list_store.set_sort_func (Columns.ALBUM, (Gtk.TreeIterCompareFunc) album_sort);
		list_store.set_sort_func (Columns.TRACK, (Gtk.TreeIterCompareFunc) track_sort);
		list_store.set_sort_func (Columns.GENRE, (Gtk.TreeIterCompareFunc) genre_sort);
		list_store.set_sort_func (Columns.DURATION, (Gtk.TreeIterCompareFunc) duration_sort);

		list_store.set_sort_column_id (Columns.ARTIST, Gtk.SortType.ASCENDING);

		// Attach the store to the track list.
		track_list.set_model (list_store);

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
		track_list.append_column (uri);
		track_list.append_column (status);
		track_list.append_column (title);
		track_list.append_column (artist);
		track_list.append_column (album);
		track_list.append_column (track);
		track_list.append_column (genre);
		track_list.append_column (duration);

		// Set the selection mode.
		browse_select = track_list.get_selection ();
		browse_select.set_mode (Gtk.SelectionMode.SINGLE);

		// Hook up some signals.
		window.destroy += quit;
	}

	// Sort by title.
	public int title_sort (Gtk.TreeModel model, Gtk.TreeIter a, Gtk.TreeIter b, void* data)
	{
		string title_a;
		string title_b;

		model.get (a, Columns.TITLE, out title_a);
		model.get (b, Columns.TITLE, out title_b);

		return Hum.compare (title_a, title_b);
	}

	// Sort by artist (actually sorts by artist > album > track).
	public int artist_sort (Gtk.TreeModel model, Gtk.TreeIter a, Gtk.TreeIter b, void* data)
	{
		string artist_a;
		string artist_b;
		int sort;

		model.get (a, Columns.ARTIST, out artist_a);
		model.get (b, Columns.ARTIST, out artist_b);

		sort = Hum.compare (artist_a, artist_b);

		// Both tracks are by the same artist.
		if (0 == sort)
		{
			return album_sort (model, a, b, data);
		}

		return sort;
	}

	// Sort by album (actually sorts by album > track).
	public int album_sort (Gtk.TreeModel model, Gtk.TreeIter a, Gtk.TreeIter b, void* data)
	{
		string album_a;
		string album_b;
		int sort;

		model.get (a, Columns.ALBUM, out album_a);
		model.get (b, Columns.ALBUM, out album_b);

		sort = Hum.compare (album_a, album_b);

		// Both tracks are from the same album.
		if (0 == sort)
		{
			return track_sort (model, a, b, data);
		}

		return sort;
	}

	// Sort by track.
	public int track_sort (Gtk.TreeModel model, Gtk.TreeIter a, Gtk.TreeIter b, void* data)
	{
		string track_a;
		string track_b;
		int num_a;
		int num_b;

		model.get (a, Columns.TRACK, out track_a);
		model.get (b, Columns.TRACK, out track_b);

		num_a = track_a.to_int ();
		num_b = track_b.to_int ();

		if (num_a != num_b)
		{
			return (num_a > num_b) ? 1 : -1;
		}
		else
		{
			return 0;
		}
	}

	// Sort by genre (actually sorts by genre > artist > album > track).
	public int genre_sort (Gtk.TreeModel model, Gtk.TreeIter a, Gtk.TreeIter b, void* data)
	{
		string genre_a;
		string genre_b;
		int sort;

		model.get (a, Columns.GENRE, out genre_a);
		model.get (b, Columns.GENRE, out genre_b);

		sort = Hum.compare (genre_a, genre_b);

		// Both tracks are from the same genre.
		if (0 == sort)
		{
			return artist_sort (model, a, b, data);
		}

		return sort;
	}

	// Sort by duration.
	public int duration_sort (Gtk.TreeModel model, Gtk.TreeIter a, Gtk.TreeIter b, void* data)
	{
		string duration_a;
		string duration_b;

		model.get (a, Columns.DURATION, out duration_a);
		model.get (b, Columns.DURATION, out duration_b);

		return Hum.compare (duration_a, duration_b);
	}

	/*
	 * FIXME: Add signals on events like next, prev, pause, stop, etc.
	 */

	public void quit ()
	{
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
