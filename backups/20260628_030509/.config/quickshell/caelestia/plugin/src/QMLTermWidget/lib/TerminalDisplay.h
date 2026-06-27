/*
    Copyright 2007-2008 by Robert Knight <robertknight@gmail.com>
    Copyright 1997,1998 by Lars Doelle <lars.doelle@on-line.de>

    This program is free software; you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation; either version 2 of the License, or
    (at your option) any later version.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with this program; if not, write to the Free Software
    Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA
    02110-1301  USA.
*/

#ifndef TERMINALDISPLAY_H
#define TERMINALDISPLAY_H

// Qt
#include <QColor>
#include <QPointer>
#include <QQuickPaintedItem>
#include <QString>
#include <QObject>
#include <QSize>

// Konsole
#include "Filter.h"
#include "Character.h"
#include "qtermwidget.h"
//#include "konsole_export.h"
#define KONSOLEPRIVATE_EXPORT

// QMLTermWidget
#include "ksession.h"
#include "ColorScheme.h"

class QDrag;
class QDragEnterEvent;
class QDropEvent;
class QLabel;
class QTimer;
class QEvent;
class QGridLayout;
class QKeyEvent;
class QShowEvent;
class QHideEvent;
class QTimerEvent;
class QWidget;

//class KMenu;

namespace Konsole
{

    enum MotionAfterPasting
    {
        // No move screenwindow after pasting
        NoMoveScreenWindow = 0,
        // Move start of screenwindow after pasting
        MoveStartScreenWindow = 1,
        // Move end of screenwindow after pasting
        MoveEndScreenWindow = 2
    };

    enum BackgroundMode {
        None,
        Stretch,
        Zoom,
        Fit,
        Center
    };

extern unsigned short vt100_graphics[32];

class ScreenWindow;
class ScrollBar;

/**
 * A widget which displays output from a terminal emulation and sends input keypresses and mouse activity
 * to the terminal.
 *
 * When the terminal emulation receives new output from the program running in the terminal,
 * it will update the display by calling updateImage().
 *
 * TODO More documentation
 */
class KONSOLEPRIVATE_EXPORT TerminalDisplay : public QQuickPaintedItem
{
   Q_OBJECT
   Q_PROPERTY(KSession* session         READ getSession      WRITE setSession     NOTIFY sessionChanged          )
   Q_PROPERTY(QFont font                READ getVTFont       WRITE setVTFont      NOTIFY vtFontChanged           )
   Q_PROPERTY(QString colorScheme       READ colorScheme     WRITE setColorScheme NOTIFY colorSchemeChanged      )
   Q_PROPERTY(QSize terminalSize        READ getTerminalSize                      NOTIFY changedContentSizeSignal)
   Q_PROPERTY(int lineSpacing           READ lineSpacing     WRITE setLineSpacing NOTIFY lineSpacingChanged      )
   Q_PROPERTY(bool terminalUsesMouse    READ getUsesMouse                         NOTIFY usesMouseChanged        )
   Q_PROPERTY(int lines                 READ lines                                NOTIFY changedContentSizeSignal)
   Q_PROPERTY(int columns               READ columns                              NOTIFY changedContentSizeSignal)
   Q_PROPERTY(int scrollbarCurrentValue READ getScrollbarValue                    NOTIFY scrollbarParamsChanged  )
   Q_PROPERTY(int scrollbarMaximum      READ getScrollbarMaximum                  NOTIFY scrollbarParamsChanged  )
   Q_PROPERTY(int scrollbarMinimum      READ getScrollbarMinimum                  NOTIFY scrollbarParamsChanged  )
   Q_PROPERTY(QSize fontMetrics         READ getFontMetrics                       NOTIFY changedFontMetricSignal )

   Q_PROPERTY(bool enableBold           READ getBoldIntense   WRITE setBoldIntense NOTIFY boldIntenseChanged )
   Q_PROPERTY(bool enableItalic         READ getItalicEnabled WRITE setItalicEnabled NOTIFY italicEnabledChanged )
   Q_PROPERTY(bool fullCursorHeight     READ fullCursorHeight WRITE setFullCursorHeight NOTIFY fullCursorHeightChanged)
   Q_PROPERTY(bool blinkingCursor       READ blinkingCursor   WRITE setBlinkingCursor NOTIFY blinkingCursorStateChanged)
   Q_PROPERTY(bool antialiasText        READ antialias       WRITE setAntialias)
   Q_PROPERTY(QStringList availableColorSchemes READ availableColorSchemes NOTIFY availableColorSchemesChanged)
   Q_PROPERTY(bool useFBORendering      READ useFBORendering WRITE setUseFBORendering)

public:
    /** Constructs a new terminal display widget with the specified parent. */
    TerminalDisplay(QQuickItem *parent=0);
    virtual ~TerminalDisplay();

