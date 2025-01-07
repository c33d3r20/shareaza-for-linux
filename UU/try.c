#define I_UNISTD
#ifdef I_UNISTD
#include <unistd.h>
#endif
int main(void)
{
	static int ret;
	ret |= access("path", 1);
	return ret ? 0 : 1;
}
