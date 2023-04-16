BITS 64

%define CELL_AMOUNT 32768

%define SYS_READ 0
%define SYS_WRITE 1
%define SYS_OPEN 2
%define SYS_CLOSE 3
%define SYS_FSTAT 5
%define SYS_MMAP 9
%define SYS_MUNMAP 11

%define STD_IN 0
%define STD_OUT 1

%define O_RDONLY 0
%define PROT_READ 0x1
%define PROT_WRITE 0x2
%define MAP_PRIVATE 0x2
%define MAP_ANONYMOUS 0x20

section .data
    arg_err_str db "Expected exactly one argument containing the path to a file!", 10
    arg_err_str_len equ $ - arg_err_str

    f_open_err_str db "Could not find or open input file!", 10
    f_open_err_str_len equ $ - f_open_err_str

    bracket_err_str db "Bracket mismatch!", 10
    bracket_err_str_len equ $ - bracket_err_str

section .bss
    cells resb CELL_AMOUNT
    io_char resb 1

section .text
    global _start

    %macro print_str 2
        mov rax, SYS_WRITE
        mov rdi, STD_OUT
        mov rsi, %1
        mov rdx, %2
        syscall
    %endmacro

_start:
    ; load argc and make sure at least one additional argument (file) is available
    mov rdi, [rsp]      
    cmp rdi, 2
    jne _arg_error

    ; load argv[1] (file path) into rsi
    mov rdi, [rsp + 16]

    ; try to open file from path
    mov rax, SYS_OPEN
    mov rsi, O_RDONLY
    mov rdx, 0
    syscall

    ; test if the file was opened successfully and store buffer in r12 (callee saved)
    cmp rax, 0
    jl _file_open_error
    mov r12, rax

    ; get the amount of characters in the file
    mov rax, SYS_FSTAT
    mov rdi, r12
    mov rsi, rsp        ; save result on stack
    syscall
    mov r13, [rsp + 48] ; the file size is at offset 48

    ; allocate memory to store the file content
    mov rax, SYS_MMAP
    mov rdi, 0
    mov rsi, r13
    mov rdx, PROT_READ | PROT_WRITE
    mov r10, MAP_PRIVATE | MAP_ANONYMOUS
    mov r8, -1
    mov r9, 0
    syscall

    ; make sure memory has been allocated successfully
    cmp rax, 0
    je _exit_err
    mov r14, rax

    ; copy the file contents into the allocated memory
    mov rax, 0
    mov rdi, r12
    mov rsi, r14
    mov rdx, r13
    syscall

    ; close the file
    mov rax, SYS_CLOSE
    mov rdi, r12
    syscall

    ; interpret file (byte amount in r13, content ptr in r14)
    mov rdi, r14
    mov rsi, r13
    call _interpret

    ; free memory
    mov rax, SYS_MUNMAP
    mov rdi, r14
    mov rsi, r13
    syscall

    jmp _exit

; 1st arg (rdi) ptr to buffer, 2nd arg (rsi) buffer length
_interpret:
    push r13
    mov r10, 0      ; r10 is the index in the code
    mov r11, 0      ; r11 is the cell ptr
    mov r12, rdi    ; store buffer ptr into r12
    mov r13, rsi    ; store buffer len into r13

_int_loop:
    ; stop when the cell ptr points after the last or
    cmp r10, r13
    jge _int_ret

    ; read the current code character
    movzx r8, BYTE [r12 + r10]

    ; execute instruction
    cmp r8, '>'
    je _int_move_right
    cmp r8, '<'
    je _int_move_left
    cmp r8, '+'
    je _int_inc_cell
    cmp r8, '-'
    je _int_dec_cell
    cmp r8, '.'
    je _int_out
    cmp r8, ','
    je _int_in
    cmp r8, '['
    je _int_jmp_fwd
    cmp r8, ']'
    je _int_jmp_bwd

    ; default case, move to next instruction
_int_loop_def:
    inc r10
    jmp _int_loop

_int_ret:
    pop r13
    ret

_int_move_right:
    inc r11
    jmp _int_loop_def

_int_move_left:
    dec r11
    jmp _int_loop_def

_int_inc_cell:
    inc BYTE [cells + r11]
    jmp _int_loop_def

_int_dec_cell:
    dec BYTE [cells + r11]
    jmp _int_loop_def

_int_out:
    mov rdi, SYS_WRITE
    mov rsi, STD_OUT
    jmp _int_io

_int_in:
    mov rdi, SYS_READ
    mov rsi, STD_IN
    jmp _int_io

; 1st arg (rdi) sys operation (read/write), 2nd arg (rsi) buffer (in/out)
_int_io:
    ; move current cell value into io_char (required if writing, reading is not affected)
    movzx rax, BYTE [cells + r11]
    mov [io_char], rax

    push r8
    push r10
    push r11

    ;read/write depending on rdi, rsi
    mov rax, rdi
    mov rdi, rsi
    mov rsi, io_char
    mov rdx, 1
    syscall

    pop r11
    pop r10
    pop r8

    ; move read value into cell if reading
    cmp rdi, SYS_READ
    jne _int_io_end
_int_io_read_res:
    movzx rax, BYTE [io_char]
    mov [cells + r11], rax    
_int_io_end:
    jmp _int_loop_def

_int_jmp_fwd:
    movzx rax, BYTE [cells + r11]
    cmp rax, 0
    jne _int_loop_def

    mov rdi, 1
    mov rsi, '['
    mov rdx, ']'
    jmp _int_jmp_search

_int_jmp_bwd:
    movzx rax, BYTE [cells + r11]
    cmp rax, 0
    je _int_loop_def
    
    mov rdi, -1
    mov rsi, ']'
    mov rdx, '['
    jmp _int_jmp_search

; 1st arg (rdi) 1/-1 = inc/dec, 2nd arg (rsi) opening bracket, 3rd arg (rdx) closing bracket
_int_jmp_search:
    mov r9, 1
_int_jmp_search_loop:
    add r10, rdi
    cmp r10, 0
    jl _bracket_mismatch_error
    cmp r10, r13
    jge _bracket_mismatch_error

    movzx rax, BYTE [r12 + r10]
    cmp rax, rsi
    je _int_jmp_open
    cmp rax, rdx
    je _int_jmp_close
    jmp _int_jmp_search_loop
_int_jmp_open:
    inc r9
    jmp _int_jmp_end
_int_jmp_close:
    dec r9
    cmp r9, 0
    je _int_loop_def
_int_jmp_end:
    jmp _int_jmp_search_loop

_arg_error:
    print_str arg_err_str, arg_err_str_len
    jmp _exit_err

_file_open_error:
    print_str f_open_err_str, f_open_err_str_len
    jmp _exit_err

_bracket_mismatch_error:
    print_str bracket_err_str, bracket_err_str_len
    jmp _exit_err

_exit_err:
    mov rax, 60
    mov rdi, 1
    syscall

_exit:
    mov rax, 60
    mov rdi, 0
    syscall