    /** Returns the terminal color palette used by the display. */
    const ColorEntry* colorTable() const;
    /** Sets the terminal color palette used by the display. */
    void setColorTable(const ColorEntry table[]);
    /**
     * Sets the seed used to generate random colors for the display
     * (in color schemes that support them).
     */
    void setRandomSeed(uint seed);
    /**
     * Returns the seed used to generate random colors for the display
     * (in color schemes that support them).
     */
    uint randomSeed() const;

    /** Sets the opacity of the terminal display. */
    void setOpacity(qreal opacity);

    /** 
     * This enum describes the location where the scroll bar is positioned in the display widget.
     */
    enum ScrollBarPosition 
    { 
        /** Do not show the scroll bar. */
        NoScrollBar=0, 
        /** Show the scroll bar on the left side of the display. */
        ScrollBarLeft=1, 
        /** Show the scroll bar on the right side of the display. */
        ScrollBarRight=2 
    };
    /** 

    /** Sets the background image of the terminal display. */
    void setBackgroundImage(const QString& backgroundImage);

    /** Sets the background image mode of the terminal display. */
    void setBackgroundMode(BackgroundMode mode);

    /**
     * Specifies whether the terminal display has a vertical scroll bar, and if so whether it
     * is shown on the left or right side of the display.
     */
    void setScrollBarPosition(QTermWidget::ScrollBarPosition position);

    /**
     * Sets the current position and range of the display's scroll bar.
     *
     * @param cursor The position of the scroll bar's thumb.
     * @param lines The maximum value of the scroll bar.
     */
    void setScroll(int cursor, int lines);

    /**
     * Scroll to the bottom of the terminal (reset scrolling).
     */
    void scrollToEnd();

    /**
     * Returns the display's filter chain.  When the image for the display is updated,
     * the text is passed through each filter in the chain.  Each filter can define
     * hotspots which correspond to certain strings (such as URLs or particular words).
     * Depending on the type of the hotspots created by the filter ( returned by Filter::Hotspot::type() )
     * the view will draw visual cues such as underlines on mouse-over for links or translucent
     * rectangles for markers.
     *
     * To add a new filter to the view, call:
     *      viewWidget->filterChain()->addFilter( filterObject );
     */
    FilterChain* filterChain() const;

    /**
     * Updates the filters in the display's filter chain.  This will cause
     * the hotspots to be updated to match the current image.
     *
     * WARNING:  This function can be expensive depending on the
     * image size and number of filters in the filterChain()
     *
     * TODO - This API does not really allow efficient usage.  Revise it so
     * that the processing can be done in a better way.
     *
     * eg:
     *      - Area of interest may be known ( eg. mouse cursor hovering
     *      over an area )
     */
    void processFilters();

    /**
     * Returns a list of menu actions created by the filters for the content
     * at the given @p position.
     */
    QList<QAction*> filterActions(const QPoint& position);

    /** Returns true if the cursor is set to blink or false otherwise. */
    bool blinkingCursor() { return _hasBlinkingCursor; }
    /** Specifies whether or not the cursor blinks. */
    void setBlinkingCursor(bool blink);

    /** Specifies whether or not text can blink. */
    void setBlinkingTextEnabled(bool blink);

    void setCtrlDrag(bool enable) { _ctrlDrag=enable; }
    bool ctrlDrag() { return _ctrlDrag; }

    /**
     *  This enum describes the methods for selecting text when
      *  the user triple-clicks within the display.
      */
    enum TripleClickMode
    {
        /** Select the whole line underneath the cursor. */
        SelectWholeLine,
        /** Select from the current cursor position to the end of the line. */
        SelectForwardsFromCursor
    };
    /** Sets how the text is selected when the user triple clicks within the display. */
    void setTripleClickMode(TripleClickMode mode) { _tripleClickMode = mode; }
    /** See setTripleClickSelectionMode() */
    TripleClickMode tripleClickMode() { return _tripleClickMode; }

    void setLineSpacing(uint);
    void setMargin(int);

    int margin() const;
    uint lineSpacing() const;

    void emitSelection(bool useXselection,bool appendReturn);

