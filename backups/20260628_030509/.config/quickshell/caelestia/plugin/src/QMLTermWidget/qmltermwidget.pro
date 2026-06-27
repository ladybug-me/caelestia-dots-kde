TEMPLATE = lib
TARGET = qmltermwidget
QT += qml quick widgets
CONFIG += qt plugin
DEFINES += QTERMWIDGET_LIBRARY

include(lib.pri)

DESTDIR = $$OUT_PWD/QMLTermWidget

DEFINES += HAVE_POSIX_OPENPT HAVE_SYS_TIME_H
macx:DEFINES += HAVE_UTMPX _UTMPX_COMPAT HAVE_PTSNAME HAVE_UNLOCKPT HAVE_GRANTPT

INCLUDEPATH += $$PWD/lib
DEPENDPATH  += $$PWD/lib
INCLUDEPATH += $$PWD/src

HEADERS += $$PWD/src/qmltermwidget_plugin.h \

# Copy the files useful to the plugin in DESTDIR
QMAKE_POST_LINK = $(COPY_DIR) $$PWD/lib/color-schemes $$DESTDIR && \
    $(COPY_DIR) $$PWD/lib/kb-layouts $$DESTDIR && \
    $$QMAKE_COPY $$PWD/src/qmldir $$DESTDIR && \
    $$QMAKE_COPY $$PWD/src/QMLTermScrollbar.qml $$DESTDIR

SOURCES += $$PWD/src/qmltermwidget_plugin.cpp \

OTHER_FILES += \
    src/QMLTermScrollbar.qml \
    test-app/test-app.qml \
    src/qmldir

#########################################
## INTALLS
#########################################

INSTALL_DIR = $$[QT_INSTALL_QML]
PLUGIN_IMPORT_PATH = QMLTermWidget
PLUGIN_ASSETS = $$PWD/src/QMLTermScrollbar.qml \
                $$PWD/lib/kb-layouts \
                $$PWD/lib/color-schemes

target.path = $$INSTALL_DIR/$$PLUGIN_IMPORT_PATH

assets.files += $$PLUGIN_ASSETS
assets.path += $$INSTALL_DIR/$$PLUGIN_IMPORT_PATH

qmldir.files += $$PWD/src/qmldir
qmldir.path += $$INSTALL_DIR/$$PLUGIN_IMPORT_PATH

colorschemes.files = $$PWD/lib/color-schemes/*
colorschemes.path = $$INSTALL_DIR/$$PLUGIN_IMPORT_PATH/color-schemes
colorschemes2.files = $$PWD/lib/color-schemes/historic/*
colorschemes2.path = $$INSTALL_DIR/$$PLUGIN_IMPORT_PATH/color-schemes/historic

kblayouts.files = $$PWD/lib/kb-layouts/*
kblayouts.path = $$INSTALL_DIR/$$PLUGIN_IMPORT_PATH/kb-layouts
kblayouts2.files = $$PWD/lib/kb-layouts/historic/*
kblayouts2.path = $$INSTALL_DIR/$$PLUGIN_IMPORT_PATH/kb-layouts/historic

scrollbar.files = $$PWD/src/QMLTermScrollbar.qml
scrollbar.path = $$INSTALL_DIR/$$PLUGIN_IMPORT_PATH

INSTALLS += target qmldir assets colorschemes colorschemes2 kblayouts kblayouts2 scrollbar
