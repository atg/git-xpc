//  Created by Alex Gordon on 13/03/2014.

#include <xpc/xpc.h>
#include <Foundation/Foundation.h>
#import "git2.h"

#import "GTDiffPatch.h"
#import "GTDiffDelta.h"
#import "GTDiffHunk.h"
#import "GTDiffLine.h"
#import "GTDiff.h"
#import "GTTree.h"
#import "GTTreeBuilder.h"
#import "GTTreeEntry.h"
#import "ObjectiveGit.h"

static int status_callback(const char *path, unsigned int status_flags, void *payload) {

    // Ignore ignored files
    if ((status_flags & GIT_STATUS_IGNORED) != 0)
        return 0;

    xpc_object_t msg = (__bridge xpc_object_t)payload;
    xpc_dictionary_set_uint64(msg, path, status_flags);
    return 0;
}

static void get_status(xpc_connection_t conn, xpc_object_t msg, const char* path) {
    // { "files": [ { "path": "path/to/directory/file.txt", "status": "added" } ] }

    // TODO: Cache repos? Or would that confuse git by holding locks?

    NSTimeInterval t0 = [NSDate timeIntervalSinceReferenceDate];
    git_repository* repo = NULL;
    if (!git_repository_open(&repo, path) && repo) {
        git_status_foreach(repo, status_callback, (__bridge void*)msg); //CFBridgingRetain(msg));
        git_repository_free(repo);
    }
    NSTimeInterval t1 = [NSDate timeIntervalSinceReferenceDate];

    int64_t t_ms = (t1 - t0) * 1000;
    if (t_ms < 0)
        t_ms = 0;

    xpc_dictionary_set_uint64(msg, "com.chocolatapp.Chocolat.time_taken_ms", (uint64_t)t_ms);
    xpc_connection_send_message(conn, msg);
}

int onGTDiffLine(const git_diff_delta *gitDelta, const git_diff_hunk *gitHunk, const git_diff_line *gitLine, void *payload){
    xpc_object_t modifications = (__bridge xpc_object_t) payload;
    GTDiffLine *line = [[GTDiffLine alloc] initWithGitLine:gitLine];
    if (line.newLineNumber < 0) {
        return 1;
    }

    xpc_object_t change = xpc_array_create(NULL, 0);
    xpc_array_set_int64(change, 0, (int64_t)(line.oldLineNumber));
    xpc_array_set_int64(change, 1, (int64_t)(line.newLineNumber));
    xpc_array_set_int64(change, 2, (int64_t)(line.origin));
    xpc_array_append_value(modifications, change);
    return 0;
}

static git_blob* getOldBlob(GTRepository *repo, NSURL *filepath){
    git_blob *blob = NULL;
    git_reference* head;

    if (git_repository_head(&head, repo.git_repository) != GIT_OK){
        return NULL;
    }

    const git_oid* sha = git_reference_target(head);
    git_commit* commit;
    int commitStatus = git_commit_lookup(&commit, repo.git_repository, sha);
    git_reference_free(head);
    if (commitStatus != GIT_OK) {
        return blob;
    };

    git_tree* tree;
    int treeStatus = git_commit_tree(&tree, commit);
    git_commit_free(commit);
    if (treeStatus != GIT_OK) {
        return blob;
    };

    git_tree_entry* treeEntry;
    if (git_tree_entry_bypath(&treeEntry, tree, [filepath.path UTF8String]) != GIT_OK) {
        git_tree_free(tree);
        return blob;
    }

    const git_oid* blobSha = git_tree_entry_id(treeEntry);
    if (blobSha != NULL) {
        git_blob_lookup(&blob, repo.git_repository, blobSha);
    }

    git_tree_entry_free(treeEntry);
    git_tree_free(tree);

    return blob;
};

static void getDiffOfFile(xpc_connection_t conn, xpc_object_t msg, xpc_object_t event, GTRepository *repo){
    NSURL *filepath = [NSURL URLWithString:@(xpc_dictionary_get_string(event, "filepath"))];
    NSData *contents = [@(xpc_dictionary_get_string(event, "buffer")) dataUsingEncoding:NSUTF8StringEncoding];
    xpc_object_t modifications = xpc_array_create(NULL, 0);


    GTBlob *newBlob = [GTBlob blobWithData:contents inRepository:repo error:nil];
    git_blob *oldBlob = getOldBlob(repo, filepath);

    git_diff_options options = GIT_DIFF_OPTIONS_INIT;
    options.version = GIT_DIFF_OPTIONS_VERSION;
    options.context_lines = 3;
    options.flags = GIT_DIFF_IGNORE_WHITESPACE;

    git_diff_blobs(oldBlob, NULL, newBlob.git_blob, NULL, &options, NULL, NULL, onGTDiffLine, (__bridge void*)modifications);

    xpc_dictionary_set_value(msg, "diff", modifications);
    xpc_connection_send_message(conn, msg);
    git_blob_free(oldBlob);
};

static void do_commit(xpc_connection_t conn, xpc_object_t msg, const char* path) {
    xpc_connection_send_message(conn, msg);
}

static void handle_message(xpc_connection_t peer, xpc_object_t event) {
    const char* name = xpc_dictionary_get_string(event, "type"); assert(name != NULL);
    const char* repopath = xpc_dictionary_get_string(event, "repopath"); assert(repopath != NULL);
    xpc_connection_t reply_conn = xpc_dictionary_get_remote_connection(event); assert(reply_conn != NULL);
    xpc_object_t reply_msg = xpc_dictionary_create_reply(event); assert(reply_msg != NULL);

//    NSLog(@"%@", reply_msg);

    if (0 == strcmp("status", name)) {
        get_status(reply_conn, reply_msg, repopath);
    }
    else if (0 == strcmp("diff", name)) {
        get_diff(reply_conn, reply_msg, event);
    }
    else if (0 == strcmp("commit", name)) {
        do_commit(reply_conn, reply_msg, repopath);
    }
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

void nop_func(int x) {
    _exit(1);
}

int main(int argc, const char *argv[]) {
    // Disable crash reporter
    signal(SIGABRT, nop_func);
    signal(SIGILL, nop_func);
    signal(SIGSEGV, nop_func);
    signal(SIGFPE, nop_func);
    signal(SIGBUS, nop_func);
    signal(SIGPIPE, nop_func);
    signal(SIGSYS, nop_func);
    signal(SIGTRAP, nop_func);

	xpc_main(gitxpc_event_handler);
	return 0;
}