    /** change and wrap text corresponding to paste mode **/
    void bracketText(QString& text) const;

    /**
     * Sets the shape of the keyboard cursor.  This is the cursor drawn
     * at the position in the terminal where keyboard input will appear.
     *
     * In addition the terminal display widget also has a cursor for
     * the mouse pointer, which can be set using the QWidget::setCursor()
     * method.
     *
     * Defaults to BlockCursor
     */
    void setKeyboardCursorShape(QTermWidget::KeyboardCursorShape shape);
    /**
     * Returns the shape of the keyboard cursor.  See setKeyboardCursorShape()
     */
    QTermWidget::KeyboardCursorShape keyboardCursorShape() const;

    /**
     * Sets the color used to draw the keyboard cursor.
     *
     * The keyboard cursor defaults to using the foreground color of the character
     * underneath it.
     *
     * @param useForegroundColor If true, the cursor color will change to match
     * the foreground color of the character underneath it as it is moved, in this
     * case, the @p color parameter is ignored and the color of the character
     * under the cursor is inverted to ensure that it is still readable.
     * @param color The color to use to draw the cursor.  This is only taken into
     * account if @p useForegroundColor is false.
     */
    void setKeyboardCursorColor(bool useForegroundColor , const QColor& color);

    /**
     * Returns the color of the keyboard cursor, or an invalid color if the keyboard
     * cursor color is set to change according to the foreground color of the character
     * underneath it.
     */
    QColor keyboardCursorColor() const;

    /**
     * Returns the number of lines of text which can be displayed in the widget.
     *
     * This will depend upon the height of the widget and the current font.
     * See fontHeight()
     */
    int  lines()   { return _lines;   }
    /**
     * Returns the number of characters of text which can be displayed on
     * each line in the widget.
     *
     * This will depend upon the width of the widget and the current font.
     * See fontWidth()
     */
    int  columns() { return _columns; }

    /**
     * Returns the height of the characters in the font used to draw the text in the display.
     */
    int  fontHeight()   { return _fontHeight;   }
    /**
     * Returns the width of the characters in the display.
     * This assumes the use of a fixed-width font.
     */
    int  fontWidth()    { return _fontWidth; }

    void setSize(int cols, int lins);
    void setFixedSize(int cols, int lins);

    // reimplemented
    QSize sizeHint() const;

    /**
     * Sets which characters, in addition to letters and numbers,
     * are regarded as being part of a word for the purposes
     * of selecting words in the display by double clicking on them.
     *
     * The word boundaries occur at the first and last characters which
     * are either a letter, number, or a character in @p wc
     *
     * @param wc An array of characters which are to be considered parts
     * of a word ( in addition to letters and numbers ).
     */
    void setWordCharacters(const QString& wc);
    /**
     * Returns the characters which are considered part of a word for the
     * purpose of selecting words in the display with the mouse.
     *
     * @see setWordCharacters()
     */
    QString wordCharacters() { return _wordCharacters; }

    /**
     * Sets the type of effect used to alert the user when a 'bell' occurs in the
     * terminal session.
     *
     * The terminal session can trigger the bell effect by calling bell() with
     * the alert message.
     */
    void setBellMode(int mode);
    /**
     * Returns the type of effect used to alert the user when a 'bell' occurs in
     * the terminal session.
     *
     * See setBellMode()
     */
    int bellMode() { return _bellMode; }

    /**
     * This enum describes the different types of sounds and visual effects which
     * can be used to alert the user when a 'bell' occurs in the terminal
     * session.
     */
    enum BellMode
    {
        /** A system beep. */
        SystemBeepBell=0,
        /**
         * KDE notification.  This may play a sound, show a passive popup
         * or perform some other action depending on the user's settings.
         */
        NotifyBell=1,
        /** A silent, visual bell (eg. inverting the display's colors briefly) */
        VisualBell=2,
        /** No bell effects */
        NoBell=3
    };

    void setSelection(const QString &t);

    /**
     * Reimplemented.  Has no effect.  Use setVTFont() to change the font
     * used to draw characters in the display.
     */
    virtual void setFont(const QFont &);

    /** Returns the font used to draw characters in the display */
    QFont getVTFont() { return font(); }

    /**
     * Sets the font used to draw the display.  Has no effect if @p font
     * is larger than the size of the display itself.
     */
    void setVTFont(const QFont& font);

