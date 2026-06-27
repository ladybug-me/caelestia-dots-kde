/*
    Copyright 2007-2008 by Robert Knight <robertknight@gmail.com>

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

// Own
#include "Filter.h"

// System
#include <iostream>

// Qt
#include <QAction>
#include <QApplication>
#include <QtAlgorithms>
#include <QClipboard>
#include <QString>
#include <QTextStream>
#include <QSharedData>
#include <QFile>
#include <QDesktopServices>
#include <QUrl>

// KDE
//#include <KLocale>
//#include <KRun>

// Konsole
#include "TerminalCharacterDecoder.h"
#include "konsole_wcwidth.h"

using namespace Konsole;

FilterChain::~FilterChain()
{
    QMutableListIterator<Filter*> iter(*this);

    while ( iter.hasNext() )
    {
        Filter* filter = iter.next();
        iter.remove();
        delete filter;
    }
}

RegExpFilter* FilterChain::getRegExpFilter(const QString& name) const
{
    QListIterator<Filter*> iter(*this);
    while (iter.hasNext())
    {
        Filter* filter = iter.next();
        if (auto f = qobject_cast<RegExpFilter*>(filter))
        {
            if (qobject_cast<UrlFilter*>(filter) == nullptr)
            {
                if (name.isEmpty() || f->objectName() == name)
                {
                    return f;
                }
            }
        }
    }
    return nullptr;
}

void FilterChain::addFilter(Filter* filter)
{
    append(filter);
}
void FilterChain::removeFilter(Filter* filter)
{
    removeAll(filter);
}
bool FilterChain::containsFilter(Filter* filter)
{
    return contains(filter);
}
void FilterChain::reset()
{
    QListIterator<Filter*> iter(*this);
    while (iter.hasNext())
        iter.next()->reset();
}
void FilterChain::setBuffer(const QString* buffer , const QList<int>* linePositions)
{
    QListIterator<Filter*> iter(*this);
    while (iter.hasNext())
        iter.next()->setBuffer(buffer,linePositions);
}
void FilterChain::process()
{
    QListIterator<Filter*> iter(*this);
    while (iter.hasNext())
        iter.next()->process();
}
void FilterChain::clear()
{
    QList<Filter*>::clear();
}
Filter::HotSpot* FilterChain::hotSpotAt(int line , int column) const
{
    QListIterator<Filter*> iter(*this);
    while (iter.hasNext())
    {
        Filter* filter = iter.next();
        Filter::HotSpot* spot = filter->hotSpotAt(line,column);
        if ( spot != nullptr )
        {
            return spot;
        }
    }

    return nullptr;
}

QList<Filter::HotSpot*> FilterChain::hotSpots() const
{
    QList<Filter::HotSpot*> list;
    QListIterator<Filter*> iter(*this);
    while (iter.hasNext())
    {
        Filter* filter = iter.next();
        list << filter->hotSpots();
    }
    return list;
}
//QList<Filter::HotSpot*> FilterChain::hotSpotsAtLine(int line) const;

TerminalImageFilterChain::TerminalImageFilterChain()
: _buffer(nullptr)
, _linePositions(nullptr)
{
}

TerminalImageFilterChain::~TerminalImageFilterChain()
{
    delete _buffer;
    delete _linePositions;
}

void TerminalImageFilterChain::setImage(const Character* const image , int lines , int columns, const QVector<LineProperty>& lineProperties)
{
    if (empty())
        return;

    // reset all filters and hotspots
    reset();

    PlainTextDecoder decoder;
    // Include trailing whitespace because otherwise, if a string is wrapped at
    // the end of a space, that space will not be taken into account in _buffer.
    decoder.setTrailingWhitespace(true);

    // setup new shared buffers for the filters to process on
    QString* newBuffer = new QString();
    QList<int>* newLinePositions = new QList<int>();
    setBuffer( newBuffer , newLinePositions );

    // free the old buffers
    delete _buffer;
    delete _linePositions;

    _buffer = newBuffer;
    _linePositions = newLinePositions;

    QTextStream lineStream(_buffer);
    decoder.begin(&lineStream);

    for (int i=0 ; i < lines ; i++)
    {
        _linePositions->append(_buffer->length());
        decoder.decodeLine(image + i*columns,columns,LINE_DEFAULT);

        // pretend that each line ends with a newline character.
        // this prevents a link that occurs at the end of one line
        // being treated as part of a link that occurs at the start of the next line
        //
        // the downside is that links which are spread over more than one line are not
        // highlighted.
        //
        // TODO - Use the "line wrapped" attribute associated with lines in a
        // terminal image to avoid adding this imaginary character for wrapped
        // lines
        if ( !(lineProperties.value(i,LINE_DEFAULT) & LINE_WRAPPED) )
            lineStream << QLatin1Char('\n');
    }
    decoder.end();
}

Filter::Filter() :
_linePositions(nullptr),
_buffer(nullptr)
{
}

Filter::~Filter()
{
    qDeleteAll(_hotspotList);
    _hotspotList.clear();
}
void Filter::reset()
{
    qDeleteAll(_hotspotList);
    _hotspots.clear();
    _hotspotList.clear();
}

void Filter::setBuffer(const QString* buffer , const QList<int>* linePositions)
{
    _buffer = buffer;
    _linePositions = linePositions;
}

void Filter::getLineColumn(int position , int& startLine , int& startColumn)
{
    Q_ASSERT( _linePositions );
    Q_ASSERT( _buffer );


    for (int i = 0 ; i < _linePositions->count() ; i++)
    {
        int nextLine = 0;

        if ( i == _linePositions->count()-1 )
            nextLine = _buffer->length() + 1;
        else
            nextLine = _linePositions->value(i+1);

        if ( _linePositions->value(i) <= position && position < nextLine )
        {
            startLine = i;
            startColumn = string_width(buffer()->mid(_linePositions->value(i),position - _linePositions->value(i)).toStdWString());
            return;
        }
    }
}


/*void Filter::addLine(const QString& text)
{
    _linePositions << _buffer.length();
    _buffer.append(text);
}*/

