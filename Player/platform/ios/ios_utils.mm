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
		// Keep the container-provided path as-is.
		// LiveContainer setups can intentionally expose nested paths here.
		const char* fsPath = [documents fileSystemRepresentation];
		return fsPath ? std::string(fsPath) : GetBundleDir();
	}
}

#endif
