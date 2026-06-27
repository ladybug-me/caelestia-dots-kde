// Minimal export header for qmake builds
#pragma once

#include <QtGlobal>

#if defined(QTERMWIDGET_LIBRARY)
#  define QTERMWIDGET_EXPORT Q_DECL_EXPORT
#else
#  define QTERMWIDGET_EXPORT Q_DECL_IMPORT
#endif

