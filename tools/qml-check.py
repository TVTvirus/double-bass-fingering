# Carga el QML del plugin con un motor QML real para cazar errores de parseo
# (nombres de propiedad ilegales, sintaxis) sin necesitar MuseScore.
import re, sys, os
os.environ.setdefault("QT_QPA_PLATFORM", "offscreen")
from PyQt6.QtQml import QQmlEngine, QQmlComponent
from PyQt6.QtCore import QUrl, QCoreApplication

src = open(sys.argv[1], encoding='utf-8').read()

# El tipo MuseScore no existe fuera de MuseScore: lo cambiamos por QtObject y
# declaramos las propiedades del manifiesto para que el resto se parsee igual.
src = src.replace('import MuseScore 3.0', '')
src = src.replace('MuseScore {', '''QtObject {
    property string title
    property string categoryCode
    property bool requiresScore
    property string version
    property string description
    property int division
    property var curScore
    signal run()
    function newElement(t) { return null }
    function removeElement(e) {}
''', 1)
# onRun: <bloque>  ->  onRun: { ... }  ya es válido como handler de la señal run

tmp = sys.argv[1] + '.check.qml'
open(tmp, 'w', encoding='utf-8').write(src)

app = QCoreApplication([])
eng = QQmlEngine()
comp = QQmlComponent(eng, QUrl.fromLocalFile(tmp))

errs = [e for e in comp.errors()
        if 'Element' not in e.description() and 'Cursor' not in e.description()]
os.remove(tmp)

if errs:
    print("ERRORES DE QML:")
    for e in errs:
        print(f"  línea {e.line()}:{e.column()}  {e.description()}")
    sys.exit(1)
print("✓ el QML parsea sin errores de sintaxis ni de nombres de propiedad")
