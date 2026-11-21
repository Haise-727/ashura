pragma Singleton

import qs.modules.common
import qs.modules.common.functions
import QtQuick
import Quickshell
import Quickshell.Io

/*
 * Ashura: dated items (deadlines, reminders, to-dos), one list for the whole
 * shell. The dashboard calendar marks the days that have items and edits them;
 * a checklist or reminder feature should read and write this same list.
 *
 * ~/.config/ashura/agenda.json:
 *   { "items": [ { "id": "k3x9...", "date": "2026-11-24", "title": "...",
 *                  "done": false, "kind": "deadline" } ] }
 * `date` is local, YYYY-MM-DD. `kind` is free text ("deadline", "todo", ...).
 */
Singleton {
    id: root
    readonly property var items: adapter.items
    // date -> number of open (not done) items, for the calendar's dots.
    readonly property var openCount: {
        const m = {};
        for (const it of adapter.items) if (!it.done) m[it.date] = (m[it.date] || 0) + 1;
        return m;
    }
    // date -> number of items in all.
    readonly property var allCount: {
        const m = {};
        for (const it of adapter.items) m[it.date] = (m[it.date] || 0) + 1;
        return m;
    }

    function isoDate(d) {
        const p = n => String(n).padStart(2, "0");
        return `${d.getFullYear()}-${p(d.getMonth() + 1)}-${p(d.getDate())}`;
    }
    function itemsOn(date) { return adapter.items.filter(it => it.date === date); }
    function add(date, title, kind) {
        const t = String(title || "").trim();
        if (!date || !t) return;
        const id = Date.now().toString(36) + Math.random().toString(36).slice(2, 6);
        adapter.items = adapter.items.concat([{ id: id, date: date, title: t, done: false, kind: kind || "deadline" }]);
    }
    function toggle(id) { adapter.items = adapter.items.map(it => it.id === id ? Object.assign({}, it, { done: !it.done }) : it); }
    function remove(id) { adapter.items = adapter.items.filter(it => it.id !== id); }

    FileView {
        path: `${FileUtils.trimFileProtocol(Directories.home)}/.config/ashura/agenda.json`
        watchChanges: true
        onFileChanged: reload()
        onAdapterUpdated: writeAdapter()
        onLoadFailed: error => { if (error === FileViewError.FileNotFound) writeAdapter(); }
        JsonAdapter {
            id: adapter
            property list<var> items: []
        }
    }
}
