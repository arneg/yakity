var Amnesty = {
    instances : new Mapping(),
    Instance : UTIL.EventSource.extend({
	constructor : function(iframe) {
	    this.base();
	    this.iframe = iframe;
	    Amnesty.instances.set(iframe, this);
	    console.log("window: %o", iframe.contentWindow);
	},
	trigger : function() {
	    //console.log("trigger: %o", arguments);
	    alert("EEK");
	    this.base.apply(this, arguments);
	}
    }),
    get_instance : function(win) {
	return Amnesty.instances.get(win);
    },
    has_instance : function(win) {
	//if (Amnesty.instances.hasIndex(win)) return true;
	////for (var i = 0; i < document.frames.length; i ++) {
	//}
	return Amnesty.instances.hasIndex(win);
    },
    init : function() {
	
	if (window.parent && window.parent.Amnesty && window.parent.Amnesty.n) {
	    Amnesty.n = window.parent.Amnesty.n;
	} else {
	    var iframe = document.createElement("iframe");
	    var url = window.location.href;
	    //iframe.src = "data:text/html;base64,PGh0bWw+PC9odG1sPg==";
	    //iframe.src = window.location.href.substring(0, window.location.href.length-window.location.search.length) + "?a";
	    iframe.height=600;
	    iframe.width="100%";
	    //document.body.bgcolor="black";
	    //iframe.contentWindow.parent = parent;
	    
	    while (document.body.firstChild) {
		var node = document.body.firstChild;
		document.body.removeChild(node);
		//iframe.contentWindow.document.body.appendChild(node);
	    }
	    document.body.appendChild(iframe);
	    iframe.src = window.location.href + "?a";
	    Amnesty.n = new Amnesty.Instance(iframe);
	}
    }
};
