/*
* Copyright (c) 2016 Felipe Escoto (https://github.com/Philip-Scott/Spice-up)
*
* This program is free software; you can redistribute it and/or
* modify it under the terms of the GNU General Public
* License as published by the Free Software Foundation; either
* version 2 of the License, or (at your option) any later version.
*
* This program is distributed in the hope that it will be useful,
* but WITHOUT ANY WARRANTY; without even the implied warranty of
* MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
* General Public License for more details.
*
* You should have received a copy of the GNU General Public
* License along with this program; if not, write to the
* Free Software Foundation, Inc., 59 Temple Place - Suite 330,
* Boston, MA 02111-1307, USA.
*
* Authored by: Felipe Escoto <felescoto95@hotmail.com>
*/

public enum Spice.HistoryActionType {
    ITEM_MOVED,
    SLIDE_CHANGED,
    ITEM_CHANGED,
    CANVAS_CHANGED
}

public class Spice.Services.HistoryManager : Object {
    public const uint MAX_SIZE = 50;

    public signal void action_called (Spice.CanvasItem? item);

    public signal void undo_changed (bool is_empty);
    public signal void redo_changed (bool is_empty);

    public class HistoryAction<I,T> {
        private Value value;

        public HistoryActionType history_type;
        public I item = null;

        public string property;

        private HistoryAction () {}

        public HistoryAction.item_moved (I item) {
            this.item = item;
            this.property = "rectangle";

            history_type = HistoryActionType.ITEM_MOVED;
            get_item_property ();
        }

        public HistoryAction.item_changed (I item, string property) {
            this.item = item;
            this.property = property;
            history_type = HistoryActionType.ITEM_CHANGED;

            get_item_property ();
        }

        public HistoryAction.slide_changed (I item, string property) {
            this.item = item;
            this.property = property;
            history_type = HistoryActionType.SLIDE_CHANGED;

            get_item_property ();
        }

        public HistoryAction.canvas_changed (I item, string property) {
            this.item = item;
            this.property = property;

            history_type = HistoryActionType.CANVAS_CHANGED;
            get_item_property ();
        }

        private void get_item_property () {
            value = Value (typeof (T));
            (item as Object).get_property (property, ref value);
        }

        public void action () {
            var temp = Value (typeof (T));
            (item as Object).get_property (property, ref temp);
            (item as Object).set_property (property, value);

            if (history_type == HistoryActionType.ITEM_CHANGED) {
                (item as CanvasItem).style ();
            } else if (history_type == HistoryActionType.CANVAS_CHANGED) {
                (item as Canvas).style ();
            }

            this.value = temp;
        }
    }

    private Queue<HistoryAction> undo_history;
    private Queue<HistoryAction> redo_history;

    private static HistoryManager? instance = null;

    private HistoryManager () {
        undo_history = new Queue<HistoryAction>();
        redo_history = new Queue<HistoryAction>();
    }

    public static HistoryManager get_instance () {
        if (instance == null) {
            instance = new HistoryManager ();
        }

        return instance;
    }

    public void add_undoable_action (HistoryAction action, bool force_add = false) {
        redo_history.clear ();

        var last_action = undo_history.peek_head ();

        if (force_add || last_action == null
        || last_action.property != action.property
        || (last_action as HistoryAction<CanvasItem,string>).item != (action as HistoryAction<CanvasItem,string>).item) {
            undo_history.push_head (action);
        }

        if (undo_history.get_length () > MAX_SIZE) {
            undo_history.pop_tail ();
        }

        send_signals ();
    }

    public HistoryAction? undo () {
        if (undo_history.is_empty()) {
            return null;
        }

        var item = undo_history.pop_head ();
        item.action ();

        if (item.history_type != HistoryActionType.CANVAS_CHANGED) {
            action_called ((item as HistoryAction<CanvasItem,string>).item);
        } else {
            action_called (null);
        }

        redo_history.push_head (item);
        send_signals ();

        return item;
    }

    public HistoryAction? redo () {
        if (redo_history.is_empty()) {
            return null;
        }

        var item = redo_history.pop_head ();
        item.action ();

        if (item.history_type != HistoryActionType.CANVAS_CHANGED) {
            action_called ((item as HistoryAction<CanvasItem,string>).item);
        } else {
           action_called (null);
        }

        undo_history.push_head (item);
        send_signals ();

        return item;
    }

    private void send_signals () {
        undo_changed (undo_history.is_empty());
        redo_changed (redo_history.is_empty());
    }

    public void clear_history () {
        undo_history.clear ();
        redo_history.clear ();
    }
}
