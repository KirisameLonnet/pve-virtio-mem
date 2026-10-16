/* SPDX-License-Identifier: Apache-2.0
 * Freestanding synthetic x86_64 /init. No guest disks, networking or services.
 */
typedef unsigned long word;

static long syscall6(long n, long a, long b, long c, long d, long e, long f)
{
    register long r10 __asm__("r10") = d;
    register long r8 __asm__("r8") = e;
    register long r9 __asm__("r9") = f;
    long result;
    __asm__ volatile("syscall" : "=a"(result)
                     : "a"(n), "D"(a), "S"(b), "d"(c),
                       "r"(r10), "r"(r8), "r"(r9)
                     : "rcx", "r11", "memory");
    return result;
}

static void print(const char *s)
{
    word length = 0;
    while (s[length]) length++;
    while (length) {
        long n = syscall6(1, 1, (long)s, length, 0, 0, 0);
        if (n <= 0) return;
        s += n;
        length -= n;
    }
}

static void number(word value)
{
    char buffer[32];
    word i = sizeof(buffer) - 1;
    buffer[i] = 0;
    do {
        buffer[--i] = '0' + value % 10;
        value /= 10;
    } while (value);
    print(buffer + i);
}

static void sleep_seconds(long seconds)
{
    long delay[2] = {seconds, 0};
    while (syscall6(35, (long)delay, (long)delay, 0, 0, 0, 0) == -4) {}
}

__attribute__((noreturn)) static void fail(const char *reason)
{
    print("TRANSPARENT FAIL ");
    print(reason);
    print("\n");
    for (;;) syscall6(34, 0, 0, 0, 0, 0, 0);
}

static word mem_total(void)
{
    char buffer[4096];
    long fd = syscall6(257, -100, (long)"/proc/meminfo", 0, 0, 0, 0);
    if (fd < 0) fail("open meminfo");
    long size = syscall6(0, fd, (long)buffer, sizeof(buffer), 0, 0, 0);
    syscall6(3, fd, 0, 0, 0, 0, 0);
    const char prefix[] = "MemTotal:";
    word i = 0;
    for (; i < sizeof(prefix) - 1; i++)
        if (size <= (long)i || buffer[i] != prefix[i]) fail("invalid meminfo");
    while (i < (word)size && buffer[i] == ' ') i++;
    word value = 0;
    while (i < (word)size && buffer[i] >= '0' && buffer[i] <= '9')
        value = value * 10 + buffer[i++] - '0';
    if (!value) fail("empty memory size");
    return value;
}

static word initial_total;
static word allocation;

static void phase(const char *name)
{
    word total = mem_total();
    if (total != initial_total) fail("guest-visible capacity changed");
    print("TRANSPARENT {\"phase\":\"");
    print(name);
    print("\",\"mem_total_kib\":");
    number(total);
    print(",\"allocation_bytes\":");
    number(allocation);
    print("}\n");
}

__attribute__((noreturn, used)) void init_main(void)
{
    long console = syscall6(257, -100, (long)"/dev/console", 2, 0, 0, 0);
    if (console >= 0) {
        for (long fd = 0; fd < 3; fd++)
            if (fd != console) syscall6(292, console, fd, 0, 0, 0, 0);
    }
    if (syscall6(165, (long)"proc", (long)"/proc", (long)"proc", 0, 0, 0) < 0)
        fail("mount proc");
    sleep_seconds(4);
    initial_total = mem_total();
    allocation = (initial_total * 1024 * 9 / 10) & ~((2UL << 20) - 1);
    phase("baseline");
    sleep_seconds(6);
    for (word round = 1; round <= 2; round++) {
        long address = syscall6(9, 0, allocation, 3, 0x22, -1, 0);
        if (address < 0 && address >= -4095) fail("mmap");
        for (word offset = 0; offset < allocation; offset += 4096) {
            volatile word *page = (volatile word *)(address + offset);
            if (page[0] || page[511]) fail("fresh anonymous memory not zero");
            page[0] = offset ^ (round << 48);
            page[511] = ~page[0];
        }
        phase(round == 1 ? "allocated_1" : "allocated_2");
        sleep_seconds(6);
        for (word offset = 0; offset < allocation; offset += 4096) {
            volatile word *page = (volatile word *)(address + offset);
            word expected = offset ^ (round << 48);
            if (page[0] != expected || page[511] != ~expected)
                fail("allocated data changed during background reclaim");
        }
        if (syscall6(11, address, allocation, 0, 0, 0, 0) < 0) fail("munmap");
        phase(round == 1 ? "freed_1" : "freed_2");
        sleep_seconds(12);
        phase(round == 1 ? "idle_1" : "idle_2");
    }
    phase("pass");
    for (;;) syscall6(34, 0, 0, 0, 0, 0, 0);
}

__asm__(".global _start\n_start:\nxor %rbp,%rbp\nand $-16,%rsp\ncall init_main\n1: jmp 1b\n");