    /**
     * Specified whether anti-aliasing of text in the terminal display
     * is enabled or not.  Defaults to enabled.
     */
    static void setAntialias( bool antialias ) { _antialiasText = antialias; }
    /**
     * Returns true if anti-aliasing of text in the terminal is enabled.
     */
    static bool antialias()                 { return _antialiasText;   }

    /**
     * Sets whether to use FramebufferObject rendering (true) or Image rendering (false).
     * FramebufferObject is GPU-based and more performant.
     * Image rendering is CPU-based and causes higher CPU usage, but can solve rendering issues.
     */
    void setUseFBORendering(bool useFBO) { 
        _useFBORendering = useFBO;
        QQuickPaintedItem::RenderTarget target = useFBO ?
            QQuickPaintedItem::FramebufferObject : QQuickPaintedItem::Image;

        QQuickPaintedItem::setRenderTarget(target);
    }

    /**
     * Returns true if using FramebufferObject rendering, false if using Image.
     */
    bool useFBORendering() const { return _useFBORendering; }

    /**
     * Specify whether line chars should be drawn by ourselves or left to
     * underlying font rendering libraries.
     */
    void setDrawLineChars(bool drawLineChars) { _drawLineChars = drawLineChars; }

    /**
     * Specifies whether characters with intense colors should be rendered
     * as bold. Defaults to true.
     */
    void setBoldIntense(bool value);
    /**
     * Returns true if characters with intense colors are rendered in bold.
     */
    bool getBoldIntense() { return _boldIntense; }

    /**
     * Specifies whether italic text rendering is allowed. Defaults to true.
     */
    void setItalicEnabled(bool value);
    /**
     * Returns true if italic text rendering is allowed.
     */
    bool getItalicEnabled() { return _italicEnabled; }

    /**
     * Sets whether or not the current height and width of the
     * terminal in lines and columns is displayed whilst the widget
     * is being resized.
     */
    void setTerminalSizeHint(bool on) { _terminalSizeHint=on; }
    /**
     * Returns whether or not the current height and width of
     * the terminal in lines and columns is displayed whilst the widget
     * is being resized.
     */
    bool terminalSizeHint() { return _terminalSizeHint; }
    /**
     * Sets whether the terminal size display is shown briefly
     * after the widget is first shown.
     *
     * See setTerminalSizeHint() , isTerminalSizeHint()
     */
    void setTerminalSizeStartup(bool on) { _terminalSizeStartup=on; }

    /**
     * Sets the status of the BiDi rendering inside the terminal display.
     * Defaults to disabled.
     */
    void setBidiEnabled(bool set) { _bidiEnabled=set; }
    /**
     * Returns the status of the BiDi rendering in this widget.
     */
    bool isBidiEnabled() { return _bidiEnabled; }

    /**
     * Sets the terminal screen section which is displayed in this widget.
     * When updateImage() is called, the display fetches the latest character image from the
     * the associated terminal screen window.
     *
     * In terms of the model-view paradigm, the ScreenWindow is the model which is rendered
     * by the TerminalDisplay.
     */
    void setScreenWindow( ScreenWindow* window );
    /** Returns the terminal screen section which is displayed in this widget.  See setScreenWindow() */
    ScreenWindow* screenWindow() const;

    static bool HAVE_TRANSPARENCY;

    void setMotionAfterPasting(MotionAfterPasting action);
    int motionAfterPasting();
    void setConfirmMultilinePaste(bool confirmMultilinePaste);
    void setTrimPastedTrailingNewlines(bool trimPastedTrailingNewlines);

    // maps a point on the widget to the position ( ie. line and column )
    // of the character at that point.
    void getCharacterPosition(const QPointF& widgetPoint,int& line,int& column) const;

    void disableBracketedPasteMode(bool disable) { _disabledBracketedPasteMode = disable; }
    bool bracketedPasteModeIsDisabled() const { return _disabledBracketedPasteMode; }

    int mouseAutohideDelay() const { return _mouseAutohideDelay; }

    /**
    * hide the mouse cursor after @param delay milliseconds of inactivity
    * @param delay < 0 deactivates the behavior
    */
    void autoHideMouseAfter(int delay);

public slots:

    /**
     * Causes the terminal display to fetch the latest character image from the associated
     * terminal screen ( see setScreenWindow() ) and redraw the display.
     */
    void updateImage();

    /** Essentially calls processFilters().
     */
    void updateFilters();

    /**
     * Causes the terminal display to fetch the latest line status flags from the
     * associated terminal screen ( see setScreenWindow() ).
     */
    void updateLineProperties();

