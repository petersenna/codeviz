#!/bin/bash
#
# Usage :  check-stack.sh vmlinux $(/sbin/modprobe -l)
#
#       Run a compiled ix86 kernel and print large local stack usage.
#
#       />:/{s/[<>:]*//g; h; }   On lines that contain '>:' (headings like
#       c0100000 <_stext>:), remove <, > and : and hold the line.  Identifies
#       the procedure and its start address.
#
#       /subl\?.*\$0x[^,][^,][^,].*,%esp/{    Select lines containing
#       subl\?...0x...,%esp but only if there are at least 3 digits between 0x and
#       ,%esp.  These are local stacks of at least 0x100 bytes.
#
#       s/.*$0x\([^,]*\).*/\1/;   Extract just the stack adjustment
#       /^[89a-f].......$/d;   Ignore line with 8 digit offsets that are
#       negative.  Some compilers adjust the stack on exit, seems to be related
#       to goto statements
#       G;   Append the held line (procedure and start address).
#       s/\(.*\)\n.* \(.*\)/\1 \2/;  Remove the newline and procedure start
#       address.  Leaves just stack size and procedure name.
#       p; };   Print stack size and procedure name.
#
#       /subl\?.*%.*,%esp/{   Selects adjustment of %esp by register, dynamic
#       arrays on stack.
#       G;   Append the held line (procedure and start address).
#       s/\(.*\)\n\(.*\)/Dynamic \2 \1/;   Reformat to "Dynamic", procedure
#       start address, procedure name and the instruction that adjusts the
#       stack, including its offset within the proc.
#       p; };   Print the dynamic line.
#
#
#       Leading spaces in the sed string are required.
#
objdump --disassemble "$@" | \
sed -ne '/>:/{s/[<>:]*//g; h; }
 /subl\?.*\$0x[^,].*,%esp/{
 s/.*\$\(0x[^,]*\).*/\1/; /^[89a-f].......$/d; G; s/\(.*\)\n.* \(.*\)/\1 \2/; p; };
 /subl\?.*%.*,%esp/{ G; s/\(.*\)\n\(.*\)/Dynamic \2 \1/; p; }; ' | \
sort -r
