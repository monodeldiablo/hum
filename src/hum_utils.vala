/*
 * hum_utils.vala
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

namespace Hum
{
	// Compare two UTF-8 strings.
	public int compare (string a, string b)
	{
		string key_a;
		string key_b;

		// FIXME: I'm sure this is a good idea, but it's not supported in Vala right
		//        now...
		//key_a = a.casefold ().collate_key ();
		//key_b = b.casefold ().collate_key ();
		key_a = a.casefold ();
		key_b = b.casefold ();

		return GLib.strcmp (key_a, key_b);
	}

	// Convert from useconds to a string representation of MM:SS.
	public string usec_to_string (int64 usec)
	{
		int64 useconds_in_second = 1000000000;
		int seconds_in_minute = 60;
		int total_seconds = (int) (usec / useconds_in_second);
		int minutes = total_seconds / seconds_in_minute;
		int seconds = total_seconds % seconds_in_minute;

		return "%d:%02d".printf (minutes, seconds);
	}

	// Sort by title.
	public int title_sort (Gtk.TreeModel model, Gtk.TreeIter a, Gtk.TreeIter b)
	{
		string title_a;
		string title_b;

		model.get (a, Columns.TITLE, out title_a);
		model.get (b, Columns.TITLE, out title_b);

		return Hum.compare (title_a, title_b);
	}

	// Sort by artist (actually sorts by artist > album > track).
	public int artist_sort (Gtk.TreeModel model, Gtk.TreeIter a, Gtk.TreeIter b)
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
			return album_sort (model, a, b);
		}

		return sort;
	}

	// Sort by album (actually sorts by album > track).
	public int album_sort (Gtk.TreeModel model, Gtk.TreeIter a, Gtk.TreeIter b)
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
			return track_sort (model, a, b);
		}

		return sort;
	}

	// Sort by track.
	public int track_sort (Gtk.TreeModel model, Gtk.TreeIter a, Gtk.TreeIter b)
	{
		string track_a;
		string track_b;
		int num_a;
		int num_b;

		model.get (a, Columns.TRACK, out track_a);
		model.get (b, Columns.TRACK, out track_b);

		num_a = int.parse (track_a);
		num_b = int.parse (track_b);

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
	public int genre_sort (Gtk.TreeModel model, Gtk.TreeIter a, Gtk.TreeIter b)
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
			return artist_sort (model, a, b);
		}

		return sort;
	}

	// Sort by duration.
	public int duration_sort (Gtk.TreeModel model, Gtk.TreeIter a, Gtk.TreeIter b)
	{
		string duration_a;
		string duration_b;

		model.get (a, Columns.DURATION, out duration_a);
		model.get (b, Columns.DURATION, out duration_b);

		return Hum.compare (duration_a, duration_b);
	}
}
