/*
 * hum_search_view.vala
 *
 * This file is part of Hum, the low calorie music manager.
 *
 * Copyright (C) 2010 by Simon Wenner <simon@wenner.ch>
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
  public class SearchView : MultiSelectionTreeView
  {
    public SearchView ()
    {
      /* Properties */
      this.set_fixed_height_mode (true);
      this.set_enable_search (false);

      /* Signals */
      this.drag_data_get.connect (on_drag_data_get);
    }

    /* Deal with an DND source data request. */
    private void on_drag_data_get (Gtk.Widget widget, Gdk.DragContext context,
                                   Gtk.SelectionData selection_data,
                                   uint info, uint time)
    {
      GLib.List<Gtk.TreePath> rows;
			Gtk.TreeSelection selection = this.get_selection ();
      Gtk.TreeModel model;
      string[] uris;
      int i = 0;

      rows = selection.get_selected_rows (out model);
      uris = new string[selection.count_selected_rows ()];

      foreach (Gtk.TreePath path in rows)
      {
        Gtk.TreeIter iter;
        GLib.Value text;

        model.get_iter (out iter, path);
        model.get_value (iter, Columns.URI, out text);
        uris[i] = text.get_string ();
        debug ("Setting selection_data to %s", uris[i]);

        ++i;
      }

      selection_data.set_uris (uris);
    }
  }
}
