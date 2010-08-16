var isjail = false;
function make_iframe() {
    if (parent && !parent.isjail) {
	isjail = true;
	var iframe = document.createElement("iframe");
	var url = window.location.href;
	//iframe.src = "data:text/html;base64,PGh0bWw+PC9odG1sPg==";
	//iframe.src = window.location.href.substring(0, window.location.href.length-window.location.search.length) + "?a";
	iframe.height="100%";
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

    }
}
