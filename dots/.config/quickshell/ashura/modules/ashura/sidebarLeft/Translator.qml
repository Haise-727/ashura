import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import qs.modules.ashura.sidebarLeft.translator
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io

/**
 * Translator widget with the `trans` commandline tool.
 */
Item {
    id: root

    // Sizes
    property real padding: 4

    // Widgets
    property var inputField: inputCanvas.inputTextArea

    // Widget variables
    property bool translationFor: false // Indicates if the translation is for an autocorrected text
    property string translatedText: ""
    property list<string> languages: ["auto"].concat(langSettings.languages)

    // Options
    property string targetLanguage: Config.options.language.translator.targetLanguage
    property string sourceLanguage: Config.options.language.translator.sourceLanguage
    property string hostLanguage: targetLanguage

    // States
    property bool showLanguageSelector: false
    property bool languageSelectorTarget: false // true for target language, false for source language

    function showLanguageSelectorDialog(isTargetLang: bool) {
        root.languageSelectorTarget = isTargetLang;
        root.showLanguageSelector = true
    }

    onFocusChanged: (focus) => {
        if (focus) {
            root.inputField.forceActiveFocus()
        }
    }

    Timer {
        id: translateTimer
        interval: Config.options.sidebar.translator.delay
        repeat: false
        onTriggered: () => {
            if (root.inputField.text.trim().length > 0) {
                // console.log("Translating with command:", translateProc.command);
                translateProc.running = false;
                translateProc.buffer = ""; // Clear the buffer
                translateProc.running = true; // Restart the process
            } else {
                root.translatedText = "";
            }
        }
    }

    Process {
        id: translateProc
        command: ["bash", "-c", `trans -brief -no-bidi`
            + ` -source '${StringUtils.shellSingleQuoteEscape(root.sourceLanguage)}'`
            + ` -target '${StringUtils.shellSingleQuoteEscape(root.targetLanguage)}'`
            + ` '${StringUtils.shellSingleQuoteEscape(root.inputField.text.trim())}'`]
        property string buffer: ""
        stdout: SplitParser {
            onRead: data => {
                translateProc.buffer += data + "\n";
            }
        }
        onExited: (exitCode, exitStatus) => {
            // With -brief mode, we get output with no metadata
            root.translatedText = translateProc.buffer.trim();
        }
    }

    // Ashura: only the languages Haise uses, not trans's full list. Edit
    // ~/.config/ashura/translator.json to add more (trans language codes).
    FileView {
        id: langFile
        path: `${Directories.home.replace("file://", "")}/.config/ashura/translator.json`
        watchChanges: true
        onFileChanged: reload()
        onAdapterUpdated: writeAdapter()
        onLoadFailed: error => { if (error === FileViewError.FileNotFound) writeAdapter(); }
        JsonAdapter {
            id: langSettings
            property list<string> languages: ["en", "ja", "ko", "zh-CN", "ru", "es", "fr"]
        }
    }

    // Ashura layout (2026-11-09): languages on one row with a swap button, the
    // text to translate right under it, the translation right under that.
    // The old layout had the translation on top and the input pinned to the bottom with
    // empty space in between.
    function swapLanguages() {
        if (root.sourceLanguage === "auto") return;      // nothing to swap to
        const src = root.sourceLanguage;
        root.sourceLanguage = root.targetLanguage;
        root.targetLanguage = src;
        Config.options.language.translator.sourceLanguage = root.sourceLanguage;
        Config.options.language.translator.targetLanguage = root.targetLanguage;
        if (root.translatedText.trim().length > 0) root.inputField.text = root.translatedText;
        translateTimer.restart();
    }

    ColumnLayout {
        anchors {
            fill: parent
            margins: root.padding
        }
        spacing: 8

        RowLayout { // From -> To
            Layout.fillWidth: true
            spacing: 4
            LanguageSelectorButton {
                id: sourceLanguageButton
                displayText: root.sourceLanguage
                onClicked: root.showLanguageSelectorDialog(false)
            }
            RippleButton {
                implicitWidth: 34
                implicitHeight: 34
                buttonRadius: 17
                enabled: root.sourceLanguage !== "auto"
                onClicked: root.swapLanguages()
                contentItem: MaterialSymbol {
                    anchors.centerIn: parent
                    text: "swap_horiz"
                    iconSize: Appearance.font.pixelSize.larger
                    color: parent.enabled ? Appearance.colors.colOnLayer1 : Appearance.colors.colSubtext
                }
                StyledToolTip { text: Translation.tr("Swap languages") }
            }
            LanguageSelectorButton {
                id: targetLanguageButton
                displayText: root.targetLanguage
                onClicked: root.showLanguageSelectorDialog(true)
            }
            Item { Layout.fillWidth: true }
            StyledText {
                visible: translateProc.running
                text: Translation.tr("Translating…")
                color: Appearance.colors.colSubtext
                font.pixelSize: Appearance.font.pixelSize.smaller
            }
        }

        TextCanvas { // Content input
            id: inputCanvas
            Layout.fillWidth: true
            Layout.preferredHeight: 190
            isInput: true
            placeholderText: Translation.tr("Enter text to translate...")
            onInputTextChanged: {
                translateTimer.restart();
            }
            GroupButton {
                id: pasteButton
                baseWidth: height
                buttonRadius: Appearance.rounding.small
                contentItem: MaterialSymbol {
                    anchors.centerIn: parent
                    horizontalAlignment: Text.AlignHCenter
                    iconSize: Appearance.font.pixelSize.larger
                    text: "content_paste"
                    color: Appearance.colors.colOnLayer1
                }
                onClicked: {
                    root.inputField.text = Quickshell.clipboardText
                }
            }
            GroupButton {
                id: deleteButton
                baseWidth: height
                buttonRadius: Appearance.rounding.small
                enabled: inputCanvas.inputTextArea.text.length > 0
                contentItem: MaterialSymbol {
                    anchors.centerIn: parent
                    horizontalAlignment: Text.AlignHCenter
                    iconSize: Appearance.font.pixelSize.larger
                    text: "close"
                    color: deleteButton.enabled ? Appearance.colors.colOnLayer1 : Appearance.colors.colSubtext
                }
                onClicked: {
                    root.inputField.text = ""
                }
            }
        }

        StyledFlickable { // Content translation
            Layout.fillWidth: true
            Layout.fillHeight: true
            contentHeight: outputCanvas.implicitHeight
            clip: true

            TextCanvas {
                id: outputCanvas
                width: parent.width
                isInput: false
                placeholderText: Translation.tr("Translation goes here...")
                property bool hasTranslation: (root.translatedText.trim().length > 0)
                text: hasTranslation ? root.translatedText : ""
                GroupButton {
                    id: copyButton
                    baseWidth: height
                    buttonRadius: Appearance.rounding.small
                    enabled: outputCanvas.displayedText.trim().length > 0
                    contentItem: MaterialSymbol {
                        anchors.centerIn: parent
                        horizontalAlignment: Text.AlignHCenter
                        iconSize: Appearance.font.pixelSize.larger
                        text: "content_copy"
                        color: copyButton.enabled ? Appearance.colors.colOnLayer1 : Appearance.colors.colSubtext
                    }
                    onClicked: {
                        Quickshell.clipboardText = outputCanvas.displayedText
                    }
                }
                GroupButton {
                    id: searchButton
                    baseWidth: height
                    buttonRadius: Appearance.rounding.small
                    enabled: outputCanvas.displayedText.trim().length > 0
                    contentItem: MaterialSymbol {
                        anchors.centerIn: parent
                        horizontalAlignment: Text.AlignHCenter
                        iconSize: Appearance.font.pixelSize.larger
                        text: "travel_explore"
                        color: searchButton.enabled ? Appearance.colors.colOnLayer1 : Appearance.colors.colSubtext
                    }
                    onClicked: {
                        let url = Config.options.search.engineBaseUrl + outputCanvas.displayedText;
                        for (let site of Config.options.search.excludedSites) {
                            url += ` -site:${site}`;
                        }
                        Qt.openUrlExternally(url);
                    }
                }
            }
        }
    }

    Loader {
        anchors.fill: parent
        active: root.showLanguageSelector
        visible: root.showLanguageSelector
        z: 9999
        sourceComponent: SelectionDialog {
            id: languageSelectorDialog
            titleText: Translation.tr("Select Language")
            items: root.languages
            defaultChoice: root.languageSelectorTarget ? root.targetLanguage : root.sourceLanguage
            onCanceled: () => {
                root.showLanguageSelector = false;
            }
            onSelected: (result) => {
                root.showLanguageSelector = false;
                if (!result || result.length === 0) return; // No selection made

                if (root.languageSelectorTarget) {
                    root.targetLanguage = result;
                    Config.options.language.translator.targetLanguage = result; // Save to config
                } else {
                    root.sourceLanguage = result;
                    Config.options.language.translator.sourceLanguage = result; // Save to config
                }

                translateTimer.restart(); // Restart translation after language change
            }
        }
    }
}
