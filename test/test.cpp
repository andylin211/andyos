#include "tinyutest.h"
#include "tinylog.h"
#pragma comment(lib, "tinylib")
#include "windows.h"

int WINAPI WinMain(HINSTANCE, HINSTANCE, LPSTR, INT)
{
	LOG_DEBUG(NULL);
	LOG_DEBUG(L"%s", L"hellowolrd!");
	RUN_ALL_TESTS();
	return 0;
}

