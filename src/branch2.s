branch2.s:
.align 4
.section .text
.globl _start

_start:
    lw x1, num1
    lw x2, num2
    lw x3, num3
    lw x4, num4

    bge x1, x2, _bad
    bgeu x1, x2, _next2

    jal _bad

    _next2:
    bge x4, x3, _bad
    bgeu x4, x3, _next3

    jal _bad

    _next3:
    blt x2, x1, _bad
    bltu x2, x1, _next4

    jal _bad

    _next4:
    beq x3, x4, _bad
    beq x1, x2, _bad

    _next5:
    blt x3, x4, _bad

_good:
    lw x1, good
_goode:
    jal x0, _goode

_bad:
    lw x1, badb
_bade:
    jal x0, _bade

.section .rodata
num1: .word 0xFFFFFFFF
num2: .word 0x00000001
num3: .word 0x5A5A5A5A
num4: .word 0xDA5A5A5A
badb: .word 0x0BADBAD0
good: .word 0x600d600d