var AccChat = psyc.Chat.extend({
	constructor : function (client, templates) {
		this.base(client, templates);
		this.DOMtoWIN = new Mapping();
		this.templates = templates;
		this.active = undefined;
		var self = this;
		this.accordion = new Accordion(document.getElementById("YakityChat"), 'a.toggler', 'div.chatwindow', {
			onActive: function(toggler, element){
				var chatwin = self.DOMtoWIN.get(toggler);
				if (chatwin && self.active != chatwin) {
					toggler.setStyle('color', '#41464D');
					
					self.active = chatwin;
					window.setTimeout((function(node) {
											chatwin.getMessagesNode().style.overflow="auto";
									  }), 700);
				} else if (!chatwin) {
					self.active = null;
				}

			},
			onBackground: function(toggler, element){
				toggler.setStyle('color', '#528CE0');
				var chatwin = self.DOMtoWIN.get(toggler);
				if (chatwin) chatwin.getMessagesNode().style.overflow="hidden";
			}
			//opacity : false
		});
	},
	msg : function(m) {
		var ret = this.base(m);	
		var win = this.getWindow(m.vars.get("_source"));
		win.getMessagesNode().scrollTop = win.getMessagesNode().scrollHeight;
		return ret;
	},
	removeWindow : function(uniform) {
		var win = this.getWindow(uniform);
		this.accordion.togglers.splice(win.pos, 1);
		this.accordion.elements.splice(win.pos, 1);
		document.getElementById("YakityChat").removeChild(win.header);
		document.getElementById("YakityChat").removeChild(win.container);
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

		var m = new psyc.Message("_request_history_delete", { _messages : messages, _target : this.client.uniform });
		this.client.send(m);

		this.base(uniform);
	},
	enterRoom : function(uniform) {
		this.base(uniform);
		this.accordion.display(this.getWindow(uniform).pos);
	},
	createWindow : function(uniform) {
		var win;
		var toggler = document.createElement("div");
                UTIL.addClass(toggler, "toggler");
		var togglemembers = document.createElement("div");
                UTIL.addClass(togglemembers, "toggleInfo");
		toggler.appendChild(togglemembers);
		
		var container = document.createElement("div");
		var header = document.createElement("div");

		if (uniform.is_person()) {
			win = new psyc.TemplatedWindow(this.templates, uniform);
			UTIL.addClass(win.getMessagesNode(), "privatechat");
                        UTIL.addClass(header, "private");
		} else {
			win = new psyc.RoomWindow(this.templates, uniform);
                        UTIL.addClass(header, "public");
			win.onenter = function() {
				UTIL.replaceClass(container, "left", "joined");
				UTIL.replaceClass(header, "left", "joined");
			};
			win.onleave = function() {
				UTIL.replaceClass(container, "joined", "left");
				UTIL.replaceClass(header, "joined", "left");
			};
			win.renderMember = function(uniform) {
				return profiles.getDisplayNode(uniform);
			};
			
			togglemembers.onclick = function() {
                                if (membersList.stlye.display = "none") {
                                        membersList.stlye.display = "block";	
                                } 
                                else {
                                        membersList.stlye.display = "none";	
                                }
                        };
			
			UTIL.addClass(win.getMessagesNode(), "roomchat");
		}
		UTIL.addClass(header, "header");
		this.DOMtoWIN.set(toggler, win);
		toggler.appendChild(profiles.getDisplayNode(uniform));

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
		        
                        var members = document.createElement("div");
                        UTIL.addClass(members, "membersList");
			members.appendChild(win.getMembersNode());
                        win.getMessagesNode().appendChild(members);
		}
		var pos = this.accordion.elements.length;
		document.getElementById("YakityChat").appendChild(header);
		document.getElementById("YakityChat").appendChild(container);
		this.accordion.addSection(toggler, container, pos);


		// fixes the flicker bug. dont know why mootools is f*cking with the styles
		// at all.
		container.style.overflow = "auto";

		win.header = header;
		win.container = container;
		win.pos = pos;

		if (!this.active) {
			this.active = win;
			this.accordion.display(pos);
		}

		return win;
	}
});