    /** Copies the selected text to the clipboard. */
    void copyClipboard();
    /**
     * Pastes the content of the clipboard into the
     * display.
     */
    void pasteClipboard();
    /**
     * Pastes the content of the selection into the
     * display.
     */
    void pasteSelection();

    /**
       * Changes whether the flow control warning box should be shown when the flow control
       * stop key (Ctrl+S) are pressed.
       */
    void setFlowControlWarningEnabled(bool enabled);
    /**
     * Returns true if the flow control warning box is enabled.
     * See outputSuspended() and setFlowControlWarningEnabled()
     */
    bool flowControlWarningEnabled() const
    { return _flowControlWarningEnabled; }

    /**
     * Causes the widget to display or hide a message informing the user that terminal
     * output has been suspended (by using the flow control key combination Ctrl+S)
     *
     * @param suspended True if terminal output has been suspended and the warning message should
     *                     be shown or false to indicate that terminal output has been resumed and that
     *                     the warning message should disappear.
     */
    void outputSuspended(bool suspended);

    /**
     * Sets whether the program whose output is being displayed in the view
     * is interested in mouse events.
     *
     * If this is set to true, mouse signals will be emitted by the view when the user clicks, drags
     * or otherwise moves the mouse inside the view.
     * The user interaction needed to create selections will also change, and the user will be required
     * to hold down the shift key to create a selection or perform other mouse activities inside the
     * view area - since the program running in the terminal is being allowed to handle normal mouse
     * events itself.
     *
     * @param usesMouse Set to true if the program running in the terminal is interested in mouse events
     * or false otherwise.
     */
    void setUsesMouse(bool usesMouse);

    /** See setUsesMouse() */
    bool usesMouse() const;

    void setBracketedPasteMode(bool bracketedPasteMode);
    bool bracketedPasteMode() const;

    /**
     * Shows a notification that a bell event has occurred in the terminal.
     * TODO: More documentation here
     */
    void bell(const QString& message);

    /**
     * Sets the background of the display to the specified color.
     * @see setColorTable(), setForegroundColor()
     */
    void setBackgroundColor(const QColor& color);

    /**
     * Sets the text of the display to the specified color.
     * @see setColorTable(), setBackgroundColor()
     */
    void setForegroundColor(const QColor& color);

    void selectionChanged();

    // QMLTermWidget
    void setColorScheme(const QString &name);
    QString colorScheme() const;
    QStringList availableColorSchemes();

    void simulateKeyPress(int key, int modifiers, bool pressed, quint32 nativeScanCode, const QString &text);
    void simulateKeySequence(const QKeySequence &sequence);
    void simulateWheel(int x, int y, int buttons, int modifiers, QPointF angleDelta);
    void simulateMouseMove(int x, int y, int button, int buttons, int modifiers);
    void simulateMousePress(int x, int y, int button, int buttons, int modifiers);
    void simulateMouseRelease(int x, int y, int button, int buttons, int modifiers);
    void simulateMouseDoubleClick(int x, int y, int button, int buttons, int modifiers);

signals:

    /**
     * Emitted when the user presses a key whilst the terminal widget has focus.
     */
    void keyPressedSignal(QKeyEvent *e, bool fromPaste);

    /**
     * A mouse event occurred.
     * @param button The mouse button (0 for left button, 1 for middle button, 2 for right button, 3 for release)
     * @param column The character column where the event occurred
     * @param line The character row where the event occurred
     * @param eventType The type of event.  0 for a mouse press / release or 1 for mouse motion
     */
    void mouseSignal(int button, int column, int line, int eventType);
    void changedFontMetricSignal(int height, int width);
    void changedContentSizeSignal(int height, int width);

    /**
     * Emitted when the user right clicks on the display, or right-clicks with the Shift
     * key held down if usesMouse() is true.
     *
     * This can be used to display a context menu.
     */
    void configureRequest(const QPoint& position);

    /**
     * When a shortcut which is also a valid terminal key sequence is pressed while
     * the terminal widget  has focus, this signal is emitted to allow the host to decide
     * whether the shortcut should be overridden.
     * When the shortcut is overridden, the key sequence will be sent to the terminal emulation instead
     * and the action associated with the shortcut will not be triggered.
     *
     * @p override is set to false by default and the shortcut will be triggered as normal.
     */
    void overrideShortcutCheck(QKeyEvent* keyEvent,bool& override);

   void isBusySelecting(bool busy);
   void sendStringToEmu(const char*);

   // qtermwidget signals
    void copyAvailable(bool available);
	void termGetFocus();
	void termLostFocus();

