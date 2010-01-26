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
var AccChat = yakity.Chat.extend({
	constructor : function (client, templates, target_id, input) {
		this.target_id = target_id;
		this.input = input;
		this.base(client, templates);
		this.DOMtoWIN = new Mapping();
		this.templates = templates;
		this.active = undefined;
		var self = this;
		this.accordion = new Accordion(document.getElementById(this.target_id), 'a.toggler', 'div.chatwindow', {
			onActive: function(toggler, element){
				var chatwin = self.DOMtoWIN.get(toggler);
				if (chatwin && self.active != chatwin) {
					toggler.setStyle('color', '#41464D');
					
					self.active = chatwin;
					chatwin.trigger("focus");
					window.setTimeout((function(node) {
											chatwin.getMessagesNode().scrollTop = chatwin.getMessagesNode().scrollHeight;
											chatwin.getMessagesNode().style.overflow="auto";
									  }), 700);
				} else if (!chatwin) {
					self.active = null;
				}

			},
			onBackground: function(toggler, element){
				toggler.setStyle('color', '#528CE0');
				var chatwin = self.DOMtoWIN.get(toggler);
				if (chatwin) {
					chatwin.trigger("blur");
					chatwin.getMessagesNode().style.overflow="hidden";
				}
			}
			//opacity : false
		});
	},
	removeWindow : function(uniform) {
		var win = this.getWindow(uniform);
		this.accordion.togglers.splice(win.pos, 1);
		this.accordion.elements.splice(win.pos, 1);
		document.getElementById(this.target_id).removeChild(win.header);
		document.getElementById(this.target_id).removeChild(win.container);
		this.DOMtoWIN.remove(win.header.firstChild);

		if (this.active == win) {
			if (win.pos < this.accordion.elements.length) {
				this.active = this.DOMtoWIN.get(this.accordion.togglers[win.pos]);
				this.accordion.display(win.pos, false);
			} else if (win.pos > 0) {
				this.active = this.DOMtoWIN.get(this.accordion.togglers[win.pos-1]);
				this.accordion.display(win.pos-1, false);
			}
		}

		var messages = win.getMessages();

		for (var i = 0; i < messages.length; i++) {
			var id = messages[i].id();

			if (id != undefined) {
				messages[i] = id;	
			} else { // we assume that this wont happen often
				messages.splice(i, 1);
				i--;
			}
		}

		this.client.sendmsg(this.client.uniform, "_request_history_delete", 0, { _messages : messages });
		this.base(uniform);
	},
	msg : function(p, m) {
		if (!p.vars.hasIndex("_context") || this.windows.hasIndex(p.source())) {
		    var messages = this.getWindow(p.source()).getMessagesNode();
		    var ret = this.base(p, m);	
		    messages.scrollTop = messages.scrollHeight;
		    return ret;
		}
	},
	enterRoom : function(uniform) {
		this.base(uniform);
		this.accordion.display(this.getWindow(uniform).pos);
	},
	createWindow : function(uniform) {
		var win;
		var toggler = document.createElement("a");
		UTIL.addClass(toggler, "toggler");
		var togglemembers = document.createElement("a");
		UTIL.addClass(togglemembers, "toggleInfo");
		toggler.appendChild(togglemembers);
		
		var container = document.createElement("div");
		var header = document.createElement("div");
		var members = document.createElement("div");

		if (uniform == this.client.uniform) {
			win = new yakity.TemplatedWindow(this.templates, uniform);
			toggler.appendChild(document.createTextNode("Status"));
			UTIL.addClass(header, "status");
			UTIL.addClass(container, "status");
		} else if (uniform.is_person()) {
			win = new yakity.TemplatedWindow(this.templates, uniform);
			UTIL.addClass(win.getMessagesNode(), "privatechat");
			UTIL.addClass(header, "private");
			UTIL.addClass(container, "private");
			toggler.appendChild(profiles.getDisplayNode(uniform));
		} else {
			win = new yakity.RoomWindow(this.templates, uniform);
			UTIL.addClass(header, "public");
			UTIL.addClass(container, "public");
			win.onenter = function() {
				UTIL.replaceClass(container, "left", "joined");
				UTIL.replaceClass(header, "left", "joined");
			};
			win.onleave = function() {
				UTIL.replaceClass(container, "joined", "left");
				UTIL.replaceClass(header, "joined", "left");
			};
			
			togglemembers.onclick = function() {
				if (members.style.display=="none") {
					members.style.display="block";	
				} else {
					members.style.display="none";	
				}
			};
			
			UTIL.addClass(win.getMessagesNode(), "roomchat");
			toggler.appendChild(profiles.getDisplayNode(uniform));
		}
		UTIL.addClass(header, "idle");
		UTIL.addClass(container, "idle");
		UTIL.addClass(header, "header");
		this.DOMtoWIN.set(toggler, win);

		if (uniform != this.client.uniform) { // not the status window
			var a;
			var chat = this;

			if (uniform.is_person()) {
				a = document.createElement("div");
				UTIL.addClass(a, "closeButton");
				a.onclick = function() {
					chat.removeWindow(uniform);
				};
				header.appendChild(a);
			} else {
				a = document.createElement("div");
				UTIL.addClass(a, "leaveButton");
				var b = document.createElement("div");
				UTIL.addClass(b, "closeButton");
				var c = document.createElement("div");
				UTIL.addClass(c, "enterButton");
				
				b.onclick = function() {
					chat.removeWindow(uniform);
				};
				a.onclick = function() {
					chat.leaveRoom(uniform);
				};
				c.onclick = function() {
					chat.enterRoom(uniform);
				};
				
				header.appendChild(b);
				header.appendChild(a);
				header.appendChild(c);
			}
		}

		header.appendChild(toggler);
		UTIL.addClass(container, "chatwindow");
		UTIL.addClass(win.getMessagesNode(), "messages");
		container.appendChild(win.getMessagesNode());

		if (uniform.is_room()) {
			UTIL.addClass(members, "membersList");
			members.appendChild(win.getMembersNode());
			win.getMessagesNode().appendChild(members);
		}

		var pos = this.accordion.elements.length;
		document.getElementById(this.target_id).appendChild(header);
		document.getElementById(this.target_id).appendChild(container);
		this.accordion.addSection(toggler, container, pos);


		// fixes the flicker bug. dont know why mootools is f*cking with the styles
		// at all.
		container.style.overflow = "auto";

		win.header = header;
		win.container = container;
		win.pos = pos;

		if (!this.active) {
			this.active = win;
			this.accordion.display(1);
			this.accordion.display(pos);
		}

		return win;
	}
});
