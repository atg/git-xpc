static void do_commit(xpc_connection_t conn, xpc_object_t msg, const char* path) {
  xpc_connection_send_message(conn, msg);
}