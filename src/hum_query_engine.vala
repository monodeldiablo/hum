/*
 * hum_query_engine.vala
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

using DBus;

namespace Hum
{
	public class QueryEngine: GLib.Object
	{
		private DBus.Connection conn;
		private dynamic DBus.Object tracker;
		private dynamic DBus.Object tracker_search;
		private dynamic DBus.Object tracker_files;
		private dynamic DBus.Object tracker_metadata;
		
		private string service_type = "Music";
		private string[] fields = {
			"Audio:Title",
			"Audio:TrackNo",
			"Audio:Genre",
			"Audio:Artist",
			"Audio:Album",
			"Audio:ReleaseDate",
			"Audio:Duration",
			"Audio:Bitrate",
			"File:Size"};//,
			//"Audio:Codec",
			//"DC:Keywords"};
		
		construct
		{
			debug ("Connecting to Tracker...");
			try
			{
				conn = DBus.Bus.get (DBus.BusType.SESSION);

				this.tracker = conn.get_object ("org.freedesktop.Tracker",
					"/org/freedesktop/Tracker",
					"org.freedesktop.Tracker");

				debug ("Connected to Tracker v%d!", tracker.GetVersion ());

				this.tracker_search = conn.get_object ("org.freedesktop.Tracker",
					"/org/freedesktop/Tracker/Search",
					"org.freedesktop.Tracker.Search");

				this.tracker_files = conn.get_object ("org.freedesktop.Tracker",
					"/org/freedesktop/Tracker/Files",
					"org.freedesktop.Tracker.Files");
			
				this.tracker_metadata = conn.get_object ("org.freedesktop.Tracker",
					"/org/freedesktop/Tracker/Metadata",
					"org.freedesktop.Tracker.Metadata");
			}
			catch (DBus.Error e)
			{
				critical ("Error connecting to Tracker: %s", e.message);
			}
		}

		// This method returns the list of URIs of files that match the given search.
		// FIXME: Perhaps make this asynchronous, so that the application doesn't
		//        freeze up for long-running queries.
		// FIXME: Remove the 512 item limit and introduce a paging system, whereby
		//        the application may page through a result set, fetching only the
		//        number necessary to fill the search window.
		public string[] search (string terms)
		{
			string[] matches = {};

/* For now, we want to disable searching for all tracks (SLOW!).
			// The user didn't enter any search terms, so we'll just grab everything.
			if (0 == terms.size ())
			{
				debug ("Searching for all tracks...");
	
				try
				{
					matches = this.tracker_files.GetByServiceType (-1,
						"Music",
						0,
						-1);
				}
				catch (GLib.Error e)
				{
					critical ("Error while fetching all tracks: %s", e.message);
				}
			}
*/
			// The user entered search terms.
			if (terms.size () > 0)
			{
				debug ("Searching for \"%s\"...", terms);
	
				try
				{
					matches = tracker_search.Text (-1,
						"Music",
						terms,
						0,
						512);
				}
				catch (GLib.Error e)
				{
					critical ("Error while searching for \"%s\": %s", terms, e.message);
				}
			}
	
			debug ("Found %d matches.", matches.length);

			for (int i = 0; i < matches.length; ++i)
			{
				try
				{
					matches[i] = GLib.Filename.to_uri (matches[i]);
				}

				catch (GLib.Error e)
				{
					critical ("Error attempting to construct a URI for %s", matches[i]);
				}
			}
			
			return matches;
		}

		// FIXME: This seems out of place if others want to use it...
		public Hum.Track make_track (string uri)
		{
			Hum.Track track = new Track (uri);

			try
			{
				string path = GLib.Filename.from_uri (uri);
				string[] metadata = this.tracker_metadata.Get (this.service_type,
					path,
					this.fields);
				int64 useconds_in_second = 1000000000;

				track.title = metadata[0];
				track.track_number = metadata[1].to_int ();
				track.genre = metadata[2];

				if (metadata[3] != "")
				{
					track.artist = metadata[3];
				}

				if (metadata[4] != "")
				{
					track.album = metadata[4];
				}

				track.release_date = metadata[5];
				track.duration = metadata[6].to_int64 () * useconds_in_second;
				track.bitrate = metadata[7];
				track.file_size = metadata[8];
			}
			catch (GLib.Error e)
			{
				critical ("Error while converting '%s' to a path: %s", uri, e.message);
			}

			return track;
		}
	}
}	
