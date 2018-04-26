printString: ; void printString(char *c);
  push eax
  push ebx
  push ecx
  mov ebx, eax
  .loop:
  mov cl, byte [ebx]
  cmp cl, byte 0
  je .exit
  mov eax, 4
  push dword 1
  push ebx
  push dword 1
  sub esp, 4
  int 0x80
  add esp, 0x10
  inc ebx
  jmp .loop
  .exit:
  pop ecx
  pop ebx
  pop eax
  ret

printReg: ; void printReg(uint32_t v);
  push eax
  push ebx
  push ecx
  push edx
  mov ecx, 8
  mov edx, printDwordBuf
  .loop:
    rol eax, 4
    mov ebx, eax
    and ebx, 0x0F
    add ebx, hexString
    mov bl, byte [ebx]
    mov [edx], byte bl
    inc edx
    dec ecx
    jnz .loop
  push dword 11
  mov ecx, dword printDwordBuf
  sub ecx, 2
  push ecx
  push dword 1
  sub esp, 4
  mov eax, 4
  int 0x80
  add esp, 16
  pop edx
  pop ecx
  pop ebx
  pop eax
  ret

memcpy: ;void memcpy(char *a, char *b, uint32_t n);
  push eax
  push ebx
  push ecx
  push edx
  cmp ecx, dword 0
  je .exit
  .loop:
    mov dl, byte [ebx]
    mov [eax], dl
    inc ebx
    inc eax
    dec ecx
    jnz .loop
  .exit:
  pop edx
  pop ecx
  pop ebx
  pop eax
  ret

memset: ;void memset(char *a, char c, unsigned int n);
  push eax
  push ebx
  push ecx
  cmp ecx, dword 0
  jz .exit
  .loop:
    mov [eax], bl
    inc eax
    dec ecx
    jnz .loop
  .exit:
  pop ecx
  pop ebx
  pop eax
  ret

ntohs: ; short ntohs(short s);
htons: ; short htons(short s);
  push ebx
  xor ebx, ebx ; zero
  mov bh,al
  mov bl, ah
  mov ax, bx
  pop ebx
  ret

ntohl:
htonl:
  push ebx
  xor ebx, ebx ;zero
  rol eax, 16 ; swap upper and lower bytes
  mov bl, ah
  mov bh, al
  rol eax, 16 ;eax - normal
  rol ebx, 16 ;ebx - swapped
  mov bl, ah
  mov bh, al
  mov eax, ebx
  ror eax, 16
  pop ebx
  ret

printEndl:
  push eax
  push dword 1
  push dword endl
  push dword 1
  sub esp, 4
  mov eax, 4
  int 0x80
  add esp, 0x10
  pop eax
  ret

bufcmp:
  push ebx
  push ecx
  push edx
  cmp ecx, dword 0
  je .exitTrue
  .loop:
  mov dh, byte [eax]
  mov dl, byte [ebx]
  cmp dh, dl
  jne .exitFalse
  inc eax
  inc ebx
  dec ecx
  jnz .loop
  .exitTrue:
  mov eax, 1
  pop edx
  pop ecx
  pop ebx
  ret
  .exitFalse:
  mov eax, 0
  pop edx
  pop ecx
  pop ebx
  ret

strcmp:
  push ebx
  push ecx
  .loop:
  mov ch, byte [eax]
  mov cl, byte [ebx]
  cmp ch, cl
  jne .exitFalse
  cmp cl, byte 0
  je .exitTrue
  inc eax
  inc ebx
  jmp .loop
  .exitFalse:
  mov eax, 0
  pop ebx
  pop ecx
  ret
  .exitTrue:
  mov eax, 1
  pop ebx
  pop ecx
  ret

printStrHex:
  push eax
  push ebx
  mov ebx, eax
  xor eax, eax
  mov al, byte [ebx]
  cmp al, byte 0
  je .exit
  .loop:
    mov al, byte [ebx]
    cmp al, byte 0
    je .exit
    call printReg
    inc ebx
    jmp .loop
  .exit:
  pop ebx
  pop eax
  ret

printBuf: ; void printBuf(char *c, uint32_t len);
  push eax
  push ebx
  dec eax
  .loop:
  inc eax
  push eax
  mov al, byte [eax]
  and eax, 0xFF
  call printReg
  pop eax
  dec ebx
  jnz .loop
  pop ebx
  pop eax
  ret

