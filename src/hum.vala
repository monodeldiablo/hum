/*
 * hum.vala
 * This file is part of Hum, and is thus awesome.
 *
 * Copyright (C) 2007-2009 by Brian Davis
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
//using DBus;
using Gst;

// FIXME: We'll start w/Gst.Playbin, but for playlist support we should move to
//        Gst.Decodebin in the future (cross-fading, etc.).

// Playlists can be either tag-, file- or search-based in nature. 
// FIXME: Nah. Playlists should be file-based only. Collections are more 
//        likely what I mean by tag- and search-based, since in that case
//        order doesn't matter.
//public enum ListType {Tag, File, Search}
// The playlist type (i.e. tag-, file- or search-based).
//public ListType type; 

// Physical URIs will feature the default 'file://' prefix.
// Search URIs will be prefixed with something like 'search://term[+term...]'.
// Tag URIs will be prefixed with something like 'tags://term[+term...]'.
//public string uri; 

// This is the index number of the currently selected track. If no track is
// currently active, this is -1. 
//public int active; 

namespace Hum
{
	// This is the player backend.
	public class Player : GLib.Object
	{
		// The GStreamer playback pipeline.
		public Element pipeline { get; set; }
		
		// The playlist, which is just a linked list of URIs.
		// FIXME: This should implement some doubly-linked list interface. 
		public GLib.List<string> playlist;

		///////////
		// STATE //
		///////////

		// Toggle playlist looping (default: true).
		public bool loop;

		//////////////
		// PLAYBACK //
		//////////////

		// The index of the currently-selected track.
		public int position;

		///////////////
		// OPERATION //
		///////////////

		Player ()
		{
			// FIXME: This should also construct the bus through which all messages and
			//        state changes are sent.
			pipeline = ElementFactory.make ("playbin", "pipeline");
			loop = true;
			position = 0;
			pipeline.set_state (Gst.State.READY);
			
			message ("Player instantiated.");
		}

		// Tear down the application.
		// FIXME: Is "MainLoop.quit()" all that's required?
		public void quit ()
		{
		}

		///////////
		// ORDER //
		///////////

		// Append a new track to the playlist or, if *pos* is specified, insert a new
		// track at position *pos* in the playlist.
		public void add (string uri, int pos = -1)
		{
			if (pos == -1)
			{
				playlist.append (uri);
				
				message ("appended '%s' to the playlist", uri);
			}
			else
			{
				playlist.insert (uri, pos);
				
				message ("inserted '%s' at position %d in the playlist", uri, pos);
			}
		}

		// Delete the track at position *pos* from the playlist.
		public void remove (int pos)
		{
			playlist.remove (playlist.nth_data (pos));
			
			message ("removed the track at position %d from the playlist", pos);
		}

		// Move a track from position *pos1* to *pos2* in the playlist.
		public void move (int pos1, int pos2)
		{
			string uri = playlist.nth_data (pos1);
			remove (pos1);
			add (uri, pos2);
			
			message ("moved the track at position %d to position %d within the playlist", pos1, pos2);
		}

		// Remove the contents of the playlist.
		public void clear ()
		{
			playlist = new GLib.List<string> ();
			
			message ("cleared the playlist");
		}

		//////////////
		// PLAYBACK //
		//////////////

		// Start playback of the items in the playlist. If playback is paused, resume
		// playing the selected track. If *pos* is specified, begin playback at *pos*
		// position in the playist. Otherwise, start at the beginning.
		public void play (int pos = -1)
		{
			if (pos == -1)
			{
				var current_state = pipeline.current_state;

				if (current_state == Gst.State.PAUSED)
				{
					pipeline.set_state (Gst.State.PLAYING);
				}
				else if (current_state == Gst.State.READY)
				{
					// FIXME: Would it be less redundant to just use "play (0)" here?
					pipeline.set ("uri", playlist.nth_data (position));
					pipeline.set_state (Gst.State.PLAYING);
				}

				message ("playing the track at position %d", position);
			}
			else
			{
				pipeline.set_state (Gst.State.READY);
				position = pos;
				pipeline.set ("uri", playlist.nth_data (position));
				pipeline.set_state (Gst.State.PLAYING);

				message ("playing the track at position %d", position);
			}
		}

		// Pause playback.
		public void pause ()
		{
			pipeline.set_state (Gst.State.PAUSED);
			
			message ("paused playback");
		}

		// Halt playback, resetting the playback pointer to the first item in the
		// playlist.
		public void stop ()
		{
			position = 0;
			pipeline.set_state (Gst.State.READY);
			
			message ("stopped playback");
		}

		// Play the next track if the current state is PLAYING. If the current track
		// is the last track in the playlist and looping is enabled, play the first
		// item in the playlist. If not, do nothing.
		public void next ()
		{
			var current_state = pipeline.current_state;

			if (current_state == Gst.State.PLAYING)
			{
				if (position == playlist.length ())
				{
					if (loop)
					{
						play (0);
					}
				}

				else
				{
					play (position + 1);
				}
			}

			message ("skipped to the next track in the playlist at position %d", position);
		}

		// Play the previous track if the current state is PLAYING. If the current
		// track is the first track in the playlist and looping is enabled, play the
		// last item in the playlist. If not, do nothing.
		public void prev ()
		{
			var current_state = pipeline.current_state;

			if (current_state == Gst.State.PLAYING)
			{
				if (position == 0)
				{
					if (loop)
					{
						play ((int) playlist.length ());
					}
				}

				else
				{
					play (position - 1);
				}
			}

			message ("skipped to the previous track in the playlist at position %d", position);
		}

		// Seek to *usec* in the currently-playing track. If no track is playing, do
		// nothing.
		public void seek (int64 usec)
		{
			pipeline.seek_simple (Gst.Format.TIME, Gst.SeekFlags.NONE, usec);
			
			// FIXME: What's the token for int64??
			//message ("seeked to %d", usec);
		}
		
		static int main (string[] args)
		{
			// Initialize GStreamer.
			Gst.init(ref args);
			
			message ("GStreamer library initialized.");
			
			// FIXME: Do I need to start the mainloop here?
			var context = new GLib.MainContext();
			var mainloop = new GLib.MainLoop(context, true);

			var p = new Player();
			
			p.add ("file:///home/brian/Audio/Girl.mp3");
			p.add ("file:///home/brian/Audio/Lengths.mp3");
			
			p.play ();
			mainloop.run();
			
			return 0;
		}
	}
}
