/*
 * hum_multi_selection_tree_view.vala
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

using Gtk;

namespace Hum
{
  public class MultiSelectionTreeView : Gtk.TreeView
  {
    private Gtk.TreePath? blocked_selection_path = null;

    public MultiSelectionTreeView ()
    {
      /* Allow multiple selections */
      Gtk.TreeSelection selection = this.get_selection ();
      selection.set_mode (Gtk.SelectionMode.MULTIPLE);

      this.button_press_event.connect (on_button_press_event);
      this.button_release_event.connect (on_button_release_event);
    }

    private bool on_button_press_event (Gdk.EventButton event)
    {
      /* Left mouse click */
      if (event.button == 1)
        return block_selection (event);

      /* not handled */
      return false;
    }

    private bool block_selection (Gdk.EventButton event)
    {
      /* Here we intercept mouse clicks on selected items, so that we can
         drag multiple items without the click selecting only one item. */
      Gtk.TreePath? path;
      bool valid = this.get_path_at_pos ((int)event.x, (int)event.y, out path, null, null, null);
      Gtk.TreeSelection selection = this.get_selection ();
      if (valid &&
          event.type == Gdk.EventType.BUTTON_PRESS &&
          ! (bool)(event.state & (Gdk.ModifierType.CONTROL_MASK | Gdk.ModifierType.SHIFT_MASK)) &&
          selection.path_is_selected (path))
      {
        /* Disable the selection */
        selection.set_select_function ((sel, mod, path, cursel) => { return false; });
        this.blocked_selection_path = path;
      }

      /* not handled */
      return false;
    }

    private bool on_button_release_event (Gdk.EventButton event)
    {
      /* re-enable selection */
      Gtk.TreeSelection selection = this.get_selection ();
      selection.set_select_function ((sel, mod, path, cursel) => { return true; });

      Gtk.TreePath? path;
      Gtk.TreeViewColumn? column;
      bool valid = this.get_path_at_pos ((int)event.x, (int)event.y, out path, out column, null, null);
      if (valid &&
          this.blocked_selection_path != null &&
          path.compare (this.blocked_selection_path) == 0 && // equal paths
          !(event.x == 0.0 && event.y == 0.0)) // a strange case
      {
        this.set_cursor (path, column, false);
      }
      this.blocked_selection_path = null;

      /* not handled */
      return false;
    }
  }
}
