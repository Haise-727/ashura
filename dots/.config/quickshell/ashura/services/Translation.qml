pragma Singleton

import QtQuick
import Quickshell

/*
 * Ashura is English only. tr() stays so every label keeps one call site
 * (and a translation layer could come back later), but it returns the text
 * as written. languageCode is the system locale, used by the screen
 * translator as its default target language.
 */
Singleton {
    id: root

    readonly property string languageCode: Qt.locale().name

    function tr(text) {
        return text ? text.toString() : "";
    }
}
