/*
 * hum_play_list_view.vala
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
  public class PlayListView : MultiSelectionTreeView
  {
    // FIXME: The playlist should not need to know the Player. Remove it.
    private dynamic DBus.Object player;
    private Hum.SearchView search_view;

    public PlayListView (DBus.Object player, Hum.SearchView search_view)
    {
      this.player = player;
      this.search_view = search_view;

      /* Properties */
      this.set_fixed_height_mode (true);
      this.set_enable_search (false);
      this.set_reorderable (true);

      /* Signals */
      this.drag_data_get.connect (on_drag_data_get);
      this.drag_data_received.connect (on_drag_data_received);
    }

    /* Deal with an DND source data request. */
    private void on_drag_data_get (Gtk.Widget widget, Gdk.DragContext context,
                                   Gtk.SelectionData selection_data,
                                   uint info, uint time)
    {
    }

    /* Handle a DND drop event. */
    private void on_drag_data_received (Gdk.DragContext context, int x, int y,
                                        Gtk.SelectionData selection_data,
                                        uint info, uint time)
    {
      Gtk.TreePath path;
      Gtk.TreeViewDropPosition pos;
      Gtk.TreeIter iter;
      Gtk.TreeModel model = this.get_model ();
      int playlist_position;

      this.get_dest_row_at_pos (x, y, out path, out pos);

      if (path != null)
      {
        model.get_iter (out iter, path);
        playlist_position = path.to_string ().to_int ();
      }
      else
      {
          playlist_position = -1;
      }

      debug ("An item was dragged from %s", selection_data.target.name ());

      // If this was dragged from within the playlist view, treat it as a move.
      switch (selection_data.target.name ())
      {
        case "OTHER_ROW":
          Gtk.TreeIter selection_iter;
          GLib.Value uri;

          Gtk.TreeSelection selection = this.get_selection ();
          GLib.List<Gtk.TreePath> paths = selection.get_selected_rows (null);

          // FIXME: does not preserve the order of multiselections.
          foreach (Gtk.TreePath selection_path in paths)
          {
            model.get_iter (out selection_iter, selection_path);
            model.get_value (selection_iter, Columns.URI, out uri);
            this.player.AddTrack (uri.get_string (), playlist_position);
            this.player.RemoveTrack (model.get_string_from_iter (selection_iter).to_int ());
          }

          // Signal that the drag has successfully completed.
          Gtk.drag_finish (context, true, false, time);
          break;
        // Drag from the the SearchView to the Playlist.
        case "SEARCH_RESULT":
          GLib.List<Gtk.TreePath> rows;
          Gtk.TreeModel search_model;
          Gtk.TreeSelection search_select = this.search_view.get_selection ();

          rows = search_select.get_selected_rows (out search_model);

          foreach (Gtk.TreePath search_path in rows)
          {
              Gtk.TreeIter search_iter;
              GLib.Value uri;

              search_model.get_iter (out search_iter, search_path);
              search_model.get_value (search_iter, Columns.URI, out uri);
              this.player.AddTrack (uri.get_string (), playlist_position);
          }

          // Signal that the drag has successfully completed.
          Gtk.drag_finish (context, true, true, time);
          break;
        case "text/uri-list":
          string[] uris = selection_data.get_uris ();

          foreach (string uri in uris)
          {
              debug ("Adding '%s' to the playlist at position %d", uri, playlist_position);
              this.player.AddTrack (uri, playlist_position);
          }

          // Signal that the drag has successfully completed.
          Gtk.drag_finish (context, true, true, time);
          break;
        case "STRING":
        case "text/plain":
          string text = selection_data.get_text ();
          long size = text.length;
          string[] uris = text.split ("\r\n", (int)size);

          foreach (string uri in uris)
          {
              if (uri != "") {
                  debug ("Adding '%s' to the playlist at position %d", uri, playlist_position);
                  this.player.AddTrack (uri, playlist_position);
              }
          }

          // Signal that the drag has successfully completed.
          Gtk.drag_finish (context, true, true, time);
          break;
        default:
          debug ("Hum doesn't know how to handle data from that source!");

          // Signal that the drag has unsuccessfully completed.
          Gtk.drag_finish (context, false, true, time);
          break;
      }
    }
  }
}
