/*
 * hum_query_engine.vala
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

using DBus;

namespace Hum
{
	public class QueryEngine: GLib.Object
	{
		private DBus.Connection conn;
		private dynamic DBus.Object tracker;

		// Searches for a substring in the title, artist and album string.
		private const string search_tracks_query = """
			SELECT ?url ?title ?performer ?album ?genre ?track ?duration
				WHERE {
				?song a nmm:MusicPiece ;
				        nie:url ?url ;
				        nie:title ?title ;
				        nmm:performer [ nmm:artistName ?performer ] ;
				        nmm:musicAlbum [ nie:title ?album ] .
				        OPTIONAL { ?song nmm:genre ?genre } .
				        OPTIONAL { ?song nmm:trackNumber ?track } .
				        OPTIONAL { ?song nfo:duration ?duration } .
				        FILTER ( regex(?title, "%s", "i") ||
				                 regex(?performer, "%s", "i") ||
				                 regex(?album, "%s", "i") )
			} LIMIT 1024
		""";

		// Searches all metadata that relates to a path of a file.
		private const string get_metadata_from_uri_query = """
			SELECT ?title ?track ?genre ?performer ?album ?date ?duration ?bitrate ?size
				WHERE {
					?song nie:url "%s" ;
				        nie:title ?title ;
				        nmm:performer [ nmm:artistName ?performer ] ;
				        nmm:musicAlbum [ nie:title ?album ] .
				        OPTIONAL { ?song nmm:genre ?genre	} .
				        OPTIONAL { ?song nmm:trackNumber ?track } .
				        OPTIONAL { ?song nie:contentCreated ?date } .
				        OPTIONAL { ?song nfo:duration ?duration } .
				        OPTIONAL { ?song nfo:averageBitrate ?bitrate } .
				        OPTIONAL { ?song nfo:fileSize ?size }
				}
		""";
		// FIXME: add a tag query, too.

		construct
		{
			debug ("Connecting to Tracker...");
			try
			{
				conn = DBus.Bus.get (DBus.BusType.SESSION);

				this.tracker = conn.get_object ("org.freedesktop.Tracker1",
					"/org/freedesktop/Tracker1/Resources",
					"org.freedesktop.Tracker1.Resources");

				debug ("Connected to Tracker!");
			}
			catch (DBus.Error e)
			{
				critical ("Error connecting to Tracker: %s", e.message);
			}
		}

		// This method returns the list of URIs of files that match the given search.
		// If the user entered a blank string, no results will be returned.
		// FIXME: Perhaps make this asynchronous, so that the application doesn't
		//        freeze up for long-running queries.
		// FIXME: Remove the 1024 item limit and introduce a paging system, whereby
		//        the application may page through a result set, fetching only the
		//        number necessary to fill the search window.
		public string[][]? search (string terms)
		{
			debug ("Searching for \"%s\"...", terms);

			string query = this. search_tracks_query.printf (terms, terms, terms);
			string[][]? matches = null;

			// FIXME: does this function really throw an exception?
			try {
				matches = this.tracker.SparqlQuery(query);
			}
			catch (GLib.Error e)
			{
				critical ("Error while searching for \"%s\": %s", terms, e.message);
			}

			debug ("Found %d matches.", matches.length);

			return matches;
		}

		// FIXME: This seems out of place if others want to use it...
		public Hum.Track make_track (string uri)
		{
			Hum.Track track = new Track (uri);

			// FIXME: does this function really throw an exception?
			try
			{
				string[][] metadata = this.tracker.SparqlQuery (this.get_metadata_from_uri_query.printf (uri));

				// FIXME: This should just throw an exception in the error case.
				if (metadata.length > 0)
				{
					int64 useconds_in_second = 1000000000;

					track.title = metadata[0][0];
					track.track_number = metadata[0][1].to_int ();
					track.genre = metadata[0][2];

					if (metadata[0][3] != "")
					{
						track.artist = metadata[0][3];
					}

					if (metadata[0][4] != "")
					{
						track.album = metadata[0][4];
					}

					track.release_date = metadata[0][5];
					track.duration = metadata[0][6].to_int64 () * useconds_in_second;
					track.bitrate = metadata[0][7];
					track.file_size = metadata[0][8];
				}
			}
			catch (GLib.Error e)
			{
				critical ("Error while converting '%s' to a track: %s", uri, e.message);
			}

			return track;
		}
	}
}	
