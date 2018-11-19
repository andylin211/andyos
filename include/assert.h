#ifndef _assert_h_
#define _assert_h_

void t_assert_func(char* file, int line);

#define t_assert(condition) do { if (!(condition)) t_assert_func(__FILEW__, __LINE__); } while (0)

#endif
