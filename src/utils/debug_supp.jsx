// debug_supp.jsx (v3) — placement test
#target illustrator

(function () {

    var folder = Folder.selectDialog("go_individual フォルダを選択");
    if (!folder) { alert("キャンセル"); return; }

    var doc;
    try { doc = app.activeDocument; }
    catch (e) { alert("ドキュメントが開いていません"); return; }

    alert("STEP 1: フォルダ = " + folder.fullName);

    // ---- place one file and measure ----
    var testPath = folder.fullName + "/delta_000ms.pdf";
    var testFile = new File(testPath);

    if (!testFile.exists) { alert("ERROR: delta_000ms.pdf が見つかりません"); return; }

    alert("STEP 2: delta_000ms.pdf を配置します...");

    var item;
    try {
        item = doc.placedItems.add();
        item.file = testFile;
        alert("STEP 3: 配置成功\n  width  = " + item.width + "\n  height = " + item.height);
    } catch (e) {
        alert("ERROR at placedItems.add or item.file:\n" + e.message);
        return;
    }

    // ---- test resize ----
    var PT   = 28.3465;
    var TOPO = 2.96 * PT;

    if (item.width === 0 || item.height === 0) {
        alert("ERROR: width/height = 0. 配置はされたがサイズが取得できません。\nitem を削除して終了します。");
        item.remove();
        return;
    }

    var sx = (TOPO / item.width)  * 100;
    var sy = (TOPO / item.height) * 100;
    alert("STEP 4: resize 前\n  sx = " + sx.toFixed(2) + "\n  sy = " + sy.toFixed(2));

    try {
        item.resize(sx, sy);
        item.position = [0, 0];
        alert("STEP 5: resize + position 成功。\n配置されたアイテムを確認してください。\n（削除はしていません）");
    } catch (e) {
        alert("ERROR at resize/position:\n" + e.message);
        item.remove();
        return;
    }

})();
