/*
 * hum_collection.vala
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

namespace Hum
{
	// FIXME: This should subclass Gee.ArrayList and make use of the various
	//        interfaces therein.
	//using Gee;
	public class Collection: GLib.Object
	{
		// Physical URIs will feature the default 'file://' prefix.
		// Search URIs will be prefixed with something like 'search://term[+term...]'.
		// Tag URIs will be prefixed with something like 'tags://term[+term...]'.
		public string uri; 
		
		public string name { get; construct set; }
		private List<Track> list;
		
		public Collection (string name)//, string uri)
		{
			/*
			if (uri.has_prefix ("tag"))
			{
				this.type = ListType.Tag;
			}
			else if (uri.has_prefix ("file"))
			{
				this.type = ListType.File;
			}
			else if (uri.has_prefix ("search"))
			{
				this.type = ListType.Search;
			}
			else
			{
				error ("Improperly formatted uri!");
			}
			*/
			this.name = name;
			this.list = new List<Track> ();
	
			debug ("Created a new playlist for \"%s\".", name);
		}
	
		public void append (Hum.Track track)
		{
			list.append (track);
		}
	
		public void remove (int position)
		{
			list.remove (list.nth_data ((uint) position));
		}

		public Hum.Track index (int position)
		{
			return list.nth_data ((uint) position);
		}
	
		public uint length ()
		{
			return list.length ();
		}
	}
}	
