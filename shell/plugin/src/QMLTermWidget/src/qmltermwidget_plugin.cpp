#include "qmltermwidget_plugin.h"

#include "TerminalDisplay.h"
#include "ksession.h"

#include <qqml.h>
#include <QQmlEngine>
#include <QDir>

using namespace Konsole;

void QmltermwidgetPlugin::registerTypes(const char *uri)
{
    // @uri org.qterminal.qmlterminal
    qmlRegisterType<TerminalDisplay>(uri, 2, 0, "QMLTermWidget");
    qmlRegisterType<KSession>(uri, 2, 0, "QMLTermSession");
}

void QmltermwidgetPlugin::initializeEngine(QQmlEngine *engine, const char *uri)
{
    QQmlExtensionPlugin::initializeEngine(engine, uri);

    QStringList pwds = engine->importPathList();

    if (!pwds.empty()){

        QString cs, kbl;

        foreach (QString pwd, pwds) {
            cs  = pwd + "/QMLTermWidget/color-schemes";
            kbl = pwd + "/QMLTermWidget/kb-layouts";
            if (QDir(cs).exists()) break;
        }

        setenv("KB_LAYOUT_DIR",kbl.toUtf8().constData(),1);
        setenv("COLORSCHEMES_DIR",cs.toUtf8().constData(),1);
    }
}
