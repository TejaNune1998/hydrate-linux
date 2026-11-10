import QtQuick
Item { signal closeRequested(); signal tabRequested(var direction); property bool blocked: false; focus: true }
