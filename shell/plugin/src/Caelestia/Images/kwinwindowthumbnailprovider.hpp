#pragma once

#include <qquickimageprovider.h>

namespace caelestia::images {

class KWinWindowThumbnailProvider : public QQuickAsyncImageProvider {
public:
    QQuickImageResponse* requestImageResponse(const QString& id, const QSize& requestedSize) override;
};

} // namespace caelestia::images