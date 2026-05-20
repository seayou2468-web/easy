/*
 * This file is part of EasyRPG Player.
 */

#include "system.h"

#if defined(__APPLE__) && TARGET_OS_IOS
#import <Foundation/Foundation.h>
#include "platform/ios/ios_utils.h"

std::string IOSUtils::GetBundleDir() {
	@autoreleasepool {
		NSBundle* mainBundle = [NSBundle mainBundle];
		NSURL* bundleURL = [mainBundle bundleURL];
		const char* fsPath = [bundleURL fileSystemRepresentation];
		return fsPath ? std::string(fsPath) : std::string();
	}
}

std::string IOSUtils::GetDocumentsDir() {
	@autoreleasepool {
		NSArray<NSURL*>* urls = [[NSFileManager defaultManager] URLsForDirectory:NSDocumentDirectory inDomains:NSUserDomainMask];
		NSURL* documents = [urls firstObject];
		if (documents == nil) {
			return GetBundleDir();
		}
		NSString* path = [[[documents URLByResolvingSymlinksInPath] URLByStandardizingPath] path];
		if (path == nil || [path length] == 0) {
			path = [documents path];
		}
		if (path == nil || [path length] == 0) {
			return GetBundleDir();
		}
		// Defensive fallback: ensure an absolute path is returned.
		if (![path hasPrefix:@"/"]) {
			NSString* home = NSHomeDirectory();
			path = [home stringByAppendingPathComponent:path];
		}
		return std::string([path UTF8String]);
	}
}

#endif
