// test_script.jsx — minimal test to confirm ExtendScript is working
#target illustrator

(function () {
    try {
        var doc = app.activeDocument;
        alert("Script is running.\n\nDocument: " + doc.name + "\nItems: " + doc.pageItems.length);
    } catch (e) {
        alert("Script is running, but no document is open.\n\nPlease open an Illustrator document first.");
    }
})();
