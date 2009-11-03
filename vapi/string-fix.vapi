[Compact]
[Immutable]
[CCode (cname = "char", const_cname = "const char", copy_function = "g_strdup", free_function = "g_free", cheader_filename = "stdlib.h,string.h,glib.h", type_id = "G_TYPE_STRING", marshaller_type_name = "STRING", get_value_function = "g_value_get_string", set_value_function = "g_value_set_string", type_signature = "s")]
public class string
{
	// This appears to have been left out of the base Vala distro.
	[CCode (cname = "g_utf8_collate_key")]
	public string collate_key (long len = -1);
}
