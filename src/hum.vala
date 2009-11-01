/*
 * hum.vala
 * This file is part of Hum
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
//using Tracker
using Gst;

// FIXME: We'll start w/Gst.Playbin, but for playlist support we should move to
//        Gst.Decodebin in the future (cross-fading, etc.). 

namespace Hum
{	
	public class Track : GLib.Object
	{
		public string uri { get; set; }
		public string title { get; set; }
		public string artist { get; set; }
		public string album { get; set; }
		public int track_number { get; set; }
		public string release_date { get; set; }
		public string genre { get; set; }
		public string codec { get; set; }
		
		// The track length is in nanoseconds.
		public int64 duration { get; set; }
		
		// A reference to the global player object. 
		// FIXME: This could be a hell of a lot more elegant. 
		public weak Element player { get; set; }
		
		// This is an indicator of whether the track is currently playing or not. 
		// FIXME: Shouldn't this be more global, like the player's state? And it 
		//        should also be an enum. 
		public bool playing { get; set; }
		
		public Track (string uri)
		{
			// FIXME: Given a URI, GStreamer should populate all the properties. 
			this.uri = uri;
		}
		
		public void play ()
		{
			// FIXME: GStreamer code goes here. 
			message ("%s: playing...", this.uri);
			player.set ("uri", this.uri);
			player.set_state (Gst.State.PLAYING);
			this.playing = true;
		}
		
		public void pause ()
		{
			// FIXME: GStreamer code goes here. 
			message ("%s: paused.", this.uri);
			player.set_state (Gst.State.PAUSED);
		}
		
		public void stop ()
		{
			// FIXME: GStreamer code goes here. 
			message ("%s: stopped.", this.uri);
			player.set_state (Gst.State.READY);
			this.playing = false;
		}
	}
	
	// Playlists can be either tag-, file- or search-based in nature. 
	// FIXME: Nah. Playlists should be file-based only. Collections are more 
	//        likely what I mean by tag- and search-based, since in that case
	//        order doesn't matter.
	public enum ListType {Tag, File, Search}
	
	// FIXME: This should implement some doubly-linked list interface. 
	public class Playlist : GLib.Object//, GeeList<Track>
	{
		public string name { get; set; }
		public GLib.List<Track> list;
		
		// The playlist type (i.e. tag-, file- or search-based).
		public ListType type; 
		
		// Physical URIs will feature the default 'file://' prefix.
		// Search URIs will be prefixed with something like 'search://term[+term...]'.
		// Tag URIs will be prefixed with something like 'tags://term[+term...]'.
		public string uri; 
		
		// This is the index number of the currently selected track. If no track is
		// currently active, this is -1. 
		public int active; 
		
		public Playlist (string name) {}
		
		// Activate the previous item, if an item is active. If the first item is 
		// active, wrap to the end. 
		public void prev ()
		{
			if (active > -1)
			{
				active -= 1;
				
				if (active == -1)
				{
					active += (int) list.length ();
				}
			}
		}
		
		// Activate the next item, if an item is active. If the last item is active,
		// wrap to the beginning. 
		public void next ()
		{
			if (active > -1)
			{
				active += 1;
				
				if (active == list.length ())
				{
					active = 0;
				}
			}
		}
	}
	
	// This is the player backend itself. This should either be global to all
	// or a parent to each object. 
	public class Player : GLib.Object
	{
		public Playlist list { get; set; }
		public Element player { get; set; }

		Player ()
		{
			player = ElementFactory.make ("playbin", "player");
		}
		
		static int main (string[] args)
		{
			// Initialize GStreamer.
			Gst.init(ref args);
			message ("GStreamer library initialized.");
			
			// FIXME: Do I need to start the mainloop here?

			var p = new Player();
			message ("Player instantiated.");
			
			p.list = new Playlist ("Test");
			var t1 = new Track ("file:///home/brian/Audio/Girl.mp3");
			var t2 = new Track ("file:///home/brian/Audio/Lengths.mp3");
			
			// FIXME: THIS IS UGLY!!!
			t1.player = p.player;
			t2.player = p.player;
			
			p.list.list.append (t1);
			p.list.list.append (t2);
			
			message ("Tracks 1 & 2 appended to playlist.");
			
			p.list.active = 0;
			p.list.list.nth_data(p.list.active).play ();
			Thread.usleep(123456789);
			
			p.list.list.nth_data(p.list.active).pause ();
			p.list.list.nth_data(p.list.active).play ();
			p.list.list.nth_data(p.list.active).stop ();
			
			p.list.next ();
			p.list.list.nth_data(p.list.active).play ();
			
			p.list.next ();
			p.list.list.nth_data(p.list.active).play ();
			
			p.list.prev ();
			p.list.list.nth_data(p.list.active).play ();
			
			p.list.next ();
			p.list.next ();
			p.list.next ();
			p.list.list.nth_data(p.list.active).play ();

			return 0;
		}
	}
}
