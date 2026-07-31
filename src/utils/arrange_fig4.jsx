// arrange_fig4.jsx
// Adobe Illustrator ExtendScript
//
// Layout:
//   A                          B
//   [experiment_condition_front] [experiment_condition_back]
//
// Both images are scaled to IMG_W (see layout parameters below).
// Labels "A" and "B" are left-aligned above each image.
//
// Usage: File > Scripts > Other Script ... > select this file

#target illustrator

(function () {

    // ------------------------------------------------------------------
    // 0.  Outer try-catch
    // ------------------------------------------------------------------
    try {

    // ---- Source file paths (use forward slashes) ---------------------
    var FILE_FRONT = "C:/Users/kaito/Downloads/experiment_condition_front.pdf";
    var FILE_BACK  = "C:/Users/kaito/Downloads/experiment_condition_back.pdf";

    // ------------------------------------------------------------------
    // 1.  Get active document
    // ------------------------------------------------------------------
    var doc;
    try {
        doc = app.activeDocument;
    } catch (e2) {
        alert("Error: No Illustrator document is open.\nPlease open a document and run the script again.");
        return;
    }

    // ------------------------------------------------------------------
    // 2.  Helper functions (outside inner try for ES3 compatibility)
    // ------------------------------------------------------------------

    var _doc = doc;
    var ARIAL_FONT      = null;   // resolved in layout section
    var ARIAL_BOLD_FONT = null;   // resolved in layout section

    // Place a PDF, scale proportionally to targetW, then EMBED it.
    // Embedding ensures the content is saved inside the .ai file.
    function placePDF(filePath, x, topY, targetW) {
        var file = new File(filePath);
        if (!file.exists) {
            alert("File not found:\n" + filePath);
            return null;
        }
        var item  = _doc.placedItems.add();
        item.file = file;
        var scale = (targetW / item.width) * 100;
        item.resize(scale, scale);
        item.position = [x, topY];
        item.embed();   // convert linked -> embedded so content is saved in the .ai file
        return item;
    }

    // Add a left-aligned bold text label at (lx, cy).
    function addLabel(str, lx, cy) {
        var tf = _doc.textFrames.add();
        tf.contents = str;
        var ca = tf.textRange.characterAttributes;
        ca.size = FONT_SIZE;
        var fnt = (ARIAL_BOLD_FONT !== null) ? ARIAL_BOLD_FONT : ARIAL_FONT;
        if (fnt !== null) { ca.textFont = fnt; }
        tf.position = [lx, cy + tf.height / 2];
        return tf;
    }

    // ------------------------------------------------------------------
    // 3.  Main layout
    // ------------------------------------------------------------------
    try {

        // ---- layout parameters (cm -> points;  1 cm = 28.3465 pt) ----
        var PT         = 28.3465;
        var IMG_W      = 8.00 * PT;   // target width for each image (cm; adjust as needed)
        var IMG_GAP    = 1.00 * PT;   // horizontal gap between the two images
        var LABEL_H    = 0.80 * PT;   // label row height above each image
        var LABEL_GAP  = 0.20 * PT;   // gap between label bottom and image top
        var FONT_SIZE  = 18;
        var AB_MARGIN  = 5;           // artboard margin (pt) to prevent clipping

        // ---- find Arial Regular and Arial Bold -----------------------
        var fi, fn;
        ARIAL_FONT = null;
        for (fi = 0; fi < app.textFonts.length; fi++) {
            fn = app.textFonts[fi].name;
            if (fn === "ArialMT") { ARIAL_FONT = app.textFonts[fi]; break; }
        }
        if (ARIAL_FONT === null) {
            for (fi = 0; fi < app.textFonts.length; fi++) {
                fn = app.textFonts[fi].name;
                if (fn.indexOf("Arial") === 0 && fn.indexOf("Bold") === -1 && fn.indexOf("Italic") === -1) {
                    ARIAL_FONT = app.textFonts[fi];
                    break;
                }
            }
        }
        ARIAL_BOLD_FONT = null;
        for (fi = 0; fi < app.textFonts.length; fi++) {
            fn = app.textFonts[fi].name;
            if (fn === "Arial-BoldMT") { ARIAL_BOLD_FONT = app.textFonts[fi]; break; }
        }
        if (ARIAL_BOLD_FONT === null) {
            for (fi = 0; fi < app.textFonts.length; fi++) {
                fn = app.textFonts[fi].name;
                if (fn.indexOf("Arial") === 0 && fn.indexOf("Bold") > -1 && fn.indexOf("Italic") === -1) {
                    ARIAL_BOLD_FONT = app.textFonts[fi];
                    break;
                }
            }
        }

        // ---- starting coordinates ------------------------------------
        var abRect  = doc.artboards[0].artboardRect;
        var originX = abRect[0];
        var originY = abRect[1];

        var xA = originX;
        var xB = originX + IMG_W + IMG_GAP;

        // ---- labels "A" and "B" (left-aligned above each image) ------
        var labelCY = originY - LABEL_H / 2;
        addLabel("A", xA, labelCY);
        addLabel("B", xB, labelCY);

        // ---- images (top edge just below label) ----------------------
        var imgTopY = originY - LABEL_H - LABEL_GAP;
        placePDF(FILE_FRONT, xA, imgTopY, IMG_W);
        placePDF(FILE_BACK,  xB, imgTopY, IMG_W);

        // ---- fit artboard to content + margin -------------------------
        var items = doc.pageItems;
        var i, gb;
        var minX, maxX, minY, maxY;
        minX =  999999; maxX = -999999;
        maxY = -999999; minY =  999999;
        for (i = 0; i < items.length; i++) {
            gb = items[i].geometricBounds;
            if (gb[0] < minX) { minX = gb[0]; }
            if (gb[1] > maxY) { maxY = gb[1]; }
            if (gb[2] > maxX) { maxX = gb[2]; }
            if (gb[3] < minY) { minY = gb[3]; }
        }
        doc.artboards[0].artboardRect = [
            minX - AB_MARGIN, maxY + AB_MARGIN,
            maxX + AB_MARGIN, minY - AB_MARGIN
        ];

        alert("Done.");

    } catch (e) {
        alert("Script error:\n" + e.message + "\n\nLine: " + e.line);
    }

    } catch (eFatal) {
        alert("Fatal error:\n" + eFatal.message + "\n\nLine: " + eFatal.line);
    }

})();
