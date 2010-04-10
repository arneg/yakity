#ifdef MEASURE_THROUGHPUT
private int obytes = 0, ibytes = 0;

void measure(int bytes) {
    obytes += bytes;
}

void inbuf(int bytes) {
    ibytes += bytes;
}


float measure_bytes(function print, void|int time) {
    int old_obytes = obytes, old_ibytes = ibytes, t = gethrtime();

    void _cb() {
	float lval = 1E-6*(gethrtime()-t);
	print((obytes-old_obytes)/lval, (ibytes-old_ibytes)/lval);
    };

    call_out(_cb, time||1);
}

#endif