getParams:
  push eax
  mov eax, [esp+8]
  mov [argc], eax
  lea eax, [esp+0xC]
  mov [argv], eax
  mov eax, [esp+4];ret address
  mov [esp + 8], eax
  pop eax
  add esp, 4
  ret
;This doesn't work yet, don't use it
atoi:
  push ebx
  push ecx
  push edx
  .initLoop:
    mov bl, byte [eax]
    cmp bl, byte 0
    je .exitInitLoop
    cmp bl, byte '0'
    jl .initLoop
    cmp bl, byte '9'
    jg .initLoop
  .exitInitLoop:

  cmp bl, byte 0
  jne .notZeroAfterInitLoop
  mov eax, 0
  jmp .exit
  .notZeroAfterInitLoop:
  mov ecx,eax
  xor eax, eax
  xor ebx, ebx
  mov bl, [ecx]
  .mainLoop:
    cmp bl, byte '0'
    jl .mainLoopComparator
    cmp bl, byte '9'
    jg .mainLoopComparator
    sub bl, byte '0'
    mov edx, 10
    mul edx
    add eax, ebx
    .mainLoopComparator:
    inc ecx
    mov bl, byte [ecx]
    cmp bl, byte 0
    jne .mainLoop
  .exit:
  pop edx
  pop ecx
  pop ebx
  ret

; Psedo-Code  - its acctually just c-ish
; (u)int32_t atoi(char *str){ //The u is just for now
;   for(;*str != 0 && !('0' <= *str && *str <= '9'); str++); // get to start of nums
;
;   if(*str == 0) return 0;
;
;   uint32_t ret;
;
;   do{
;     if('0' <= *str && *str <= '9'){
;       ret *= 10;
;       ret += *str - '0'
;     }
;   }for(; *str; str++);
;
;   return ret;
; }
uintToStr: ;uint32_t uintToStr(uint32_t n); //Return Value <=10
  push ebx
  push ecx
  push edx
  mov ebx, uintToStrRet
  xor ecx, ecx
  .toBackwardsStringLoop:
    inc ecx
    xor edx, edx
    push ebx
    mov ebx, 10
    div ebx
    pop ebx
    add dl, byte '0'
    mov [ebx], dl
    inc ebx
    cmp eax, dword 0
    jne .toBackwardsStringLoop

    ;for loop setup
    xor edx, edx
    mov eax, ecx
    shr eax, 1
    ;for loop
    .weLoopingBois:
    cmp edx, eax
    jnl .exit
    push ecx
    mov ecx, edx
    add ecx, dword uintToStrRet
    mov bl, byte [ecx]
    mov ecx, dword [esp]
    sub ecx, edx
    add ecx, dword uintToStrRet
    dec ecx
    mov bh, byte [ecx]
    mov byte [ecx], bl
    mov ecx, edx
    add ecx, dword uintToStrRet
    mov byte [ecx], bh
    pop ecx
    inc edx
    jmp .weLoopingBois

  ; xor edx, edx
  ; dec edx
  ; mov eax, ecx
  ; shr eax, 1
  ; .forLoopComparator:
  ; inc edx
  ; cmp edx, eax
  ; jge .exit
  ;   mov cl, byte [ebx + edx]
  ;   push eax
  ;   push ecx
  ;   push edx
  ;   ;eax = len >> 1
  ;   ;ecx = len
  ;   ;edx = offset
  ;   sub ecx, edx
  ;   add ecx, ebx
  ;   mov al, byte [ecx]
  ;   add edx, ebx
  ;   mov ah, byte [edx]
  ;   mov [ecx], ah
  ;   mov [edx], al
  ;   pop edx
  ;   pop ecx
  ;   pop eax
  ; jmp .forLoopComparator
  .exit:
  mov eax,ecx
  pop edx
  pop ecx
  pop ebx
  ret

section .data
  db '0x'
  printDwordBuf: db '00000000', 0x0A, 0
  hexString: db '0123456789ABCDEF'
  endl: db 0x0A
  uintToStrRet: times 11 db 0
  section .bss
  argc: RESD 1
  argv: RESD 1
