int main()
{
	int a[2], i;
	for (i = 0;i < 2;++ i) a[i] = i;
	if (a[0] != 0 || a[1] != 1)
		for (;;) a[0] = a[0] + 1;
}