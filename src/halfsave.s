halfsave.s:
.align 4
.section .text
.globl _start
    # Refer to the RISC-V ISA Spec for the functionality of
    # the instructions in this test program.
    # This is a simple ASM program to compute a factorial.
    # The input is present in register a0 and the answer is stored in a0 when the program ends
_start:

    lw x1, negone
    lw x2, neghfw
    lw x3, negbte
    lw x4, posone
    lw x5, postwo
    lw x6, postre

    la x21, saveme

    sw x1, 0(x21)
    lw x7, 0(x21)
    sw x2, 0(x21)
    lw x7, 0(x21)
    sw x3, 0(x21)
    lw x7, 0(x21)
    sw x4, 0(x21)
    lw x7, 0(x21)
    sw x5, 0(x21)
    lw x7, 0(x21)
    sw x6, 0(x21)
    lw x7, 0(x21)
    
    sw x1, 4(x21) 
    sw x2, 4(x21)
    sw x3, 4(x21)
    sw x4, 4(x21)
    sw x5, 4(x21)
    sw x6, 4(x21)

    sw x1, 8(x21) 
    sw x2, 8(x21)
    sw x3, 8(x21)
    sw x4, 8(x21)
    sw x5, 8(x21)
    sw x6, 8(x21)

    sw x1, 12(x21) 
    sw x2, 12(x21)
    sw x3, 12(x21)
    sw x4, 12(x21)
    sw x5, 12(x21)
    sw x6, 12(x21)

    sw x1, 16(x21) 
    sw x2, 16(x21)
    sw x3, 16(x21)
    sw x4, 16(x21)
    sw x5, 16(x21)
    sw x6, 16(x21)

    sh x1, 0(x21) 
    sh x2, 0(x21) # 0000000 00010 10101 001 00000 0100011
    sh x3, 0(x21) 
    sh x4, 0(x21)
    sh x5, 0(x21)
    sh x6, 0(x21)

    sb x1, 0(x21) 
    sb x2, 0(x21) # 0000000 00010 10101 000 00000 0100011
    sb x3, 0(x21)
    sb x4, 0(x21)
    sb x5, 0(x21)
    sb x6, 0(x21)

    sh x1, 2(x21) # 0000000 00001 10101 001 00010 0100011
    sh x2, 2(x21)
    sh x3, 2(x21)
    sh x4, 2(x21)
    sh x5, 2(x21)
    sh x6, 2(x21)

    sb x1, 1(x21)
    sb x2, 1(x21)
    sb x3, 1(x21)
    sb x4, 1(x21)
    sb x5, 1(x21)
    sb x6, 1(x21)

    sb x1, 2(x21)
    sb x2, 2(x21)
    sb x3, 2(x21)
    sb x4, 2(x21)
    sb x5, 2(x21)
    sb x6, 2(x21)

    sb x1, 3(x21)
    sb x2, 3(x21)
    sb x3, 3(x21)
    sb x4, 3(x21)
    sb x5, 3(x21)
    sb x6, 3(x21)

    jal _start

    done:
        beq x0, x0, done

.section .data
# if you need any constants
negone:    .word 0xffffffff # neg neg neg
neghfw:    .word 0x8000F102 # neg neg pos
negbte:    .word 0x800070F0 # neg pos neg
posone:    .word 0x7FFFFFFF # pos neg neg
postwo:    .word 0x701270F3 # pos pos neg
postre:    .word 0x70707040 # pos pos pos

saveme:    .word 0x00000000 # place to save to
    .word 0x00000000 # place to save to
    .word 0x00000000 # place to save to
    .word 0x00000000 # place to save to
    .word 0x00000000 # place to save to
    .word 0x00000000 # place to save to
    .word 0x00000000 # place to save to
    .word 0x00000000 # place to save to
    .word 0x00000000 # place to save to
    .word 0x00000000 # place to save to
    .word 0x00000000 # place to save to
    .word 0x00000000 # place to save to
    .word 0x00000000 # place to save to
    .word 0x00000000 # place to save to
    .word 0x00000000 # place to save to
    .word 0x00000000 # place to save to
    .word 0x00000000 # place to save to
    .word 0x00000000 # place to save to
    .word 0x00000000 # place to save to
    .word 0x00000000 # place to save to
    .word 0x00000000 # place to save to
    .word 0x00000000 # place to save to
    .word 0x00000000 # place to save to
