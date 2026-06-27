#ifndef QMLTERMWIDGET_PLUGIN_H
#define QMLTERMWIDGET_PLUGIN_H

#include <QQmlExtensionPlugin>

class QmltermwidgetPlugin : public QQmlExtensionPlugin
{
    Q_OBJECT
    Q_PLUGIN_METADATA(IID "org.qterminal.qmlterminal.QMLTermWidget")
    
public:
    void registerTypes(const char *uri);
    void initializeEngine(QQmlEngine *engine, const char *uri);
};

#endif // QMLTERMWIDGET_PLUGIN_H