const QString* Filter::buffer()
{
    return _buffer;
}
Filter::HotSpot::~HotSpot()
{
}
void Filter::addHotSpot(HotSpot* spot)
{
    _hotspotList << spot;

    for (int line = spot->startLine() ; line <= spot->endLine() ; line++)
    {
        _hotspots.insert(line,spot);
    }
}
QList<Filter::HotSpot*> Filter::hotSpots() const
{
    return _hotspotList;
}
QList<Filter::HotSpot*> Filter::hotSpotsAtLine(int line) const
{
    return _hotspots.values(line);
}

Filter::HotSpot* Filter::hotSpotAt(int line , int column) const
{
    QListIterator<HotSpot*> spotIter(_hotspots.values(line));

    while (spotIter.hasNext())
    {
        HotSpot* spot = spotIter.next();

        if ( spot->startLine() == line && spot->startColumn() > column )
            continue;
        if ( spot->endLine() == line && spot->endColumn() < column )
            continue;

        return spot;
    }

    return nullptr;
}

Filter::HotSpot::HotSpot(int startLine , int startColumn , int endLine , int endColumn)
    : _startLine(startLine)
    , _startColumn(startColumn)
    , _endLine(endLine)
    , _endColumn(endColumn)
    , _type(NotSpecified)
{
}
QList<QAction*> Filter::HotSpot::actions()
{
    return QList<QAction*>();
}
int Filter::HotSpot::startLine() const
{
    return _startLine;
}
int Filter::HotSpot::endLine() const
{
    return _endLine;
}
int Filter::HotSpot::startColumn() const
{
    return _startColumn;
}
int Filter::HotSpot::endColumn() const
{
    return _endColumn;
}
Filter::HotSpot::Type Filter::HotSpot::type() const
{
    return _type;
}
void Filter::HotSpot::setType(Type type)
{
    _type = type;
}

RegExpFilter::RegExpFilter()
{
}

RegExpFilter::HotSpot::HotSpot(int startLine,int startColumn,int endLine,int endColumn)
    : Filter::HotSpot(startLine,startColumn,endLine,endColumn)
{
    setType(Marker);
}

void RegExpFilter::HotSpot::activate(const QString&)
{
}

void RegExpFilter::HotSpot::setCapturedTexts(const QStringList& texts)
{
    _capturedTexts = texts;
}
QStringList RegExpFilter::HotSpot::capturedTexts() const
{
    return _capturedTexts;
}

void RegExpFilter::setRegExp(const QRegularExpression& regExp)
{
    _searchText = regExp;
}
QRegularExpression RegExpFilter::regExp() const
{
    return _searchText;
}
/*void RegExpFilter::reset(int)
{
    _buffer = QString();
}*/
void RegExpFilter::process()
{
    const QString* text = buffer();

    Q_ASSERT( text );

    // ignore any regular expressions which match an empty string.
    // otherwise the while loop below will run indefinitely
    static const QString emptyString;
    auto match = _searchText.match(emptyString, 0,
        QRegularExpression::NormalMatch, QRegularExpression::AnchorAtOffsetMatchOption);
    if (match.hasMatch())
    {
        return;
    }

    match = _searchText.match(*text);
    while (match.hasMatch()) {
        int startLine = 0;
        int endLine = 0;
        int startColumn = 0;
        int endColumn = 0;

        QStringList captureList;
        for (int i = 0; i <= match.lastCapturedIndex(); i++) {
            QString text = match.captured(i);
            captureList.append(text);
        }

        getLineColumn(match.capturedStart(), startLine, startColumn);
        getLineColumn(match.capturedEnd(), endLine, endColumn);

        RegExpFilter::HotSpot* spot = newHotSpot(startLine, startColumn, endLine, endColumn);
        spot->setCapturedTexts(captureList);

        addHotSpot(spot);

        // if capturedLength == 0, the program will get stuck in an infinite loop
        if (match.capturedLength() == 0) {
            break;
        }

        match = _searchText.match(*text, match.capturedEnd());
    }
}

