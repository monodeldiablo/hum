namespace Hum
{
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
}
