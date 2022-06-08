#include <stdint.h> // uint8_t
#include <stdbool.h> // global initializer
#include <stddef.h> //size_t
#include <string.h> //memcpy

#include "reliable.h"

#define MAX_PACKET_BYTES (16*1024)

bool lib_init = false;
double global_time = 100.0; 
struct reliable_config_t config;
struct reliable_endpoint_t *endpoint;

// Mandatory function skeletons
void test_transmit_packet_function(void *context, int index, uint16_t sequence, uint8_t *packet_data, int packet_bytes) {
	(void) context;
	(void) index;
	(void) sequence;
	(void) packet_data;
	(void) packet_bytes;
}

int test_process_packet_function(void *context, int index, uint16_t sequence, uint8_t *packet_data, int packet_bytes) {
	(void) context;
	(void) index;
	(void) sequence;
	(void) packet_data;
	(void) packet_bytes;
	return 1;
}
// End mandatory function skeletons


void initialize_library() {
	reliable_init();

	// Set up config 
	reliable_default_config(&config);
	config.index = 0;
	config.transmit_packet_function = &test_transmit_packet_function;
	config.process_packet_function = &test_process_packet_function;

	endpoint = reliable_endpoint_create(&config, global_time); 
	lib_init = true; 
}

int LLVMFuzzerTestOneInput(const uint8_t *data, size_t size) {
	int cast_size = (int) size; // Expected by library
	if (!lib_init) initialize_library(); 
	if (cast_size <= 0 || cast_size > MAX_PACKET_BYTES) return 0; // Handle assertion in receive packet that ensures non-zero message length

	// Expects non-const copy
	uint8_t buff[cast_size];
	memcpy(buff, data, cast_size);

	reliable_endpoint_receive_packet(endpoint, buff, cast_size);
	reliable_endpoint_update(endpoint, global_time); 
	reliable_endpoint_clear_acks(endpoint); 
	
	global_time += 0.1;
	return 0;
}
