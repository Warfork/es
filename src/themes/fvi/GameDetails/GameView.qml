// gameOS theme
// Copyright (C) 2018-2020 Seth Powell 
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

import QtQuick 2.8
import QtQuick.Layouts 1.11
import QtGraphicalEffects 1.0
import SortFilterProxyModel 0.2
import QtQml.Models 2.10
import QtMultimedia 5.9
import "../Global"
import "../GridView"
import "../Lists"
import "../utils.js" as Utils

FocusScope {
id: root

    // Pull in our custom lists and define
    ListAllGames    { id: listNone;        max: 0 }
    ListAllGames    { id: listAllGames;    max: settings.ShowcaseColumns }
    ListFavorites   { id: listFavorites;   max: settings.ShowcaseColumns }
    ListFavoritesWhitelists   { id: listFavoritesWhitelists;   max: settings.ShowcaseColumns }	
    ListWhitelists   { id: listWhitelists;   max: settings.ShowcaseColumns }
    ListLastPlayed  { id: listLastPlayed;  max: settings.ShowcaseColumns }
    ListMostPlayed  { id: listMostPlayed;  max: settings.ShowcaseColumns }
    ListRecommended { id: listRecommended; max: settings.ShowcaseColumns }
    ListPublisher   { id: listPublisher;   max: settings.ShowcaseColumns; publisher: randoPub }
    ListGenre       { id: listGenre;       max: settings.ShowcaseColumns; genre: randoGenre }
	
    property var game: api.allGames.get(0)
	property string favIcon: game && game.favorite ? "http://forbidden.gg/assets/media/theme/icon_unheart.png" : "http://forbidden.gg/assets/media/theme/icon_heart.png"
    property string whitelistIcon: game && game.whitelist ? "http://forbidden.gg/assets/media/theme/icon_unwhitelist.png" : "http://forbidden.gg/assets/media/theme/icon_whitelist.png"
	property string whitelistCheck: { if (game.whitelist == false && game.item === "1") { showcaseScreen(); } }
    property string collectionName: game ? game.collections.get(0).name : ""
    property string collectionShortName: game ? game.collections.get(0).shortName : ""
    property bool iamsteam: game ? (collectionShortName == "steam") : false
    property bool canPlayVideo: settings.VideoPreview === "Yes"
    property real detailsOpacity: (settings.DetailsDefault === "Yes") ? 1 : 0
    property bool blurBG: settings.GameBlurBackground === "Yes"
    property var featuredCollection: listFavoritesWhitelists
    property var featuredItems: listWhitelists	
    property string publisherName: {
        if (game !== null && game.publisher !== null) {
            var str = game.publisher;
            var result = str.split(" ");
            return result[0]
        } else {
            return ""
        }
    } 
					
    ListPublisher { id: publisherCollection; publisher: game && game.publisher ? game.publisher : ""; max: 10 }
    ListGenre { id: genreCollection; genre: game ? game.genreList[0] : ""; max: 10 }

    // Combine the video and the screenshot arrays into one
    function mediaArray() {
        let mediaList = [];
        if (game && game.assets.video)
            game.assets.videoList.forEach(v => mediaList.push(v));

        if (game) {
            game.assets.screenshotList.forEach(v => mediaList.push(v));
            game.assets.backgroundList.forEach(v => mediaList.push(v));
        }

        return mediaList;
    }

    // Reset the screen to default state
    function reset() {
        content.currentIndex = 0;
        menu.currentIndex = 0;
        media.savedIndex = 0;
        screenshot.opacity = 1;
        mediaScreen.opacity = 0;
        toggleVideo(true);
    }

    // Show/hide the details overlay
    function showDetails() {
        if (detailsOpacity === 1) {
            toggleVideo(true);
            detailsOpacity = 0;
        }
        else {
            detailsOpacity = 1;
            toggleVideo(false);
        }
    }

    // Show/hide the media view
    function showMedia(index) {
        sfxAccept.play();
        mediaScreen.mediaIndex = index;
        mediaScreen.focus = true;
        mediaScreen.opacity = 1;
    }

    function closeMedia() {
        sfxBack.play();
        mediaScreen.opacity = 0;
        content.focus = true;
        currentHelpbarModel = gameviewHelpModel;
    }

    onGameChanged: reset();

    anchors.fill: parent

    GridSpacer {
    id: fakebox
        
        width: vpx(100); height: vpx(100)
    }

    // Video
    // Show/hide the video
    function toggleVideo(toggle) {
      if (!toggle)
      {
        // Turn off video
        screenshot.opacity = 1;
        stopvideo.restart();
      } else {
        stopvideo.stop();
        // Turn on video
        if (canPlayVideo)
            videoDelay.restart();
      }
    }

    // Timer to show the video
    Timer {
    id: videoDelay

        interval: 1000
        onTriggered: {
            if (game && game.assets.videos.length && canPlayVideo) {
                videoPreviewLoader.sourceComponent = videoPreviewWrapper;
                fadescreenshot.restart();
            }
        }
    }

    // NOTE: Next fade out the bg so there is a smooth transition into the video
    Timer {
    id: fadescreenshot

        interval: 1000
        onTriggered: {
            screenshot.opacity = 0;
            if (blurBG)
                bgBlur.opacity = 0;
        }
    }

    Timer {
    id: stopvideo

        interval: 1000
        onTriggered: {
            videoPreviewLoader.sourceComponent = undefined;
            videoDelay.stop();
            fadescreenshot.stop();
        }
    }

    // NOTE: Video Preview
    Component {
    id: videoPreviewWrapper

        Video {
        id: videocomponent

            property bool videoExists: game ? game.assets.videos.length : false
            source: videoExists ? game.assets.videos[0] : ""
            anchors.fill: parent
            fillMode: VideoOutput.PreserveAspectCrop
            muted: settings.AllowVideoPreviewAudio === "No"
            loops: MediaPlayer.Infinite
            autoPlay: true
            //onPlaying: videocomponent.seek(5000)
        }

    }

    // Video
    Loader {
    id: videoPreviewLoader

        asynchronous: true
        anchors { fill: parent }
    }

    // Background
    Image {
    id: screenshot

        anchors.fill: parent
        asynchronous: true
        property int randoScreenshotNumber: {
            if (game && settings.GameRandomBackground === "Yes")
                return Math.floor(Math.random() * game.assets.screenshotList.length);
            else
                return 0;
        }
        property int randoFanartNumber: {
            if (game && settings.GameRandomBackground === "Yes")
                return Math.floor(Math.random() * game.assets.backgroundList.length);
            else
                return 0;
        }

        property var randoScreenshot: game ? game.assets.screenshotList[randoScreenshotNumber] : ""
        property var randoFanart: game ? game.assets.backgroundList[randoFanartNumber] : ""
        property var actualBackground: (settings.GameBackground === "Screenshot") ? randoScreenshot : Utils.fanArt(game) || randoFanart;
        source: actualBackground || ""
        fillMode: Image.PreserveAspectCrop
        smooth: true
        Behavior on opacity { NumberAnimation { duration: 500 } }
        visible: !blurBG
    }

    FastBlur {
        anchors.fill: screenshot
        source: screenshot
        radius: 64
        opacity: screenshot.opacity
        Behavior on opacity { NumberAnimation { duration: 500 } }
        visible: blurBG
    }

    // Scanlines
    Image {
    id: scanlines

        anchors.fill: parent
        source: "http://forbidden.gg/assets/media/theme/scanlines_v3.png"
        asynchronous: true
        opacity: 0.2
        visible: !iamsteam && (settings.ShowScanlines == "Yes")
    }

    // Clear logo
    Image {
    id: logo

        anchors { 
            top: parent.top; //topMargin: vpx(70)
            left: parent.left; leftMargin: vpx(70)
        }
        width: vpx(500)
        height: vpx(450) + header.height
        source: game ? Utils.logo(game) : ""
        fillMode: Image.PreserveAspectFit
        asynchronous: true
        opacity: (content.currentIndex !== 0 || detailsScreen.opacity !== 0) ? 0 : 1
        Behavior on opacity { NumberAnimation { duration: 200 } }
        z: (content.currentIndex == 0) ? 10 : -10
        visible: settings.GameLogo === "Show"
    }

    DropShadow {
    id: logoshadow

        anchors.fill: logo
        horizontalOffset: 0
        verticalOffset: 0
        radius: 8.0
        samples: 12
        color: "#000000"
        source: logo
        opacity: (content.currentIndex !== 0 || detailsScreen.opacity !== 0) ? 0 : 0.4
        Behavior on opacity { NumberAnimation { duration: 200 } }
        visible: settings.GameLogo === "Show"
    }

    // Platform title
    Text {
    id: gametitle
        
        text: game.title
        
        anchors {
            top:    logo.top;
            left:   logo.left;//    leftMargin: globalMargin
            right:  parent.right;
            bottom: logo.bottom
        }
        
        color: theme.text
        font.family: titleFont.name
        font.pixelSize: vpx(80)
        font.bold: true
        horizontalAlignment: Text.AlignHLeft
        verticalAlignment: Text.AlignVCenter
        elide: Text.ElideRight
        wrapMode: Text.WordWrap
        lineHeight: 0.8
        visible: logo.source === "" || settings.GameLogo === "Text only"
        opacity: (content.currentIndex !== 0 || detailsScreen.opacity !== 0) ? 0 : 1
    }

    // Gradient
    LinearGradient {
    id: bggradient

        width: parent.width
        height: parent.height/2
        start: Qt.point(0, 0)
        end: Qt.point(0, height)
        gradient: Gradient {
            GradientStop { position: 0.0; color: theme.gradientstart }
            GradientStop { position: 0.7; color: theme.gradientend }
        }
        y: (content.currentIndex == 0) ? height : -height
        Behavior on y { NumberAnimation { duration: 200 } }
    }

    Rectangle {
    id: overlay

        color: theme.gradientend
        anchors {
            left: parent.left; right: parent.right
            top: bggradient.bottom; bottom: parent.bottom
        }
    }

    

    // Details screen
    Item {
    id: detailsScreen
        
        anchors.fill: parent
        visible: opacity !== 0
        opacity: (content.currentIndex !== 0) ? 0 : detailsOpacity
        Behavior on opacity { NumberAnimation { duration: 200 } }
        
        Rectangle {
            anchors.fill: parent
            color: theme.main
            opacity: 0.7
        }

        Item {
        id: details 

            anchors { 
                top: parent.top; topMargin: vpx(100)
                left: parent.left; leftMargin: vpx(70)
                right: parent.right; rightMargin: vpx(70)
            }
            height: vpx(450) - header.height

            Image {
            id: boxart

                source: Utils.boxArt(game);
                //width: vpx(350)
                height: parent.height
                fillMode: Image.PreserveAspectFit
                asynchronous: true
                smooth: true
            }

            GameInfo {
            id: info

                anchors {
                    left: boxart.right; leftMargin: vpx(30)
                    top: parent.top; bottom: parent.bottom; right: parent.right
                }
            }
        }
    }

    // Header
    Item {
    id: header

        anchors {
            left: parent.left; 
            right: parent.right
        }
        height: vpx(75)

        // Platform logo
        Image {
        id: logobg

            anchors.fill: platformlogo
        source: if (game.tier === "0") return "http://forbidden.gg/assets/media/theme/gradient.png"
      else if (game.tier === "1") return "http://forbidden.gg/assets/media/theme/gradient1.png"
      else if (game.tier === "2") return "http://forbidden.gg/assets/media/theme/gradient2.png"
      else if (game.tier === "3") return "http://forbidden.gg/assets/media/theme/gradient3.png"	  
      else return "http://forbidden.gg/assets/media/theme/gradient.png"
            asynchronous: true
            visible: false
        }

        Image {
        id: platformlogo

            anchors {
                top: parent.top; topMargin: vpx(20)
                bottom: parent.bottom; bottomMargin: vpx(20)
                left: parent.left; leftMargin: globalMargin
            }
            fillMode: Image.PreserveAspectFit
            source: "http://forbidden.gg/assets/media/theme/collections/" + Utils.processPlatformName(game.collections.get(0).shortName) + ".png"
            sourceSize: Qt.size(width, height)
            smooth: true
            visible: false
            asynchronous: true           
        }

        OpacityMask {
            anchors.fill: logobg
            source: logobg
            maskSource: platformlogo
            
            // Mouse/touch functionality
            MouseArea {
                anchors.fill: parent
                hoverEnabled: settings.MouseHover == "Yes"
                onClicked: previousScreen();
            }
        }

        // Platform title
        Text {
        id: softwareplatformtitle
            
            text: game.collections.get(0).name
            
            anchors {
                top:    parent.top;
                left:   parent.left;    leftMargin: globalMargin
                right:  parent.right
                bottom: parent.bottom
            }
            
            color: theme.text
            font.family: titleFont.name
            font.pixelSize: vpx(30)
            font.bold: true
            horizontalAlignment: Text.AlignHLeft
            verticalAlignment: Text.AlignVCenter
            elide: Text.ElideRight
            visible: platformlogo.status == Image.Error

            // Mouse/touch functionality
            MouseArea {
                anchors.fill: parent
                hoverEnabled: settings.MouseHover == "Yes"
                onClicked: previousScreen();
            }
        }
        z: 10
    }


    // Game menu
    ObjectModel {
    id: menuModel

        Button { 
        id: button1 
					color: if (game.tier === "0") return theme.accent
      else if (game.tier === "1") return theme.accent1
      else if (game.tier === "2") return theme.accent2
      else if (game.tier === "3") return theme.accent3
      else return theme.accent
            text: game.item === "1" ? "Welcome" : "Play"
            height: parent.height
			opacity: (game.item === "1" && game.welcome == "") ? 0.25 : 1			
            selected: ListView.isCurrentItem && menu.focus
            onHighlighted: { menu.currentIndex = ObjectModel.index; content.currentIndex = 0; }
            onActivated: 
                if (selected) {
				
				if (game.item === "0") {
                    if (game.collections.get(0).name != "COMPLETE"){ sfxAccept.play(); launchGame(game); }
                    if (featuredItems.games.count <= 0 && game.collections.get(0).name == "COMPLETE"){ sfxAccept.play(); unlockScreen(); }
		            if (featuredItems.games.count >= 1 && game.collections.get(0).name == "COMPLETE"){ sfxAccept.play(); launchGame(game); }
				}
				if (game.item === "1" && game.welcome != undefined) {
                    sfxAccept.play(); welcomeScreen(game);
				}
					
                } else {
                    sfxNav.play();
                    menu.currentIndex = ObjectModel.index;
                }
        }

		Button { 
        id: button2
			color: if (game.tier === "0") return theme.accent
      else if (game.tier === "1") return theme.accent1
      else if (game.tier === "2") return theme.accent2
      else if (game.tier === "3") return theme.accent3
      else return theme.accent
            text: game.item === "1" ? "Signature" : "Source Code"
            icon: game.item === "1" ? "http://forbidden.gg/assets/media/theme/icon_signature.png" : "http://forbidden.gg/assets/media/theme/icon_github.svg"
            height: parent.height
			opacity: (game.item === "1" && game.tier === "1" || game.item === "0") ? 1 : 0.25	
            selected: ListView.isCurrentItem && menu.focus
            onHighlighted: { menu.currentIndex = ObjectModel.index; content.currentIndex = 0; }
            onActivated: 
                if (selected) {
					if (game.item === "0") { Qt.openUrlExternally(game.source); }
					if (game.item === "1" && game.tier === "1") { sfxAccept.play(); signatureScreen(game); }
				}
                else {
                    sfxNav.play(); 
                    menu.currentIndex = ObjectModel.index;
                }
        }
		
		Button { 
        id: button3
			color: if (game.tier === "0") return theme.accent
      else if (game.tier === "1") return theme.accent1
      else if (game.tier === "2") return theme.accent2
      else if (game.tier === "3") return theme.accent3
      else return theme.accent
			enabled: game.website == undefined ? false : true
            text: game.item === "0" ? "Website" : ""
            icon: "http://forbidden.gg/assets/media/theme/icon_www.png"
            height: parent.height
			opacity: (game.website == undefined || game.website == "") ? 0.25 : 1
			selected: ListView.isCurrentItem && menu.focus
            onHighlighted: { menu.currentIndex = ObjectModel.index; content.currentIndex = 0; }
            onActivated: 
                if (selected) 
                    Qt.openUrlExternally(game.website);
                else {
                    sfxNav.play(); 
                    menu.currentIndex = ObjectModel.index;
                }
        }

	    Button { 
        id: button4
			color: if (game.tier === "0") return theme.accent
      else if (game.tier === "1") return theme.accent1
      else if (game.tier === "2") return theme.accent2
      else if (game.tier === "3") return theme.accent3
      else return theme.accent
  			// enabled: game.item === "1" ? true : false
			opacity: game.item === "1" ? 1 : 0.25			
            text: game.item === "1" ? "Vanity Card" : "Launch Options"
            icon: game.item === "1" ? "http://forbidden.gg/assets/media/theme/icon_vanitycard.png" : "http://forbidden.gg/assets/media/theme/icon_launchoptions.png"
            height: parent.height
            selected: ListView.isCurrentItem && menu.focus
            onHighlighted: { menu.currentIndex = ObjectModel.index; content.currentIndex = 0; }
            onActivated:
                if (selected) {
					// if (game.item === "0") { launchScreen(game); }
					if (game.item === "1") { sfxAccept.play(); vanityScreen(game); }
				}
                else {
                    sfxNav.play(); 
                    menu.currentIndex = ObjectModel.index;
                }
        }
		
		Button { 
        id: button5
			color: if (game.tier === "0") return theme.accent
      else if (game.tier === "1") return theme.accent1
      else if (game.tier === "2") return theme.accent2
      else if (game.tier === "3") return theme.accent3
      else return theme.accent
			enabled: game.twitter == undefined ? false : true
            icon: "http://forbidden.gg/assets/media/theme/twitter.png"
			opacity: (game.twitter == undefined || game.twitter == "") ? 0.25 : 1
			visible: game.item === "1" ? true : false
            height: parent.height
            selected: ListView.isCurrentItem && menu.focus
            onHighlighted: { menu.currentIndex = ObjectModel.index; content.currentIndex = 0; }
            onActivated: 
                if (selected) 
                    Qt.openUrlExternally(game.twitter);
                else {
                    sfxNav.play(); 
                    menu.currentIndex = ObjectModel.index;
                }
        }

		Button { 
        id: button6
			color: if (game.tier === "0") return theme.accent
      else if (game.tier === "1") return theme.accent1
      else if (game.tier === "2") return theme.accent2
      else if (game.tier === "3") return theme.accent3
      else return theme.accent
			enabled: game.facebook == undefined ? false : true
            icon: "http://forbidden.gg/assets/media/theme/facebook.png"
			opacity: (game.facebook == undefined || game.facebook == "") ? 0.25 : 1
			visible: game.item === "1" ? true : false
            height: parent.height
            selected: ListView.isCurrentItem && menu.focus
            onHighlighted: { menu.currentIndex = ObjectModel.index; content.currentIndex = 0; }
            onActivated: 
                if (selected) 
                    Qt.openUrlExternally(game.facebook);
                else {
                    sfxNav.play(); 
                    menu.currentIndex = ObjectModel.index;
                }
        }

		Button { 
        id: button7
			color: if (game.tier === "0") return theme.accent
      else if (game.tier === "1") return theme.accent1
      else if (game.tier === "2") return theme.accent2
      else if (game.tier === "3") return theme.accent3
      else return theme.accent
			enabled: game.instagram == undefined ? false : true
            icon: "http://forbidden.gg/assets/media/theme/instagram.png"
			opacity: (game.instagram == undefined || game.instagram == "") ? 0.25 : 1
			visible: game.item === "1" ? true : false
            height: parent.height
            selected: ListView.isCurrentItem && menu.focus
            onHighlighted: { menu.currentIndex = ObjectModel.index; content.currentIndex = 0; }
            onActivated: 
                if (selected) 
                    Qt.openUrlExternally(game.instagram);
                else {
                    sfxNav.play(); 
                    menu.currentIndex = ObjectModel.index;
                }
        }

		Button {
        id: button8
			color: if (game.tier === "0") return theme.accent
      else if (game.tier === "1") return theme.accent1
      else if (game.tier === "2") return theme.accent2
      else if (game.tier === "3") return theme.accent3
      else return theme.accent
			enabled: game.snapchat == undefined ? false : true
            icon: "http://forbidden.gg/assets/media/theme/snapchat.png"
			opacity: (game.snapchat == undefined || game.snapchat == "") ? 0.25 : 1
			visible: game.item === "1" ? true : false
            height: parent.height
            selected: ListView.isCurrentItem && menu.focus
            onHighlighted: { menu.currentIndex = ObjectModel.index; content.currentIndex = 0; }
            onActivated: 
                if (selected) 
                    Qt.openUrlExternally(game.snapchat);
                else {
                    sfxNav.play(); 
                    menu.currentIndex = ObjectModel.index;
                }
        }

		Button {
        id: button9
			color: if (game.tier === "0") return theme.accent
      else if (game.tier === "1") return theme.accent1
      else if (game.tier === "2") return theme.accent2
      else if (game.tier === "3") return theme.accent3
      else return theme.accent
			enabled: game.pinterest == undefined ? false : true
            icon: "http://forbidden.gg/assets/media/theme/pinterest.png"
			opacity: (game.pinterest == undefined || game.pinterest == "") ? 0.25 : 1
			visible: game.item === "1" ? true : false
            height: parent.height
            selected: ListView.isCurrentItem && menu.focus
            onHighlighted: { menu.currentIndex = ObjectModel.index; content.currentIndex = 0; }
            onActivated: 
                if (selected) 
                    Qt.openUrlExternally(game.pinterest);
                else {
                    sfxNav.play(); 
                    menu.currentIndex = ObjectModel.index;
                }
        }
        
		Button {
        id: button10
			color: if (game.tier === "0") return theme.accent
      else if (game.tier === "1") return theme.accent1
      else if (game.tier === "2") return theme.accent2
      else if (game.tier === "3") return theme.accent3
      else return theme.accent
			enabled: game.youtube == undefined ? false : true
            icon: "http://forbidden.gg/assets/media/theme/youtube.png"
			opacity: (game.youtube == undefined || game.youtube == "") ? 0.25 : 1
			visible: game.item === "1" ? true : false
            height: parent.height
            selected: ListView.isCurrentItem && menu.focus
            onHighlighted: { menu.currentIndex = ObjectModel.index; content.currentIndex = 0; }
            onActivated: 
                if (selected) 
                    Qt.openUrlExternally(game.youtube);
                else {
                    sfxNav.play(); 
                    menu.currentIndex = ObjectModel.index;
                }
        }		
		
		Button {
        id: button11
						color: if (game.tier === "0") return theme.accent
      else if (game.tier === "1") return theme.accent1
      else if (game.tier === "2") return theme.accent2
      else if (game.tier === "3") return theme.accent3
      else return theme.accent
			enabled: game.tiktok == undefined ? false : true
            icon: "http://forbidden.gg/assets/media/theme/tiktok.png"
			opacity: (game.tiktok == undefined || game.tiktok == "") ? 0.25 : 1
			visible: game.item === "1" ? true : false
            height: parent.height
            selected: ListView.isCurrentItem && menu.focus
            onHighlighted: { menu.currentIndex = ObjectModel.index; content.currentIndex = 0; }
            onActivated: 
                if (selected) 
                    Qt.openUrlExternally(game.tiktok);
                else {
                    sfxNav.play(); 
                    menu.currentIndex = ObjectModel.index;
                }
        }	
		
		Button {
        id: button12
					color: if (game.tier === "0") return theme.accent
      else if (game.tier === "1") return theme.accent1
      else if (game.tier === "2") return theme.accent2
      else if (game.tier === "3") return theme.accent3
      else return theme.accent
			enabled: game.discord == undefined ? false : true
            icon: "http://forbidden.gg/assets/media/theme/discord.png"
			opacity: (game.discord == undefined || game.discord == "") ? 0.25 : 1
			visible: game.item === "1" ? true : false
            height: parent.height
            selected: ListView.isCurrentItem && menu.focus
            onHighlighted: { menu.currentIndex = ObjectModel.index; content.currentIndex = 0; }
            onActivated: 
                if (selected) 
                    Qt.openUrlExternally(game.discord);
                else {
                    sfxNav.play(); 
                    menu.currentIndex = ObjectModel.index;
                }
        }

		Button {
        id: button13
					color: if (game.tier === "0") return theme.accent
      else if (game.tier === "1") return theme.accent1
      else if (game.tier === "2") return theme.accent2
      else if (game.tier === "3") return theme.accent3
      else return theme.accent
			enabled: game.twitch == undefined ? false : true
            icon: "http://forbidden.gg/assets/media/theme/twitch.png"
			opacity: (game.twitch == undefined || game.twitch == "") ? 0.25 : 1
			visible: game.item === "1" ? true : false
            height: parent.height
            selected: ListView.isCurrentItem && menu.focus
            onHighlighted: { menu.currentIndex = ObjectModel.index; content.currentIndex = 0; }
            onActivated: 
                if (selected) 
                    Qt.openUrlExternally(game.twitch);
                else {
                    sfxNav.play(); 
                    menu.currentIndex = ObjectModel.index;
                }
        }
		
		Button { 
        id: button14 

            property string buttonText: game && game.favorite ? "Unfavorite" : "Add favorite"
            //text: buttonText
						color: if (game.tier === "0") return theme.accent
      else if (game.tier === "1") return theme.accent1
      else if (game.tier === "2") return theme.accent2
      else if (game.tier === "3") return theme.accent3
      else return theme.accent
            icon: favIcon
            height: parent.height
			visible: game.item === "1" ? true : false
            selected: ListView.isCurrentItem && menu.focus
            onHighlighted: { menu.currentIndex = ObjectModel.index; content.currentIndex = 0; }
            onActivated: 
                if (selected) {
                    sfxToggle.play();
                    game.favorite = !game.favorite;
                } else {
                    sfxNav.play();
                    menu.currentIndex = ObjectModel.index;
                }
        }
		
    
    
    //		Button { 
    //  id: button15
    //
    //     property string buttonText: game && game.whitelist ? "Unwhitelist" : "Add whitelist"
    //     //text: buttonText
    //     icon: whitelistIcon
    //     height: parent.height
	//	visible: game.item === "1" ? true : false
    //     selected: ListView.isCurrentItem && menu.focus
    //     onHighlighted: { menu.currentIndex = ObjectModel.index; content.currentIndex = 0; }
    //     onActivated: 
    //         if (selected) {
    //             sfxToggle.play();
    //             game.whitelist = !game.whitelist;
    //         } else {
    //             sfxNav.play();
    //             menu.currentIndex = ObjectModel.index;
    //         }
    // }
		
    }

    // Full list
    ObjectModel {
    id: extrasModel

        // Game menu
        ListView {
        id: menu

            property bool selected: parent.focus
            focus: selected
            width: parent.width
            height: vpx(50)
            model: menuModel
            orientation: ListView.Horizontal
            spacing: vpx(10)
            keyNavigationWraps: true
            Keys.onLeftPressed: { sfxNav.play(); decrementCurrentIndex() }
            Keys.onRightPressed: { sfxNav.play(); incrementCurrentIndex() }
        }

        HorizontalCollection {
        id: media

            width: root.width - vpx(70) - globalMargin
            height: ((root.width - globalMargin * 2) / 6.0) + vpx(60)
			title: if (game.tier === "0") return "Media"
      else if (game.tier === "1") return "Signature Vault"
      else if (game.tier === "2") return "Multimedia Vault"
      else if (game.tier === "3") return "Artwork Vault"  
      else return "Media"	  
            model: game ? mediaArray() : []
            delegate: MediaItem {
            id: mediadelegate

                width: (root.width - globalMargin * 2) / 6.0
                height: width
                selected: ListView.isCurrentItem && media.ListView.isCurrentItem
                mediaItem: modelData

                onHighlighted: {
                    sfxNav.play(); 
                    media.currentIndex = index;
                    content.currentIndex = media.ObjectModel.index;
                }

                onActivated: {
                if (selected)
                    showMedia(index);
                else
                {
                    sfxNav.play(); 
                    media.currentIndex = index;
                    content.currentIndex = media.ObjectModel.index;
                }
            }
            }
            
        }


        
    }

    ListView {
    id: content

        anchors {
            left: parent.left; leftMargin: vpx(70)
            right: parent.right
            top: parent.top; topMargin: header.height
            bottom: parent.bottom; bottomMargin: vpx(150)
        }
        model: extrasModel
        focus: true
        spacing: vpx(30)
        header: Item { height: vpx(450) }
        
        snapMode: ListView.SnapToItem
        highlightMoveDuration: 100
        displayMarginEnd: 150
        cacheBuffer: 250
        onCurrentIndexChanged: { 
            if (content.currentIndex === 0) {
                toggleVideo(true); 
            } else {
                toggleVideo(false);
            }
        }
        keyNavigationWraps: true
        Keys.onUpPressed: { sfxNav.play(); decrementCurrentIndex() }
        Keys.onDownPressed: { sfxNav.play(); incrementCurrentIndex() }
    }

    MediaView {
    id: mediaScreen
        
        anchors.fill: parent
        Behavior on opacity { NumberAnimation { duration: 100 } }
        visible: opacity != 0

        mediaModel: mediaArray();
        mediaIndex: media.currentIndex != -1 ? media.currentIndex : 0
        onClose: closeMedia();
    }

    // Input handling
    Keys.onPressed: {
        // Back
        if (api.keys.isCancel(event) && !event.isAutoRepeat) {
            event.accepted = true;
            if (mediaScreen.visible)
                closeMedia();
            else
                previousScreen();
        }
    }

    // Helpbar buttons
    ListModel {
        id: gameviewHelpModel

        ListElement {
            name: "Back"
            button: "cancel"
        }
        ListElement {
            name: "Launch"
            button: "accept"
        }
	
    }
    
    onFocusChanged: { 
        if (focus) { 
            currentHelpbarModel = gameviewHelpModel;
            menu.focus = true;
            menu.currentIndex = 0; 
        } else {
            screenshot.opacity = 1;
            toggleVideo(false);
        }
    }

}
