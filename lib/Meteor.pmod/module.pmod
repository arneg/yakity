#ifdef MEASURE_THROUGHPUT
int obytes = 0;

void measure(int bytes) {
    obytes += bytes;
}

float measure_bytes(void|int time) {
    int old_bytes = obytes;
    int t = gethrtime();

    sleep(time || 1);

    return ((obytes-old_bytes)/(1E-6*(gethrtime()-t)));	
}

#endif