    void notifyBell(const QString& bell);
    void usesMouseChanged();

    // QMLTermWidget
    void sessionChanged();
    void sizeChanged();
    void imagePainted();
    void scrollbarValueChanged();
    void scrollbarParamsChanged(int value);
    void vtFontChanged();
    void lineSpacingChanged();
    void availableColorSchemesChanged();
    void colorSchemeChanged();
    void fullCursorHeightChanged();
    void blinkingCursorStateChanged();
    void boldIntenseChanged();
    void italicEnabledChanged();

protected:
    bool event( QEvent * ) override;

    void showEvent(QShowEvent*);
    void hideEvent(QHideEvent*);
    void resizeEvent(QResizeEvent*);

    virtual void fontChange(const QFont &font);
    void focusInEvent(QFocusEvent* event) override;
    void focusOutEvent(QFocusEvent* event) override;
    // void enterEvent(QEnterEvent* event) override;
    // void leaveEvent(QEvent* event) override;
    void keyPressEvent(QKeyEvent* event) override;
    void mouseDoubleClickEvent(QMouseEvent* ev) override;
    void mousePressEvent( QMouseEvent* ) override;
    void mouseReleaseEvent( QMouseEvent* ) override;
    void mouseMoveEvent( QMouseEvent* ) override;
    virtual void extendSelection( const QPoint& pos );
    void wheelEvent( QWheelEvent* ) override;

    bool focusNextPrevChild( bool next );

    // drag and drop
    void dragEnterEvent(QDragEnterEvent* event) override;
    void dropEvent(QDropEvent* event) override;
    void doDrag();
    enum DragState { diNone, diPending, diDragging };

    struct _dragInfo {
      DragState       state;
      QPoint          start;
      QDrag           *dragObject;
    } dragInfo;

    // classifies the 'ch' into one of three categories
    // and returns a character to indicate which category it is in
    //
    //     - A space (returns ' ')
    //     - Part of a word (returns 'a')
    //     - Other characters (returns the input character)
    QChar charClass(const Character &ch) const;

    void clearImage();

    void mouseTripleClickEvent(QMouseEvent* ev);

    // reimplemented
    void inputMethodEvent ( QInputMethodEvent* event ) override;
    QVariant inputMethodQuery( Qt::InputMethodQuery query ) const override;

    // QMLTermWidget
    void paint(QPainter * painter);
    virtual void geometryChange(const QRectF & newGeometry, const QRectF & oldGeometry) override;
    void inputMethodQuery(QInputMethodQueryEvent *event);
    void itemChange(ItemChange change, const ItemChangeData & value);

protected slots:

    void scrollBarPositionChanged(int value);
    void blinkEvent();
    void blinkCursorEvent();

    //Renables bell noises and visuals.  Used to disable further bells for a short period of time
    //after emitting the first in a sequence of bell events.
    void enableBell();

private slots:

    void swapColorTable();
    void tripleClickTimeout();  // resets possibleTripleClick

private:

    // -- Drawing helpers --

    // determine the width of this text
    int textWidth(int startColumn, int length, int line) const;
    // determine the area that encloses this series of characters
    QRect calculateTextArea(int topLeftX, int topLeftY, int startColumn, int line, int length);

    // divides the part of the display specified by 'rect' into
    // fragments according to their colors and styles and calls
    // drawTextFragment() to draw the fragments
    void drawContents(QPainter &paint, const QRect &rect);
    // draws a section of text, all the text in this section
    // has a common color and style
    void drawTextFragment(QPainter& painter, const QRect& rect,
                          const std::wstring& text, const Character* style, bool tooWide);
    // draws the background for a text fragment
    // if useOpacitySetting is true then the color's alpha value will be set to
    // the display's transparency (set with setOpacity()), otherwise the background
    // will be drawn fully opaque
    void drawBackground(QPainter& painter, const QRect& rect, const QColor& color,
                        bool useOpacitySetting);
    // draws the cursor character
    void drawCursor(QPainter& painter, const QRect& rect , const QColor& foregroundColor,
                                       const QColor& backgroundColor , bool& invertColors);
    // draws the characters or line graphics in a text fragment
    void drawCharacters(QPainter& painter, const QRect& rect,  const std::wstring& text,
                                           const Character* style, bool invertCharacterColor,
                                           bool tooWide = false);
    // draws a string of line graphics
    void drawLineCharString(QPainter& painter, int x, int y,
                            const std::wstring& str, const Character* attributes) const;

