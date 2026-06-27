/*
    This file is part of Konsole QML plugin,
    which is a terminal emulator from KDE.

    Copyright 2013      by Dmitry Zagnoyko <hiroshidi@gmail.com>

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
#include "ksession.h"
#include "TerminalDisplay.h"

// Qt
#include <QApplication>
#include <QGuiApplication>
#include <QPointer>
#include <QRegularExpression>

// Konsole
#include "KeyboardTranslator.h"
#include "HistorySearch.h"

KSession::KSession(QObject *parent) :
    QObject(parent), m_session(createSession(""))
{
    connect(m_session, SIGNAL(started()), this, SIGNAL(started()));
    connect(m_session, SIGNAL(finished()), this, SLOT(sessionFinished()));
    connect(m_session, SIGNAL(titleChanged()), this, SIGNAL(titleChanged()));
}

KSession::~KSession()
{
    if (m_session) {
        m_session->close();
        m_session->disconnect();
        delete m_session;
    }
}

void KSession::setTitle(QString name)
{
    m_session->setTitle(Session::NameRole, name);
}


Konsole::Session *KSession::createSession(QString name)
{
    Session *session = new Session();

    session->setTitle(Session::NameRole, name);

    /* Thats a freaking bad idea!!!!
     * /bin/bash is not there on every system
     * better set it to the current $SHELL
     * Maybe you can also make a list available and then let the widget-owner decide what to use.
     * By setting it to $SHELL right away we actually make the first filecheck obsolete.
     * But as iam not sure if you want to do anything else ill just let both checks in and set this to $SHELL anyway.
     */

    //cool-old-term: There is another check in the code. Not sure if useful.

    const QByteArray envshell = qgetenv("SHELL");
    const QString shellProg = envshell.isEmpty() ? QStringLiteral("/bin/bash") : QString::fromUtf8(envshell);
    m_shellProgram = shellProg;
    session->setProgram(shellProg);

    setenv("TERM", "xterm", 1);

    //session->setProgram();

    QStringList args("");
    m_shellArgs = args;
    session->setArguments(args);
    session->setAutoClose(true);

    session->setFlowControlEnabled(true);
    session->setHistoryType(HistoryTypeBuffer(1000));

    session->setDarkBackground(true);

    session->setKeyBindings("");

    return session;
}

/////////////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////////////////////////////////////////////////////


int  KSession::getRandomSeed()
{
    return m_session->sessionId() * 31;
}

void  KSession::addView(Konsole::TerminalDisplay *display)
{
    m_session->addView(display);
}

void KSession::removeView(Konsole::TerminalDisplay *display)
{
    m_session->removeView(display);
}

void KSession::sessionFinished()
{
    emit finished();
}

void KSession::selectionChanged(bool textSelected)
{
    Q_UNUSED(textSelected)
}

void KSession::startShellProgram()
{
    if ( m_session->isRunning() ) {
        return;
    }

    m_session->run();
}

bool KSession::sendSignal(int signal)
{
    if ( !m_session->isRunning() ) {
        return false;
    }

    return m_session->sendSignal(signal);
}

int KSession::getShellPID()
{
    return m_session->processId();
}

void KSession::changeDir(const QString &dir)
{
    /*
       this is a very hackish way of trying to determine if the shell is in
       the foreground before attempting to change the directory.  It may not
       be portable to anything other than Linux.
    */
    QString strCmd;
    strCmd.setNum(getShellPID());
    strCmd.prepend("ps -j ");
    strCmd.append(" | tail -1 | awk '{ print $5 }' | grep -q \\+");
    int retval = system(strCmd.toStdString().c_str());

    if (!retval) {
        QString cmd = "cd " + dir + "\n";
        sendText(cmd);
    }
}

void KSession::setEnvironment(const QStringList &environment)
{
    m_session->setEnvironment(environment);
}


void KSession::setShellProgram(const QString &progname)
{
    m_shellProgram = progname;
    m_session->setProgram(progname);
}

void KSession::setInitialWorkingDirectory(const QString &dir)
{
    if ( _initialWorkingDirectory != dir ) {
        _initialWorkingDirectory = dir;
        m_session->setInitialWorkingDirectory(dir);
        emit initialWorkingDirectoryChanged();
}   }

QString KSession::getInitialWorkingDirectory()
{
    return _initialWorkingDirectory;
}

QString KSession::getShellProgram() const
{
    return m_shellProgram;
}

QStringList KSession::getShellProgramArgs() const
{
    return m_shellArgs;
}

void KSession::setArgs(const QStringList &args)
{
    m_shellArgs = args;
    m_session->setArguments(args);
}

void KSession::setHistorySize(int lines)
{
    if ( historySize() != lines ) {
        if (lines < 0)
            m_session->setHistoryType(HistoryTypeFile());
        else
            m_session->setHistoryType(HistoryTypeBuffer(lines));
        emit historySizeChanged();
    }
}

int KSession::historySize() const
{
    if ( m_session->historyType().isUnlimited() ) {
        return -1;
    } else {
        return m_session->historyType().maximumLineCount();
    }
}

QString KSession::getHistory() const
{
    QString history;
    QTextStream historyStream(&history);
    PlainTextDecoder historyDecoder;

    historyDecoder.begin(&historyStream);
    m_session->emulation()->writeToStream(&historyDecoder);
    historyDecoder.end();

    return history;
}

void KSession::sendText(QString text)
{
    m_session->sendText(text);
}

void KSession::sendKey(int rep, int key, int mod) const
{
    //TODO implement or remove this function.
//    Qt::KeyboardModifier kbm = Qt::KeyboardModifier(mod);

//    QKeyEvent qkey(QEvent::KeyPress, key, kbm);

//    while (rep > 0){
//        m_session->sendKey(&qkey);
//        --rep;
    //    }
}

void KSession::clearScreen()
{
    m_session->emulation()->clearEntireScreen();
}

void KSession::search(const QString &regexp, int startLine, int startColumn, bool forwards)
{
    HistorySearch *history = new HistorySearch(QPointer<Emulation>(m_session->emulation()),
                                               QRegularExpression(regexp),
                                               forwards,
                                               startColumn,
                                               startLine,
                                               this);
    connect( history, SIGNAL(matchFound(int,int,int,int)), this, SIGNAL(matchFound(int,int,int,int)));
    connect( history, SIGNAL(noMatchFound()), this, SIGNAL(noMatchFound()));
    history->search();
}

void KSession::setFlowControlEnabled(bool enabled)
{
    m_session->setFlowControlEnabled(enabled);
}

bool KSession::flowControlEnabled()
{
    return m_session->flowControlEnabled();
}

void KSession::setKeyBindings(const QString &kb)
{
    m_session->setKeyBindings(kb);
    emit changedKeyBindings(kb);
}

QString KSession::getKeyBindings()
{
   return m_session->keyBindings();
}

QStringList KSession::availableKeyBindings()
{
    return KeyboardTranslatorManager::instance()->allTranslators();
}

QString KSession::keyBindings()
{
    return m_session->keyBindings();
}

QString KSession::getTitle()
{
    return m_session->userTitle();
}

bool KSession::hasActiveProcess() const
{
    return m_session->processId() != m_session->foregroundProcessId();
}

QString KSession::foregroundProcessName()
{
    return m_session->foregroundProcessName();
}

QString KSession::currentDir() 
{
    return m_session->currentDir();
}
