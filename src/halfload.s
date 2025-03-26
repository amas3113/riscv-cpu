halfload.s:
.align 4
.section .text
.globl _start
    # Refer to the RISC-V ISA Spec for the functionality of
    # the instructions in this test program.
    # This is a simple ASM program to compute a factorial.
    # The input is present in register a0 and the answer is stored in a0 when the program ends
_start:

    lw x5, negone
    lw x5, neghfw
    lw x5, negbte
    lw x5, posone
    lw x5, postwo
    lw x5, postre

    lh x5, negone
    lhu x5, negone
    lb x5, negone
    lbu x5, negone

    lh x5, neghfw
    lhu x5, neghfw
    lb x5, neghfw
    lbu x5, neghfw

    lh x5, negbte
    lhu x5, negbte
    lb x5, negbte
    lbu x5, negbte

    lh x5, posone
    lhu x5, posone
    lb x5, posone
    lbu x5, posone

    lh x5, postwo
    lhu x5, postwo
    lb x5, postwo
    lbu x5, postwo

    lh x5, postre
    lhu x5, postre
    lb x5, postre
    lbu x5, postre

    la x1, negone
    lb x5, 0(x1)
    lb x5, 1(x1)
    lb x5, 2(x1)
    lb x5, 3(x1)

    lbu x5, 0(x1)
    lbu x5, 1(x1)
    lbu x5, 2(x1)
    lbu x5, 3(x1)

    lh x5, 0(x1)
    lh x5, 2(x1)

    lhu x5, 0(x1)
    lhu x5, 2(x1)

    done:
        beq x0, x0, done

.section .rodata
# if you need any constants
negone:    .word 0xffffffff # neg neg neg
neghfw:    .word 0x8000F102 # neg neg pos
negbte:    .word 0x800070F0 # neg pos neg
posone:    .word 0x7FFFFFFF # pos neg neg
postwo:    .word 0x701270F3 # pos pos neg
postre:    .word 0x70707040 # pos pos pos