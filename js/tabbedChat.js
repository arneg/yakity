/*
Copyright (C) 2008-2009  Arne Goedeke
Copyright (C) 2008-2009  Matt Hardy

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
version 2 as published by the Free Software Foundation.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program; if not, write to the Free Software
Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.
*/
psyc.TabbedRoom = function(templates, id) {
	psyc.RoomWindow.call(this, templates, id);
	this.li = document.createElement("li");
	// hide all by default
	this.container = document.createElement("div");
	this.li.className = "chatheader roomchat header_hidden";
	this.container.className = "chatwindow roomchat window_hidden";
	this.container.appendChild(this.messages);
	this.container.appendChild(this.getMembersNode());
	this.active = null;
};
psyc.TabbedRoom.prototype = new psyc.RoomWindow();
psyc.TabbedRoom.prototype.constructor = psyc.TabbedRoom;
psyc.TabbedRoom.prototype.hide = function() {
	this.li.className = this.li.className.replace("header_shown", "header_hidden");
	this.container.className = this.container.className.replace("window_shown", "window_hidden");
};
psyc.TabbedRoom.prototype.show = function() {
	this.li.className = this.li.className.replace("header_hidden", "header_shown");
	this.container.className = this.container.className.replace("window_hidden", "window_shown");
};
psyc.TabbedPrivate = function(templates, id) {
	psyc.TemplatedWindow.call(this, templates, id);
	this.li = document.createElement("li");
	// hide all by default
	this.container = document.createElement("div");
	this.li.className = "chatheader privatechat header_hidden";
	this.container.className = "chatwindow privatechat window_hidden";
	this.container.appendChild(this.messages);
	this.active = null;
};
psyc.TabbedPrivate.prototype = new psyc.TemplatedWindow();
psyc.TabbedPrivate.prototype.constructor = psyc.TabbedPrivate;
psyc.TabbedPrivate.prototype.hide = function() {
	this.li.className = this.li.className.replace(/header_shown/g, "header_hidden");
	this.container.className = this.container.className.replace(/window_shown/g, "window_hidden");
};
psyc.TabbedPrivate.prototype.show = function() {
	this.li.className = this.li.className.replace(/header_hidden/g, "header_shown");
	this.container.className = this.container.className.replace(/window_hidden/g, "window_shown");
};
psyc.TabbedChat = psyc.Chat.extend({
	constructor : function(client, templates) {
		psyc.Chat.call(this, client);

		if (!client) return;

		this.templates = templates;

		this.ul = document.createElement("ul");
		this.ul.className = "chatheader";
		this.div = document.createElement("div");
		this.div.className = "chatcontainer";
	},
	/**
	 * Opens a new tab inside the chat. It will be used to display messages coming from the entity specified by uniform. Use this for cases like private messages where the conversation is not initiated by a handshake (in contrary to group chats).
	 * @param {Object} uniform Uniform to use this ChatTab for.
	 */
	createWindow : function(uniform) {
		var win;

		if (uniform.is_room()) {
			win = new psyc.TabbedRoom(this.templates, uniform);
		} else {
			win = new psyc.TabbedPrivate(this.templates, uniform);
		}

		if (!this.active) {
			this.active = win;
			win.show();
		}

		var self = this;
		win.li.onclick = function(event) {
			self.activateWindow(uniform);
		};

		this.ul.appendChild(win.li);
		this.div.appendChild(win.container);

		return win;
	},
	activateWindow : function(uniform) {
		var win = this.getWindow(uniform);

		//if (this.active == win) return;
		if (this.active) {
			this.active.hide();
		}
		this.active = win;
		win.show();
	}
});
