qml_module(caelestia-images
    URI Caelestia.Images
    SOURCES
        cachingimageprovider.cpp
        cachingimageprovider.hpp
        imagecacher.cpp
        imagecacher.hpp
        iutils.cpp
        iutils.hpp
        kwinwindowthumbnailprovider.cpp
        kwinwindowthumbnailprovider.hpp
    LIBRARIES
        Qt::DBus
        Qt::Gui
        Qt::Quick
        Qt::Concurrent
)
