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

function elink(name,fun,title) {
	var a = document.createElement("a");
	a.href = "javascript:void(null)";
	a.appendChild((typeof(name) == "string") ? document.createTextNode(name) : name);
	if (fun) a.onclick = fun;
	if (title) a.title = title;
	return a;
}
var AccChat = Yakity.Chat.extend({
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
					chatwin.trigger("focus", chatwin);
					chatwin.getMessagesNode().style.overflow="auto";
				} else if (!chatwin) {
					self.active = null;
				}

			},
			onBackground: function(toggler, element){
				toggler.setStyle('color', '#528CE0');
				var chatwin = self.DOMtoWIN.get(toggler);
				if (chatwin) {
					chatwin.trigger("blur", chatwin);
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

		var i;
		for (i = win.pos; this.accordion.from.hasOwnProperty(i+1); i++) {
		    this.accordion.from[i] = this.accordion.from[i+1];
		    this.accordion.to[i] = this.accordion.to[i+1];
		}
		delete this.accordion.from[i];
		delete this.accordion.to[i];

		for (i = 0; i < this.accordion.togglers.length; i++) {
		    this.DOMtoWIN.get(this.accordion.togglers[i]).pos = i;
		}

		document.getElementById(this.target_id).removeChild(win.header);
		document.getElementById(this.target_id).removeChild(win.container);
		this.DOMtoWIN.remove(win.header.firstChild);

		if (win.pos < this.accordion.previous) {
		    this.accordion.previous--;
		}

		if (this.active == win) {
		    	this.accordion.previous = -1;

			if (win.pos < this.accordion.elements.length) {
				this.accordion.display(win.pos, false);
				//this.active = this.DOMtoWIN.get(this.accordion.togglers[win.pos]);
			} else if (win.pos > 0) {
				this.accordion.display(win.pos-1, false);
				//this.active = this.DOMtoWIN.get(this.accordion.togglers[win.pos-1]);
			}
		}

		/*
		 * TODO: this is deactivated until the server message history is working again properly
		var messages = win.getMessages();

		for (i = 0; i < messages.length; i++) {
			var id = messages[i].id();

			if (id != undefined) {
				messages[i] = id;	
			} else { // we assume that this wont happen often
				messages.splice(i, 1);
				i--;
			}
		}

		this.client.sendmsg(this.client.uniform, "_request_history_delete", 0, { _messages : messages });
		*/
		this.base(uniform);
	},
	msg : function(p, m) {
		if (!p.vars.hasIndex("_context") || this.windows.hasIndex(p.source())) {
		    var messages = this.getWindow(p.source()).getMessagesNode();
		    var scrolldown = (messages.scrollTop == (messages.scrollHeight - messages.offsetHeight));
		    var ret = this.base(p, m);	
		    if (scrolldown) messages.scrollTop = messages.scrollHeight - messages.offsetHeight;
		    return ret;
		}
	},
	enterRoom : function(uniform, history) {
		var win = this.getWindow(uniform);
		this.accordion.display(win.pos);
		if (!win.left) return;
		this.base(uniform, history);
	},
	createWindow : function(uniform) {
		var win;
		var toggler = document.createElement("a");
		toggler.title = "toggle pane";
		UTIL.addClass(toggler, "toggler");
		
		var container = document.createElement("div");
		var header = document.createElement("div");
		var infoicon = document.createElement("div");
		UTIL.addClass(infoicon, "infoIcon");
		toggler.appendChild(infoicon);


		if (uniform == this.client.uniform) {
			win = new Yakity.TemplatedWindow(this.templates, uniform);
			toggler.appendChild(document.createTextNode("Welcome to YakityChat"));
			UTIL.addClass(header, "status");
			UTIL.addClass(container, "status");
		} else if (uniform.is_person()) {
			win = new Yakity.TemplatedWindow(this.templates, uniform);
			UTIL.addClass(win.getMessagesNode(), "privatechat");
			UTIL.addClass(header, "private");
			UTIL.addClass(container, "private");
			toggler.appendChild(profiles.getDisplayNode(uniform));
		} else {
			win = new Yakity.RoomWindow(this.templates, uniform);
			UTIL.addClass(header, "public");
			UTIL.addClass(container, "public");
			win.register_event("onenter", this, function() {
				UTIL.replaceClass(container, "left", "joined");
				UTIL.replaceClass(header, "left", "joined");
			});
			win.register_event("onleave", this, function() {
				UTIL.replaceClass(container, "joined", "left");
				UTIL.replaceClass(header, "joined", "left");
			});
			
			var members = document.createElement("div");
			UTIL.addClass(members, "membersList");
			var membersc = document.createElement("div");
			UTIL.addClass(membersc, "membersContainer");
			var togglemembers = document.createElement("a");
			UTIL.addClass(togglemembers, "focus");
			UTIL.addClass(togglemembers, "membersToggler");
			togglemembers.title = "Toggle members list";
			togglemembers.appendChild(document.createElement("div"));
			UTIL.addClass(togglemembers.firstChild, "Button");

			members.appendChild(win.getMembersNode());
			membersc.appendChild(togglemembers);
			membersc.appendChild(members);
			win.getMessagesNode().appendChild(membersc);
			togglemembers.href = "javascript:void(null)";
			togglemembers.onclick = function() {
				if (members.style.display=="none") {
					members.style.display="block";	
					UTIL.replaceClass(togglemembers, "blur", "focus");
				} else {
					members.style.display="none";	
					UTIL.replaceClass(togglemembers, "focus", "blur");
				}
			};
			
			UTIL.addClass(win.getMessagesNode(), "roomchat");
			toggler.appendChild(profiles.getDisplayNode(uniform));
		}
		win.register_event("new_message", this, function(win, p, node) {
			if (this.active != win) {
				UTIL.addClass(header, "unread");
				UTIL.addClass(container, "unread");
			}
		});
		win.register_event("focus", this, function(win) {
			UTIL.removeClass(header, "unread");
			UTIL.removeClass(container, "unread");
		});

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
				// We need some dictionary here.
				a = elink(a, function() {
					chat.removeWindow(uniform);
				}, "close window");
				
				header.appendChild(a);
			} else {
				a = document.createElement("div");
				UTIL.addClass(a, "leaveButton");
				var b = document.createElement("div");
				UTIL.addClass(b, "closeButton");
				var c = document.createElement("div");
				UTIL.addClass(c, "enterButton");
				
				b = elink(b, function() {
					chat.removeWindow(uniform);
				}, "close window");
				a = elink(a, function() {
					chat.leaveRoom(uniform);
				}, "leave room");
				c = elink(c, function() {
					chat.enterRoom(uniform);
				}, "enter room");
				
				header.appendChild(b);
				header.appendChild(a);
				header.appendChild(c);
			}
		}

		header.appendChild(toggler);
		UTIL.addClass(container, "chatwindow");
		UTIL.addClass(win.getMessagesNode(), "messages");
		container.appendChild(win.getMessagesNode());


		var pos = this.accordion.elements.length;
		document.getElementById(this.target_id).appendChild(header);
		document.getElementById(this.target_id).appendChild(container);
		this.accordion.addSection(toggler, container, pos);


		// fixes the flicker bug. dont know why mootools is f*cking with the styles
		// at all.
		if (UTIL.App.is_firefox) {
		    container.style.overflow = "auto";
		}

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
