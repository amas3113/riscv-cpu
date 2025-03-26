# -*- coding: utf-8 -*-
"""
Created on Sat Mar  2 20:33:10 2022

@author: leezi
"""
import secrets
import random
import os

num_commands = 10000
mem_region_len = 256

with open("randmem.s", "w") as file:
    file.write(
"""
randmem.s:
.align 4
.section .text
.globl _start

_start:
    la x31, data_start
"""
)
    
    for i in range(num_commands):
        x = random.randint(0, 8)
        if(x <= 0):
            file.write(f"    lw x{random.randint(1,30)}, {random.randint(0,mem_region_len/4-1)*4}(x31)")
        elif(x <= 1):
            file.write(f"    lh x{random.randint(1,30)}, {random.randint(0,mem_region_len/2-1)*2}(x31)")
        elif(x <= 2):
            file.write(f"    lb x{random.randint(1,30)}, {random.randint(0,mem_region_len)}(x31)")
        elif(x <= 4):
            file.write(f"    sw x{random.randint(1,30)}, {random.randint(0,mem_region_len/4-1)*4}(x31)")
        elif(x <= 6):
            file.write(f"    sh x{random.randint(1,30)}, {random.randint(0,mem_region_len/2-1)*2}(x31)")
        elif(x <= 8):
            file.write(f"    sb x{random.randint(1,30)}, {random.randint(0,mem_region_len)}(x31)")
        file.write('\n')
        
    file.write(
"""
    done:
        beq x0, x0, done

.section .data
data_start:
"""
        )
    for i in range(mem_region_len):
        file.write(
f"""
    .word 0x{secrets.token_hex(4)}""")