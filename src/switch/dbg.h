#ifndef H_SWITCHDBG
#define H_SWITCHDBG

// libnx must be included at global scope. Including it from inside a
// namespace also places newlib and C++ standard-library declarations into
// that namespace, which breaks headers such as <fstream>, <ctime> and
// <sys/stat.h>.
#include <switch.h>

// Keep the Switch:: spelling used by the game client while exposing the
// libnx declarations from their normal global namespace.
namespace Switch
{
	using ::PrintConsole;
	using ::Result;
	using ::appletMainLoop;
	using ::consoleExit;
	using ::consoleInit;
	using ::consoleUpdate;
	using ::envSetNextLoad;
	using ::fsdevMountSdmc;
	using ::nxlinkStdio;
	using ::romfsInit;
	using ::socketExit;
	using ::socketInitializeDefault;
}

#endif
