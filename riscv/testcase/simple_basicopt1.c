#include "io.h"
int main()
{
    int N = 9;
    int a[N][N];
    int i;
	int j;
    int sum = 0;

    for (i = 0;i < N;i++)
        for (j = 0;j < N;j++)
            a[i][j] = 1;

    for (i = 0;i < N;i++)
        for (j = 0;j < N;j++)
            sum = sum + a[i][j];
    outlln(sum);
}
