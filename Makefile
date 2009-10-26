ifdef V
	VERSION = $(V)
else
	VERSION = local
endif

NAME = YakityChat-$(VERSION)

release:
	mkdir $(NAME)
	cp -r lib $(NAME)
	cp README $(NAME)
	cp gpl-2.0.txt $(NAME)
	cp COPYING $(NAME)
	mkdir $(NAME)/modules
	cp modules/yakitychat.pike $(NAME)/modules/
	mkdir $(NAME)/htdocs
	cp -r js $(NAME)/htdocs/
	mkdir $(NAME)/htdocs/ppp-js/
	cp ppp/js/*.js $(NAME)/htdocs/ppp-js/
	rm $(NAME)/htdocs/ppp-js/time.js
	rm $(NAME)/htdocs/ppp-js/psyc.js
	cp -r ppp/lib/Serialization.pmod $(NAME)/lib/
	cp ppp-bsd ppp/lib/Serialization.pmod/LICENSE
	mkdir $(NAME)/lib/MMP.pmod
	cp mmp-module.pmod	$(NAME)/lib/MMP.pmod/module.pmod
	echo "class Uniform {" >>$(NAME)/lib/MMP.pmod/module.pmod
	cat ppp/lib/MMP.pmod/Uniform.pike >> $(NAME)/lib/MMP.pmod/module.pmod
	echo "}" >>$(NAME)/lib/MMP.pmod/module.pmod
	mkdir $(NAME)/lib/MMP.pmod/Utils.pmod/
	cp ppp/lib/MMP.pmod/Utils.pmod/module.pmod $(NAME)/lib/MMP.pmod/Utils.pmod/
	cp ppp-bsd ppp/lib/MMP.pmod/LICENSE
	cp htdocs/index.html $(NAME)/htdocs/
	cp -r htdocs/images/ $(NAME)/htdocs/
	cp htdocs/mootools-1.2.3-core-nc.js $(NAME)/htdocs/
	cp htdocs/mootools-1-1.2.3.1-more.js $(NAME)/htdocs/
	tar cfzvp $(NAME).tar.gz $(NAME)
