//
//  GTRepository+Chocolat.m
//  gitxpc
//
//  Created by Nicholas Penree on 4/15/14.
//  Copyright (c) 2014 Chocolat. All rights reserved.
//

#import "GTRepository+Chocolat.h"
#import "EXTScope.h"

@implementation GTRepository (Chocolat)

- (BOOL)choc_enumerateFileStatusUsingBlock:(void (^)(NSString *path, GTRepositoryStatusFlags status, BOOL *stop))block {
	NSParameterAssert(block != NULL);

    NSDictionary *options = @{ GTRepositoryStatusOptionsFlagsKey: @(GTRepositoryStatusFlagsIncludeUntracked | GTRepositoryStatusFlagsRecurseUntrackedDirectories | GTRepositoryStatusFlagsRenamesHeadToIndex) };
	__block git_status_options gitOptions = GIT_STATUS_OPTIONS_INIT;
	gitOptions.flags = GIT_STATUS_OPT_DEFAULTS;
    
	NSArray *pathSpec = options[GTRepositoryStatusOptionsPathSpecArrayKey];
	if (pathSpec != nil) gitOptions.pathspec = pathSpec.git_strarray;
    
	NSNumber *flagsNumber = options[GTRepositoryStatusOptionsFlagsKey];
	if (flagsNumber != nil) gitOptions.flags = flagsNumber.unsignedIntValue;
    
	NSNumber *showNumber = options[GTRepositoryStatusOptionsShowKey];
	if (showNumber != nil) gitOptions.show = showNumber.unsignedIntValue;
    
	git_status_list *statusList;
	git_status_list_new(&statusList, self.git_repository, &gitOptions);
	@onExit {
		git_status_list_free(statusList);
		if (gitOptions.pathspec.count > 0) git_strarray_free(&gitOptions.pathspec);
	};
    
	size_t statusCount = git_status_list_entrycount(statusList);
	if (statusCount < 1) return YES;
    
	BOOL stop = NO;
	for (size_t idx = 0; idx < statusCount; idx++) {
		const git_status_entry *entry = git_status_byindex(statusList, idx);
        const char *path = entry->head_to_index
            ? entry->head_to_index->old_file.path
            : entry->index_to_workdir->old_file.path;

		block([NSString stringWithUTF8String:path], (GTRepositoryStatusFlags)entry->status, &stop);
        
		if (stop) break;
	}
    
	return YES;
}

@end
