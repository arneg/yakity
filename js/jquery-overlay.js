(function($, undefined) {
    $.widget("ui.oslider", {
	options : {
	    effects : [ $().show, $().hide ]
	},
	_create : function() {
	    this.oslider = $("<div></div>").addClass("ui-widget");
	    this.hidden = false;
	    this.element
		.css({
		    position : "absolute",
		    bottom : "0px",
		    right : "17px"
		})
		.find(".oslider-header")
		    .addClass("ui-widget-header")
		    .addClass("ui-corner-bl ui-corner-tl ui-corner-tr")
		    .css("padding", "5px")
		    .bind("click", UTIL.make_method(this, this.toggle));
	    this.element.find(".oslider-content")
		.addClass("ui-widget-content")
		.addClass("ui-corner-tl")
		.css("margin-top", "2px")
		.css("border-bottom", "0px")
		.css("padding", "5px");

	    this.element.appendTo(this.oslider);
	    this.oslider.appendTo(document.body);
	},
	_init : function() {
	    this.hide();
	},
	toggle : function() {
	    // we will be the new jquery!
	    (this.hidden ? this.show : this.hide).apply(this);
	},
	hide : function() {
	    console.log("%o", this.element.find(".oslider-content"));
	    this.options.effects[1].apply(this.element.find(".oslider-content"), arguments);
	    this.hidden = true;
	},
	show : function() {
	    this.hidden = false;
	    this.options.effects[0].apply(this.element.find(".oslider-content"), arguments);
	}
    });
})(jQuery);
<<<<<<< HEAD
=======
(function($, undefined) {
    $.widget("ui.ychatbox", {
	options : {
	    //maxMessages : 12
	    templates : new mmp.Vars({
		_notice_enter : "[_supplicant] enters [_source].",
		_notice_leave : "[_supplicant] leaves [_source].",
		_message_public : "[_timestamp] [_source_relay] [data]",
		_message_private : "[_timestamp] [_source_relay] [data]",
		_echo_message_public : "[_timestamp] [_source_relay] [data]",
		_echo_message_private : "[_timestamp] [_source_relay] [data]"
	    })
	},
	_create : function() {
	    this.displayedMessages = 0;
	    this.element.css("overflow", "auto");
	},
	add_message : function(packet) {
	    $(Yakity.funky_text(packet, this.options.templates)).appendTo(this.element);
	    /*
	    if (++this.displayedMessages > this.options.maxMessages) {
		this.element.removeChild(this.element.firstChild);
	    }
	    */
	}
    });
})(jQuery);
>>>>>>> el/foo
