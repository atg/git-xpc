//  Created by Alex Gordon on 13/03/2014.

static void get_status(xpc_connection_t conn, xpc_object_t msg, const char* path) {
    GTRepository *repo = [GTRepository repositoryWithURL:[NSURL fileURLWithPath:[NSString stringWithUTF8String:path]] error:nil];
    
    if (repo) {
        [repo choc_enumerateFileStatusUsingBlock:^(NSString *fileName, GTRepositoryStatusFlags status, BOOL *stop) {
            xpc_dictionary_set_uint64(msg, [fileName UTF8String], status);
        }];
    }
    
    xpc_connection_send_message(conn, msg);
}


/*static void get_diff(xpc_connection_t conn, xpc_object_t msg, const char* repopath, const char* filepath, const char* buf, size_t buflen) {
    
    git_repository* repo = NULL;
    git_repository_open(&repo, repopath);
    if (repo) {
        git_object *obj = NULL;
        git_tree_entry *subentry = NULL;
        git_blob *old_blob = NULL;
        
        // Each line is an item in the array
        xpc_object_t infos = xpc_array_create(NULL, 0);
        xpc_dictionary_set_value(msg, "lines", infos);
        
        // Load our tree
        int err = git_revparse_single(&obj, repo, "HEAD^{tree}");
        if (err) { NSLog(@"Error 1: %d", err); goto fail; }
        
        git_tree *tree = (git_tree *)obj;
        
        // Look up the tree entry
        err = git_tree_entry_bypath(&subentry, tree, filepath);
        if (err) { NSLog(@"Error 2: %d", err); goto fail; }
        
        // Convert the tree entry into an object id
        const git_oid *oid = git_tree_entry_id(subentry);
        
        // Convert the object to a blob
        err = git_blob_lookup(&old_blob, repo, oid);
        if (err) { NSLog(@"Error 3: %d", err); goto fail; }
        
        NSLog(@"blob size: %ld", git_blob_rawsize(old_blob));
        
        // Diff
        err = git_diff_blob_to_buffer(NULL, filepath, buf, buflen, filepath, NULL,
                                NULL, NULL, diff_line_callback, (__bridge void*)msg);
        
        if (err) { NSLog(@"Error 4: %d", err); goto fail; }
        
    fail:
        git_tree_entry_free(subentry); // caller has to free this one
        git_object_free(obj);
        git_repository_free(repo);
    }
    
    xpc_connection_send_message(conn, msg);
}

static void do_commit(xpc_connection_t conn, xpc_object_t msg, const char* path) {
    // ???
    xpc_connection_send_message(conn, msg);
}*/

static void handle_message(xpc_connection_t peer, xpc_object_t event) {
    const char* name = xpc_dictionary_get_string(event, "type"); assert(name != NULL);
    const char* repopath = xpc_dictionary_get_string(event, "repopath"); assert(repopath != NULL);
    xpc_connection_t reply_conn = xpc_dictionary_get_remote_connection(event); assert(reply_conn != NULL);
    xpc_object_t reply_msg = xpc_dictionary_create_reply(event); assert(reply_msg != NULL);
    
    NSLog(@"%@", reply_msg);
    
    if (0 == strcmp("status", name)) {
        get_status(reply_conn, reply_msg, repopath);
    }/*
    else if (0 == strcmp("diff", name)) {
        const char* filepath = xpc_dictionary_get_string(event, "filepath"); assert(filepath != NULL);
        
        char buf[] = "hello world";
        size_t buflen = sizeof(buf);
        
        get_diff(reply_conn, reply_msg, repopath, filepath, buf, buflen);
    }
    else if (0 == strcmp("commit", name)) {
        do_commit(reply_conn, reply_msg, repopath);
    }*/
    else {
        assert(0 && "Unknown command");
    }
}





// --- Ignore this stuff. ---

static void gitxpc_peer_event_handler(xpc_connection_t peer, xpc_object_t event)  {
	xpc_type_t type = xpc_get_type(event);
	if (type == XPC_TYPE_ERROR) {
		if (event == XPC_ERROR_CONNECTION_INVALID) {
			// The client process on the other end of the connection has either
			// crashed or cancelled the connection. After receiving this error,
			// the connection is in an invalid state, and you do not need to
			// call xpc_connection_cancel(). Just tear down any associated state
			// here.
		} else if (event == XPC_ERROR_TERMINATION_IMMINENT) {
			// Handle per-connection termination cleanup.
		}
	} else {
		assert(type == XPC_TYPE_DICTIONARY);
        handle_message(peer, event);
	}
}

static void gitxpc_event_handler(xpc_connection_t peer) 
{
	xpc_connection_set_target_queue(peer, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0));
    
	xpc_connection_set_event_handler(peer, ^(xpc_object_t event) {
		gitxpc_peer_event_handler(peer, event);
	});
	
	xpc_connection_resume(peer);
}

int main(int argc, const char *argv[]) {
	xpc_main(gitxpc_event_handler);
	return 0;
}
