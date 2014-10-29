/* -*- coding: utf-8-unix -*-
 *
 * Copyright (C) 2014 Osmo Salomaa
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 */

import QtQuick 2.0
import Sailfish.Silica 1.0
import "."

Page {
    id: page
    allowedOrientations: Orientation.All
    canNavigateForward: query.length > 0
    property var history: []
    property string query: ""
    SilicaListView {
        id: listView
        anchors.fill: parent
        // Prevent list items from stealing focus.
        currentIndex: -1
        delegate: ListItem {
            id: listItem
            contentHeight: Theme.itemSizeSmall
            menu: contextMenu
            ListView.onRemove: animateRemoval(listItem)
            ListItemLabel {
                anchors.leftMargin: listView.searchField.textLeftMargin
                color: listItem.highlighted ?
                    Theme.highlightColor : Theme.primaryColor
                height: Theme.itemSizeSmall
                text: model.place
            }
            ContextMenu {
                id: contextMenu
                MenuItem {
                    text: "Remove"
                    onClicked: {
                        py.call_sync("poor.app.history.remove_place", [model.place]);
                        listView.model.remove(index);
                    }
                }
            }
            onClicked: {
                page.query = model.place;
                app.pageStack.navigateForward();
            }
        }
        header: Column {
            height: pageHeader.height + usingButton.height + searchField.height;
            width: parent.width
            PageHeader {
                id: pageHeader
                title: "Find Place"
            }
            ValueButton {
                id: usingButton
                label: "Using"
                height: Theme.itemSizeSmall
                value: py.evaluate("poor.app.geocoder.name")
                width: parent.width
                onClicked: {
                    var dialog = app.pageStack.push("GeocoderPage.qml");
                    dialog.accepted.connect(function() {
                        usingButton.value = py.evaluate("poor.app.geocoder.name");
                    });
                }
            }
            SearchField {
                id: searchField
                placeholderText: "Address, landmark, etc."
                width: parent.width
                EnterKey.enabled: searchField.text.length > 0
                EnterKey.onClicked: app.pageStack.navigateForward();
                onTextChanged: {
                    page.query = searchField.text;
                    page.populate();
                }
            }
            Component.onCompleted: listView.searchField = searchField;
        }
        model: ListModel {}
        property var searchField
        VerticalScrollDecorator {}
    }
    onStatusChanged: {
        if (page.status == PageStatus.Activating) {
            page.history = py.evaluate("poor.app.history.places");
            page.populate();
        } else if (page.status == PageStatus.Active) {
            var resultPage = app.pageStack.nextPage();
            resultPage.populated = false;
        }
    }
    function populate() {
        // Load search history items from the Python backend.
        listView.model.clear();
        var query = listView.searchField.text.toLowerCase();
        var nstart = 0;
        for (var i = 0; i < page.history.length; i++) {
            var historyItem = page.history[i].toLowerCase();
            if (query.length > 0 && historyItem.indexOf(query) == 0) {
                listView.model.insert(nstart++, {"place": page.history[i]});
                if (listView.model.count >= 100) break;
            } else if (query == "" || historyItem.indexOf(query) > 0) {
                listView.model.append({"place": page.history[i]});
                if (listView.model.count >= 100) break;
            }
        }
        // XXX: Work around a bug causing the search field to disappear
        // if text has been typed, but there are no matches.
        if (listView.model.count == 0)
            listView.model.append({"place": listView.searchField.text});
    }
}