    // draws the preedit string for input methods
    void drawInputMethodPreeditString(QPainter& painter , const QRect& rect);

    // --

    // maps an area in the character image to an area on the widget
    QRect imageToWidget(const QRect& imageArea) const;

    // the area where the preedit string for input methods will be draw
    QRect preeditRect() const;

    // shows a notification window in the middle of the widget indicating the terminal's
    // current size in columns and lines
    void showResizeNotification();

    // scrolls the image by a number of lines.
    // 'lines' may be positive ( to scroll the image down )
    // or negative ( to scroll the image up )
    // 'region' is the part of the image to scroll - currently only
    // the top, bottom and height of 'region' are taken into account,
    // the left and right are ignored.
    void scrollImage(int lines , const QRect& region);

    // shows the multiline prompt
    bool multilineConfirmation(const QString& text);

    void calcGeometry();
    void propagateSize();
    void updateImageSize();
    void makeImage();
    void calDrawTextAdditionHeight(QPainter& painter);

    void paintFilters(QPainter& painter);

    // returns a region covering all of the areas of the widget which contain
    // a hotspot
    QRegion hotSpotRegion() const;

    // returns the position of the cursor in columns and lines
    QPoint cursorPosition() const;

    // redraws the cursor
    void updateCursor();

    bool handleShortcutOverrideEvent(QKeyEvent* event);

    bool isLineChar(Character c) const;
    bool isLineCharString(const std::wstring& string) const;

    void hideStaleMouse() const; // conditionally hides the mouse cursor

    // the window onto the terminal screen which this display
    // is currently showing.
    QPointer<ScreenWindow> _screenWindow;

    bool _allowBell;

    QGridLayout* _gridLayout;

    bool _fixedFont; // has fixed pitch
    bool _fixedFont_original; // used only in textWidth()
    int  _fontHeight;     // height
    int  _fontWidth;     // width
    int  _fontAscent;     // ascend
    int  _drawTextAdditionHeight;   // additional height to prevent font truncation
    bool _drawTextTestFlag;         // indicates when text drawing metrics are being tested
    bool _boldIntense;   // Whether intense colors should be rendered with bold font
    bool _italicEnabled; // Whether italic rendition is allowed
    bool _useFBORendering; // Whether to use FramebufferObject (true) or Image (false)

    int _leftMargin;    // offset
    int _topMargin;    // offset

    int _lines;      // the number of lines that can be displayed in the widget
    int _columns;    // the number of columns that can be displayed in the widget

    int _usedLines;  // the number of lines that are actually being used, this will be less
                    // than 'lines' if the character image provided with setImage() is smaller
                    // than the maximum image size which can be displayed

    int _usedColumns; // the number of columns that are actually being used, this will be less
                     // than 'columns' if the character image provided with setImage() is smaller
                     // than the maximum image size which can be displayed

    int _contentHeight;
    int _contentWidth;
    Character* _image; // [lines][columns]
               // only the area [usedLines][usedColumns] in the image contains valid data

    int _imageSize;
    QVector<LineProperty> _lineProperties;

    ColorEntry _colorTable[TABLE_COLORS];
    uint _randomSeed;

    bool _resizing;
    bool _terminalSizeHint;
    bool _terminalSizeStartup;
    bool _bidiEnabled;
    bool _mouseMarks;
    bool _bracketedPasteMode;
    bool _disabledBracketedPasteMode;

    QPoint  _iPntSel; // initial selection point
    QPoint  _pntSel; // current selection point
    QPoint  _tripleSelBegin; // help avoid flicker
    int     _actSel; // selection state
    bool    _wordSelectionMode;
    bool    _lineSelectionMode;
    bool    _preserveLineBreaks;
    bool    _columnSelectionMode;

    QClipboard*  _clipboard;
    ScrollBar* _scrollBar;
    QTermWidget::ScrollBarPosition _scrollbarLocation;
    QString     _wordCharacters;
    int         _bellMode;

    bool _blinking;   // hide text in paintEvent
    bool _hasBlinker; // has characters to blink
    bool _cursorBlinking;     // hide cursor in paintEvent
    bool _hasBlinkingCursor;  // has blinking cursor enabled
    bool _allowBlinkingText;  // allow text to blink
    bool _ctrlDrag;           // require Ctrl key for drag
    TripleClickMode _tripleClickMode;
    bool _isFixedSize; //Columns / lines are locked.
    QTimer* _blinkTimer;  // active when hasBlinker
    QTimer* _blinkCursorTimer;  // active when hasBlinkingCursor
    static std::shared_ptr<QTimer> _hideMouseTimer;