RegExpFilter::HotSpot* RegExpFilter::newHotSpot(int startLine,int startColumn,
                                                int endLine,int endColumn)
{
    return new RegExpFilter::HotSpot(startLine,startColumn,
                                                  endLine,endColumn);
}
RegExpFilter::HotSpot* UrlFilter::newHotSpot(int startLine,int startColumn,int endLine,
                                                    int endColumn)
{
    HotSpot *spot = new UrlFilter::HotSpot(startLine,startColumn,
                                               endLine,endColumn);
    connect(spot->getUrlObject(), &FilterObject::activated, this, &UrlFilter::activated);
    return spot;
}

UrlFilter::HotSpot::HotSpot(int startLine,int startColumn,int endLine,int endColumn)
: RegExpFilter::HotSpot(startLine,startColumn,endLine,endColumn)
, _urlObject(new FilterObject(this))
{
    setType(Link);
}

UrlFilter::HotSpot::UrlType UrlFilter::HotSpot::urlType() const
{
    QString url = capturedTexts().constFirst();

    if ( FullUrlRegExp.match(url).hasMatch() )
        return StandardUrl;
    else if ( EmailAddressRegExp.match(url).hasMatch() )
        return Email;
    else
        return Unknown;
}

void UrlFilter::HotSpot::activate(const QString& actionName)
{
    QString url = capturedTexts().constFirst();

    const UrlType kind = urlType();

    if ( actionName == QLatin1String("copy-action") )
    {
        QApplication::clipboard()->setText(url);
        return;
    }

    if ( actionName.isEmpty() || actionName == QLatin1String("open-action") || actionName == QLatin1String("click-action") )
    {
        if ( kind == StandardUrl )
        {
            // if the URL path does not include the protocol ( eg. "www.kde.org" ) then
            // prepend http:// ( eg. "www.kde.org" --> "http://www.kde.org" )
            if (!url.contains(QLatin1String("://")))
            {
                url.prepend(QLatin1String("http://"));
            }
        }
        else if ( kind == Email )
        {
            url.prepend(QLatin1String("mailto:"));
        }

        _urlObject->emitActivated(QUrl(url, QUrl::StrictMode), actionName != QLatin1String("click-action"));
    }
}

// Note:  Altering these regular expressions can have a major effect on the performance of the filters
// used for finding URLs in the text, especially if they are very general and could match very long
// pieces of text.
// Please be careful when altering them.

//regexp matches:
// full url:
// protocolname:// or www. followed by anything other than whitespaces, <, >, ' or ", and ends before whitespaces, <, >, ', ", ], !, comma and dot
const QRegularExpression UrlFilter::FullUrlRegExp(QLatin1String("(www\\.(?!\\.)|[a-z][a-z0-9+.-]*://)[^\\s<>'\"]+[^!,\\.\\s<>'\"\\]]"));
// email address:
// [word chars, dots or dashes]@[word chars, dots or dashes].[word chars]
const QRegularExpression UrlFilter::EmailAddressRegExp(QLatin1String("\\b(\\w|\\.|-)+@(\\w|\\.|-)+\\.\\w+\\b"));

// matches full url or email address
const QRegularExpression UrlFilter::CompleteUrlRegExp(QLatin1Char('(')+FullUrlRegExp.pattern()+QLatin1Char('|')+
                                            EmailAddressRegExp.pattern()+QLatin1Char(')'));

UrlFilter::UrlFilter()
{
    setRegExp( CompleteUrlRegExp );
}

UrlFilter::HotSpot::~HotSpot()
{
    delete _urlObject;
}

void FilterObject::emitActivated(const QUrl& url, bool fromContextMenu)
{
    emit activated(url, fromContextMenu);
}

void FilterObject::activate()
{
    _filter->activate(sender()->objectName());
}

FilterObject* UrlFilter::HotSpot::getUrlObject() const
{
    return _urlObject;
}

QList<QAction*> UrlFilter::HotSpot::actions()
{
    QList<QAction*> list;

    const UrlType kind = urlType();

    QAction* openAction = new QAction(_urlObject);
    QAction* copyAction = new QAction(_urlObject);;

    Q_ASSERT( kind == StandardUrl || kind == Email );

    if ( kind == StandardUrl )
    {
        openAction->setText(QObject::tr("Open Link"));
        copyAction->setText(QObject::tr("Copy Link Address"));
    }
    else if ( kind == Email )
    {
        openAction->setText(QObject::tr("Send Email To..."));
        copyAction->setText(QObject::tr("Copy Email Address"));
    }

    // object names are set here so that the hotspot performs the
    // correct action when activated() is called with the triggered
    // action passed as a parameter.
    openAction->setObjectName( QLatin1String("open-action" ));
    copyAction->setObjectName( QLatin1String("copy-action" ));

    QObject::connect( openAction , &QAction::triggered , _urlObject , &FilterObject::activate );
    QObject::connect( copyAction , &QAction::triggered , _urlObject , &FilterObject::activate );

    list << openAction;
    list << copyAction;

    return list;
}

//#include "Filter.moc"
