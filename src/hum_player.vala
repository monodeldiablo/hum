/*
 * hum_player.vala
 *
 * This file is part of Hum, the low-calorie music manager.
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

using GLib;
using DBus;
using Gst;

// FIXME: We'll start w/Gst.Playbin, but for playlist support we should move to
//        Gst.Decodebin in the future (cross-fading, etc.).
// FIXME: Use the built-in logging facilities!
// FIXME: Look into daemonizing (libdaemon?) this.

namespace Hum
{
	// This is the player backend.
	[DBus (name = "org.washedup.Hum")]
	public class Player : GLib.Object
	{
		// The application main loop.
		private GLib.MainLoop mainloop;

		// The GStreamer playback pipeline.
		private Gst.Element pipeline;

		// The GStreamer communication bus.
		private Gst.Bus bus;
		
		// The playlist, which is just a linked list of URIs.
		// FIXME: This should implement something fast and light, perhaps a modern
		//        array (see GLib.Array and Gee.ArrayList).
		private GLib.List<string> playlist;

		/***********
		* SETTINGS *
		***********/
		
		// FIXME: These settings should probably be persisted using GConf or
		//        something, since users are likely to have a preference.

		// Playlist repeat setting (default: true).
		public bool repeat;

		// Playlist shuffle setting (default: false).
		public bool shuffle;

		/***********
		* PLAYBACK *
		***********/

		// The index of the currently-selected track.
		public int current_track;

		/**********
		* SIGNALS *
		**********/

		// Indicates that the track *uri* was added to the playlist at *position*.
		public signal void track_added (string uri, int position);

		// Indicates that the track at *position* was removed from the playlist.
		public signal void track_removed (int position);

		// Indicates that the playlist has been cleared.
		public signal void playlist_cleared ();

		// Indicates that the track at *position* has begun playing.
		public signal void playing_track (int position);

		// Indicates that playback has been paused.
		public signal void paused_playback ();

		// Indicates that playback has been stopped.
		public signal void stopped_playback ();

		// Indicates that the current track has been seeked to *usec*.
		// FIXME: This might be unnecessary if clients are querying using
		//        get_progress ().
		public signal void seeked (int64 usec);

		// Indicates that the repeat setting has been changed to *do_repeat*.
		public signal void repeat_toggled (bool do_repeat);

		// Indicates that the shuffle setting has been changed to *do_shuffle*.
		public signal void shuffle_toggled (bool do_shuffle);

		/************
		* OPERATION *
		************/

		// The constructor...
		Player (string[] args)
		{
			this.mainloop = new GLib.MainLoop (null, false);
			
			// FIXME: See the FIXME under SETTINGS, above.
			set_repeat (true);
			set_shuffle (false);

			// Initialize the playlist pointer to the top of the list.
			this.current_track = 0;

			// Initialize GStreamer.
			Gst.init(ref args);
			
			debug ("GStreamer library initialized.");
			
			// Set up the pipeline for playing.
			this.pipeline = ElementFactory.make ("playbin", "pipeline");
			this.pipeline.set_state (Gst.State.READY);
			
			// Set up the bus for messages (such as when a song ends or an error
			// occurs).
			this.bus = this.pipeline.get_bus ();
			this.bus.add_watch (parse_message);
			
			debug ("Player instantiated.");

			register_dbus_service ();
		}

		// ... and its darker counterpart, the destructor.
		~Public ()
		{
			// Setting the pipeline to NULL signals GStreamer to clean up before exit.
			this.pipeline.set_state (Gst.State.NULL);
		}

		// Run the application.
		private void run ()
		{
			this.mainloop.run ();
		}

		// Tear down the application.
		public void quit ()
		{
			debug ("Quitting...");

			this.pipeline.set_state (Gst.State.NULL);
			
			debug ("Goodbye!");

			this.mainloop.quit ();
		}

		// The master callback that intercepts messages on the pipeline's bus.
		private bool parse_message (Gst.Bus bus, Gst.Message message)
		{
			switch (message.type)
			{
				case Gst.MessageType.ERROR:
					GLib.Error err;
					string debug;
					message.parse_error (out err, out debug);
					stderr.printf ("Error: %s\n", err.message);
					break;
				case MessageType.EOS:
					if (this.current_track < this.playlist.length () - 1 || get_repeat ())
					{
						next ();
					}

					// We're at the end of the playlist, and repeat is
					// disabled.
					else
					{
						stop ();
					}
					break;
				case MessageType.STATE_CHANGED:
				case MessageType.TAG:
				default:
					break;
			}

			return true;
		}

		// Register Hum as a DBus service.
		private void register_dbus_service ()
		{
			try
			{
				var conn = DBus.Bus.get (DBus.BusType.SESSION);

				dynamic DBus.Object dbus = conn.get_object ("org.freedesktop.DBus",
					"/org/freedesktop/DBus",
					"org.freedesktop.DBus");

				uint request_name_result = dbus.request_name ("org.washedup.Hum", (uint) 0);

				if (request_name_result == DBus.RequestNameReply.PRIMARY_OWNER)
				{
					conn.register_object ("/org/washedup/Hum", this);
					
					debug ("Successfully registered DBus service!");
					
					run ();
				}

				else
				{
					quit ();
				}
			}

			catch (DBus.Error e)
			{
				stderr.printf ("Shit! %s\n", e.message);
			}
		}

		/********
		* ORDER *
		********/

		// Append a new track to the playlist or, if *position* is specified, insert a new
		// track at position *position* in the playlist.
		// FIXME: We should first check if the URI is even valid before proceeding.
		public void add_track (string uri, int position = -1)
		{
			// FIXME: Catch the ConvertError that this throws...
			string path = GLib.Filename.from_uri (uri);

			if (FileUtils.test (path, GLib.FileTest.EXISTS))
			{
				if (position == -1)
				{
					position = (int) this.playlist.length ();
				}

				this.playlist.insert (uri, position);

				debug ("added '%s' to the playlist at position %d", uri, position);
			
				// If we add something ahead of the currently-selected track, its position
				// changes.
				if (position <= this.current_track)
				{
					this.current_track += 1;
				}

				// Emit a helpful signal.
				track_added (uri, position);
			}
		}

		// Delete the track at position *position* from the playlist.
		public void remove_track (int position)
		{
			if (position == this.current_track && this.pipeline.current_state == Gst.State.PLAYING)
			{
				stop ();
			}

			this.playlist.remove (this.playlist.nth_data (position));

			// If we remove something ahead of the currently-selected track, its
			// position changes.
			if (position < this.current_track)
			{
				this.current_track -= 1;
			}
			
			debug ("removed the track at position %d from the playlist", position);

			// Emit a helpful signal.
			track_removed (position);
		}

		// Remove the contents of the playlist.
		public void clear_playlist ()
		{
			stop ();
			this.playlist = new GLib.List<string> ();
			
			debug ("cleared the playlist");

			// Emit a helpful signal.
			playlist_cleared ();
		}

		// Return the contents of the playlist.
		// FIXME: Investigate using GLib.Array or something for *playlist* that is
		//        faster, smaller, less unweildy, and fits this model better.
		public string[] get_playlist ()
		{
			string[] list = new string[this.playlist.length ()];

			for (int i = 0; i < this.playlist.length (); i++)
			{
				list[i] = this.playlist.nth_data (i);
			}

			return list;
		}

		/***********
		* PLAYBACK *
		***********/

		// Start playback of the items in the playlist. If playback is paused, resume
		// playing the selected track. If *position* is specified, begin playback at *position*
		// position in the playist. Otherwise, start at the beginning.
		public void play (int position = -1)
		{
			// If there's nothing in the playlist, there's nothing to play!
			if (this.playlist.length () > 0)
			{
				if (position < 0)
				{
					var current_state = this.pipeline.current_state;

					if (current_state == Gst.State.PAUSED)
					{
						this.pipeline.set_state (Gst.State.PLAYING);

						debug ("resuming playback of the track at position %d", this.current_track);

						// Emit a helpful signal.
						playing_track (this.current_track);
					}

					else if (current_state == Gst.State.READY)
					{
						play (0);
					}
				}

				else
				{
					// If the user asks for a track that is outside the bounds of the list,
					// ignore the command, even if looping is enabled.
					if (position < this.playlist.length ())
					{
						// NOTE: This results in a reassignment (this.current_track = 0, then position), which is slightly wasteful.
						stop ();
						this.current_track = position;
						this.pipeline.set ("uri", this.playlist.nth_data (this.current_track));
						this.pipeline.set_state (Gst.State.PLAYING);
	
						debug ("playing the track at position %d", this.current_track);
	
						// Emit a helpful signal.
						playing_track (this.current_track);
					}
				}
			}
		}

		// Pause playback.
		public void pause ()
		{
			if (this.pipeline.current_state == Gst.State.PLAYING)
			{
				this.pipeline.set_state (Gst.State.PAUSED);

				debug ("paused playback");

				// Emit a helpful signal.
				paused_playback ();
			}
		}

		// Halt playback, resetting the playback pointer to the first item in the
		// playlist.
		public void stop ()
		{
			this.current_track = 0;
			this.pipeline.set_state (Gst.State.READY);
			
			debug ("stopped playback");

			// Emit a helpful signal.
			stopped_playback ();
		}

		// Play the next track in the playlist. If the current track is the last
		// track in the playlist and looping is enabled, play the first track in the
		// playlist.
		public void next ()
		{
			if (this.playlist.length () > 0)
			{
				if (this.current_track >= this.playlist.length () - 1)
				{
					if (repeat)
					{
						play (0);
					}
				}
	
				else
				{
					play (this.current_track + 1);
				}
	
				debug ("skipped to the next track in the playlist at position %d", this.current_track);
				}
		}

		// Play the previous track in the playlist. If the current track is the
		// first track in the playlist and looping is enabled, play the last track in
		// the playlist.
		public void previous ()
		{
			if (this.playlist.length () > 0)
			{
				if (this.current_track <= 0)
				{
					if (repeat)
					{
						play ((int) this.playlist.length () - 1);
					}
				}
	
				else
				{
					play (this.current_track - 1);
				}
	
				debug ("skipped to the previous track in the playlist at position %d", this.current_track);
			}
		}


		// Seek to *usec* in the currently-playing track. If no track is playing, do
		// nothing.
		public void seek (int64 usec)
		{
			this.pipeline.seek_simple (Gst.Format.TIME, Gst.SeekFlags.FLUSH, usec);
			
			float sec = (float) usec / 1000000000;
			debug ("seeked to %f seconds", sec);

			// Emit a helpful signal.
			seeked (usec);
		}

		// Return the currently selected track.
		public int get_current_track ()
		{
			return this.current_track;
		}

		// Return the currently selected track's uri.
		public string get_current_uri ()
		{
			return this.playlist.nth_data (this.current_track);
		}

		// Return the current track progress in usec.
		public int64 get_progress ()
		{
			int64 position;
			Gst.Format format = Gst.Format.TIME;

			if (this.pipeline.query_position (ref format, out position))
			{
				return position;
			}
			
			else
			{
				return -1;
			}
		}

		// Return the current playback state.
		public string get_playback_status ()
		{
			return this.pipeline.current_state.to_string ();
		}

		// Adjust playback volume.
		public void set_volume (int level)
		{
			// FIXME: How do you do this?
		}

		// Query playback volume.
		public int get_volume ()
		{
			// FIXME: And how do you do this?
			return 0;
		}

		/***********
		* SETTINGS *
		***********/

		// Toggle playlist looping.
		public void set_repeat (bool do_repeat)
		{
			// If it's already set to that value, do nothing.
			if (repeat != do_repeat)
			{
				repeat = do_repeat;

				// Emit a helpful signal.
				repeat_toggled (do_repeat);

				debug ("playlist repeat toggled '%s'", repeat.to_string ());
			}
		}

		// Toggle playlist shuffle.
		// FIXME: Make this work!
		public void set_shuffle (bool do_shuffle)
		{
			// If it's already set to that value, do nothing.
			if (shuffle != do_shuffle)
			{
				shuffle = do_shuffle;

				// Emit a helpful signal.
				shuffle_toggled (do_shuffle);

				debug ("playlist shuffle toggled '%s'", shuffle.to_string ());
			}
		}

		// Return the current repeat setting.
		public bool get_repeat ()
		{
			return repeat;
		}

		// Return the current shuffle setting.
		public bool get_shuffle ()
		{
			return shuffle;
		}

		/************
		* EXECUTION *
		************/
		
		static int main (string[] args)
		{
			new Player(args);

			return 0;
		}
	}
}
