#!/usr/sbin/dtrace -s
/*
 * mysqld_pid_fslatency.d  Print file system latency distribution every second.
 *
 * USAGE: ./mysqld_pid_fslatency.d -p mysqld_PID
 *
 */

#pragma D option quiet

dtrace:::BEGIN
{
        printf("Tracing PID %d... Hit Ctrl-C to end.\n", $target);
}

pid$target::os_file_read:entry,
pid$target::os_file_write:entry,
pid$target::my_read:entry,
pid$target::my_write:entry
{
        self->start = timestamp;
}

pid$target::os_file_read:return  { this->dir = "read"; }
pid$target::os_file_write:return { this->dir = "write"; }
pid$target::my_read:return       { this->dir = "read"; }
pid$target::my_write:return      { this->dir = "write"; }

pid$target::os_file_read:return,
pid$target::os_file_write:return,
pid$target::my_read:return,
pid$target::my_write:return
/self->start/
{
        @time[this->dir] = quantize(timestamp - self->start);
        @num = count();
        self->start = 0;
}

dtrace:::END
{
        printa("MySQL filesystem I/O: %@d; latency (ns):\n", @num);
        printa(@time);
        clear(@time); clear(@num);
}