    //QMenu* _drop;
    QString _dropText;
    int _dndFileCount;

    bool _possibleTripleClick;  // is set in mouseDoubleClickEvent and deleted
                               // after QApplication::doubleClickInterval() delay


    QLabel* _resizeWidget;
    QTimer* _resizeTimer;

    bool _flowControlWarningEnabled;

    //widgets related to the warning message that appears when the user presses Ctrl+S to suspend
    //terminal output - informing them what has happened and how to resume output
    QLabel* _outputSuspendedLabel;

    uint _lineSpacing;
    QString _colorScheme;
    bool _colorsInverted; // true during visual bell

    QSize _size;

    qreal _opacity;

    QPixmap _backgroundImage;
    BackgroundMode _backgroundMode;

    // list of filters currently applied to the display.  used for links and
    // search highlight
    TerminalImageFilterChain* _filterChain;
    QRegion _mouseOverHotspotArea;

    QTermWidget::KeyboardCursorShape _cursorShape;

    // custom cursor color.  if this is invalid then the foreground
    // color of the character under the cursor is used
    QColor _cursorColor;


    MotionAfterPasting mMotionAfterPasting;
    bool _confirmMultilinePaste;
    bool _trimPastedTrailingNewlines;

    struct InputMethodData
    {
        std::wstring preeditString;
        QRect previousPreeditRect;
    };
    InputMethodData _inputMethodData;

    static bool _antialiasText;   // do we antialias or not

    //the delay in milliseconds between redrawing blinking text
    static const int TEXT_BLINK_DELAY = 500;

    int _leftBaseMargin;
    int _topBaseMargin;

    // QMLTermWidget port functions
    QFont m_font;
    QPalette m_palette;
    QPalette::ColorRole m_color_role;
    KSession *m_session;
    bool m_full_cursor_height;

    QFont font() const { return m_font; }

    const QPalette palette() { return m_palette; }
    void setPalette(const QPalette &p){ m_palette = p; }

    QPalette::ColorRole backgroundRole() { return m_color_role; }
    void setBackgroundRole(QPalette::ColorRole role) { m_color_role = role; }

    void update(const QRegion &region);
    void update();

    QRect contentsRect() const;
    QSize size() const;

    void setSession(KSession *session);
    KSession* getSession();

    QSize getTerminalSize();

    bool getUsesMouse();

    int getScrollbarValue();
    int getScrollbarMaximum();
    int getScrollbarMinimum();

    QSize getFontMetrics();

    void setFullCursorHeight(bool val);

    bool _drawLineChars;

    int _mouseAutohideDelay;

public:
    static void setTransparencyEnabled(bool enable)
    {
        HAVE_TRANSPARENCY = enable;
    }
    bool fullCursorHeight() const;
};

class AutoScrollHandler : public QObject
{
Q_OBJECT

public:
    AutoScrollHandler(QWidget* parent);
protected:
    void timerEvent(QTimerEvent* event) override;
    bool eventFilter(QObject* watched,QEvent* event) override;
private:
    QWidget* widget() const { return static_cast<QWidget*>(parent()); }
    int _timerId;
};

class ScrollBar : public QObject
{
Q_OBJECT
public:
    explicit ScrollBar(QObject* parent = nullptr);

    void setRange(int min, int max);
    void setSingleStep(int step);
    void setPageStep(int step);
    void setValue(int value);
    int value() const;
    int minimum() const;
    int maximum() const;

    bool isHidden() const;
    void hide();
    void show();
    void setVisible(bool vis);

    int width() const;
    QSize sizeHint() const;
    void resize(int w, int h);
    void move(const QPoint&); // no-op placeholder

    void setCursor(Qt::CursorShape); // no-op
    void setPalette(const QPalette&); // no-op
    void setAutoFillBackground(bool); // no-op
    void setAttribute(Qt::WidgetAttribute); // no-op
    bool underMouse() const;
    bool isTransient() const { return false; }
    void handleEvent(QEvent*); // no-op hook

Q_SIGNALS:
    void valueChanged(int value);

private:
    int m_minimum{0};
    int m_maximum{0};
    int m_value{0};
    int m_singleStep{1};
    int m_pageStep{0};
    int m_width{0};
    int m_height{0};
    bool m_hidden{false};
};

}

#endif // TERMINALDISPLAY_H
