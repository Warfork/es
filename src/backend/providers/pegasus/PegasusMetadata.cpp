// Pegasus Frontend
// Copyright (C) 2017-2018  Mátyás Mustoha
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with this program. If not, see <http://www.gnu.org/licenses/>.


#include "PegasusMetadata.h"

#include "ConfigFile.h"
#include "PegasusCommon.h"
#include "types/Game.h"

#include <QDebug>
#include <QFileInfo>
#include <QStringBuilder>


namespace {

} // namespace


namespace providers {
namespace pegasus {

enum class MetaAttribType : unsigned char {
    TITLE,
    DEVELOPER,
    PUBLISHER,
    GENRE,
    PLAYER_COUNT,
    SHORT_DESC,
    LONG_DESC,
    RELEASE,
    RATING,
};

PegasusMetadata::PegasusMetadata()
    : m_key_types {
        { QStringLiteral("title"), MetaAttribType::TITLE },
        { QStringLiteral("name"), MetaAttribType::TITLE },
        { QStringLiteral("developer"), MetaAttribType::DEVELOPER },
        { QStringLiteral("developers"), MetaAttribType::DEVELOPER },
        { QStringLiteral("publisher"), MetaAttribType::PUBLISHER },
        { QStringLiteral("publishers"), MetaAttribType::PUBLISHER },
        { QStringLiteral("genre"), MetaAttribType::GENRE },
        { QStringLiteral("genres"), MetaAttribType::GENRE },
        { QStringLiteral("players"), MetaAttribType::PLAYER_COUNT },
        { QStringLiteral("summary"), MetaAttribType::SHORT_DESC },
        { QStringLiteral("description"), MetaAttribType::LONG_DESC },
        { QStringLiteral("release"), MetaAttribType::RELEASE },
        { QStringLiteral("rating"), MetaAttribType::RATING },
    }
    , m_player_regex(QStringLiteral("(\\d+)(-(\\d+))?"))
    , m_rating_regex(QStringLiteral("(\\d+(\\.\\d+)?)%"))
    , m_release_regex(QStringLiteral("(\\d{4})(-(\\d{1,2}))?(-(\\d{1,2}))?"))
{
}

void PegasusMetadata::enhance_in_dirs(const QStringList& dir_list,
                                      const QHash<QString, Types::Game*>& games,
                                      const QHash<QString, Types::Collection*>&) const
{
    for (const QString& dir_path : dir_list) {
        read_metadata_file(dir_path, games);
    }
}


void PegasusMetadata::read_metadata_file(const QString& dir_path,
                                         const QHash<QString, Types::Game*>& games) const
{
    // reminder: sections are relative file paths

    QString curr_file_path;
    QString curr_game_path;
    Types::Game* curr_game = nullptr;

    const auto on_error = [&](const int lineno, const QString msg){
        qWarning().noquote()
            << QObject::tr("`%1`, line %2: %3")
                           .arg(curr_file_path, QString::number(lineno), msg);
    };
    const auto on_section = [&](const int lineno, const QString name){
        curr_game_path = dir_path % '/' % name;
        const QFileInfo fileinfo(curr_game_path);
        curr_game = nullptr;

        if (!games.contains(fileinfo.canonicalFilePath())) {
            on_error(lineno,
                QObject::tr("the game `%3` is either missing or excluded, values for it will be ignored").arg(name));
            return;
        }

        curr_game = games[fileinfo.canonicalFilePath()];
        Q_ASSERT(curr_game);
    };
    const auto on_attribute = [&](const int lineno, const QString key, const QString val){
        if (curr_game_path.isEmpty()) {
            on_error(lineno, QObject::tr("no sections defined yet, values ignored"));
            return;
        }
        if (!curr_game)
            return;

        if (key.startsWith(QLatin1String("x-"))) {
            // TODO: unimplemented
            return;
        }
        if (!m_key_types.contains(key)) {
            on_error(lineno, QObject::tr("unrecognized attribute name `%3`, ignored").arg(key));
            return;
        }

        switch (m_key_types[key]) {
            case MetaAttribType::TITLE:
                curr_game->m_title = val;
                break;
            case MetaAttribType::DEVELOPER:
                curr_game->addDevelopers(tokenize(val));
                break;
            case MetaAttribType::PUBLISHER:
                curr_game->addPublishers(tokenize(val));
                break;
            case MetaAttribType::GENRE:
                curr_game->addGenres(tokenize(val));
                break;
            case MetaAttribType::PLAYER_COUNT:
                {
                    const auto rx_match = m_player_regex.match(val);
                    if (rx_match.hasMatch()) {
                        const int a = rx_match.capturedRef(1).toInt();
                        const int b = rx_match.capturedRef(3).toInt();
                        curr_game->m_players = qMax(1, qMax(a, b));
                    }
                }
                break;
            case MetaAttribType::SHORT_DESC:
                curr_game->m_summary = val;
                break;
            case MetaAttribType::LONG_DESC:
                curr_game->m_description = val;
                break;
            case MetaAttribType::RELEASE:
                {
                    const auto rx_match = m_release_regex.match(val);
                    if (!rx_match.hasMatch()) {
                        on_error(lineno, QObject::tr("incorrect date format, should be YYYY(-MM(-DD))"));
                        return;
                    }

                    const int y = qMax(1, rx_match.captured(1).toInt());
                    const int m = qBound(1, rx_match.captured(3).toInt(), 12);
                    const int d = qBound(1, rx_match.captured(5).toInt(), 31);
                    curr_game->setRelease(QDate(y, m, d));
                }
                break;
            case MetaAttribType::RATING:
                {
                    const auto rx_match_a = m_rating_regex.match(val);
                    if (!rx_match_a.hasMatch()) {
                        on_error(lineno, QObject::tr("failed to parse rating value"));
                        return;
                    }

                    curr_game->m_rating = qBound(0.f, rx_match_a.capturedRef(1).toFloat() / 100.f, 1.f);
                }
                break;
        }
    };


    // the actual reading

    curr_file_path = dir_path + QStringLiteral("/metadata.pegasus.txt");
    config::readFile(curr_file_path, on_section, on_attribute, on_error);

    curr_file_path = dir_path + QStringLiteral("/metadata.txt");
    curr_game = nullptr;
    config::readFile(curr_file_path, on_section, on_attribute, on_error);
}

} // namespace pegasus
} // namespace providers