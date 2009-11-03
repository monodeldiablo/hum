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
		
		public Track (string uri)
		{
			// FIXME: Given a URI, GStreamer should populate all the properties. 
			this.uri = uri;
		}
	}
}

