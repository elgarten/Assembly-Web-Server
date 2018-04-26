;BUF_SIZE = 1 Megabyte
%define BUF_SIZE 2 << 20
%define HEADER_BUF_SIZE 2048
%define PORT 8000
;%define NUM_REQUESTS 5

;%define VERBOSE 1
%define INADDR_ANY 0
%define SOCK_STREAM 1
%define AF_INET 2
%define SO_REUSEADDR 4
%define SO_REUSEPORT 0x0200
%define SOL_SOCKET 0xFFFF
%define O_RDONLY 0
%include "helper.s"

; decimal
; 3   user_ssize_t read(int fd, user_addr_t cbuf, user_size_t nbyte);
; 4   user_ssize_t write(int fd, user_addr_t cbuf, user_size_t nbyte);
; 5   int open(user_addr_t path, int flags, int mode);
; 6   int close(int fd);
; 30  int accept(int s, caddr_t name, socklen_t	*anamelen);
; 97  int socket(int domain, int type, int protocol);
; 104 int bind(int s, caddr_t name, socklen_t namelen);
; 105 int setsockopt(int s, int level, int name, caddr_t val, socklen_t valsize);
; 106 int listen(int s, int backlog);

global start
section .text
start:

;create server socket
mov eax, 97
push dword 0
push dword SOCK_STREAM
push dword AF_INET
sub esp, 4
int 0x80
add esp, 0x10
mov [sfd], eax

;test for creation and exit on error
cmp eax, dword 0
je exit
%ifdef VERBOSE
mov eax, fdMsg
call printString
mov eax, dword [sfd]
call printReg
%endif

;set sock opt so i can reuse port
mov eax, 105
push dword 4
push dword optVal
push dword SO_REUSEADDR
push dword SOL_SOCKET
mov ebx, dword [sfd]
push ebx
sub esp, 0x4
int 0x80
add esp, 0x18
cmp eax, dword 0
je setsockoptSuccess
mov eax, setsockoptFailMsg
call printString
jmp exitClose
setsockoptSuccess:
%ifdef VERBOSE
mov eax, setsockoptSuccessMsg
call printString
%endif
;zero servaddr
mov eax, servaddr
xor ebx, ebx
mov ecx, 0x10
call memset

;set servaddr values
mov [servaddr.sin_len], byte 0x10
mov [servaddr.sin_family], byte AF_INET
mov eax, PORT
call htons
mov [servaddr.sin_port], ax
mov eax, INADDR_ANY
call htonl
mov [servaddr.sin_addr], eax

;bind
push dword 0x10
push dword servaddr
mov eax, dword [sfd]
push eax
mov eax, 104
sub esp, 4
int 0x80
add esp, 0x10
cmp eax, dword 0
je exitBind
;fail
mov eax, bindFailMsg
call printString
jmp exitClose
;success
exitBind:
;mov eax, bindSuccessMsg
;call printString

;listen
push dword 3
push dword [sfd]
mov eax, dword 106
sub esp, 8
int 0x80
add esp, 0x10
cmp eax, dword 0
je exitListen
mov eax, listenFailureMsg
call printString
jmp exit
exitListen:
mov eax, listenSuccessMsg
call printString

%ifdef NUM_REQUESTS
xor ecx, ecx
mov [numReqs], cl
%endif
acceptLoop:
%ifdef NUM_REQUESTS
mov cl, byte [numReqs]
inc cl
mov [numReqs], cl
%endif

;zero cfd
mov [cliaddr_len], dword 0x10
mov eax, cliaddr
xor ebx, ebx
mov ecx, dword [cliaddr_len]
call memset

;accept
mov ecx, dword [sfd]
mov eax, 30
push dword cliaddr_len
push dword cliaddr
push dword ecx
sub esp, 4
int 0x80
add esp, 0x10
mov [cfd], eax

;zero buffer
push eax
mov eax, sockBuf
mov ebx, 0
mov ecx, BUF_SIZE
call memset
pop eax
;read data
push dword BUF_SIZE-1
push dword sockBuf
push dword eax
sub esp, 4
mov eax, 3
int 0x80
add esp, 0x10

mov [nread], eax

;print data
%ifdef VERBOSE
mov eax, dword sockBuf
call printString
%endif
;zero resourcePath
mov eax, resourcePath
xor ebx, ebx
mov ecx, 128
call memset
dec eax
mov [eax], byte 0x2E

;get to start of resourcePath
mov eax, sockBuf
toStartOfPath:
mov bl, byte [eax]
cmp bl, byte ' '
je exitToStartOfPath
inc eax
jmp toStartOfPath
exitToStartOfPath:

;copy requested path to resourcePath
xor ecx, ecx
inc eax
mov edx, resourcePath
copyRequestedPath:
mov bl, byte [eax]
cmp bl, byte ' '
je exitCopyRequestedPath
cmp ecx, 127
jnl exitCopyRequestedPath
mov [edx], bl
inc eax
inc edx
jmp copyRequestedPath
exitCopyRequestedPath:

;print requested path
mov eax, resourcePath
dec eax
%ifdef VERBOSE
call printString
call printEndl
%endif
;check for quit command
push eax
mov ebx, quitURL
call strcmp
cmp eax, 1
je exitClientClose
pop eax

;open requested resource
push dword O_RDONLY
push dword 0
push eax
mov eax, 5
sub esp, 4
int 0x80
add esp, 0x10
mov [resourcefd], eax

;zero header buf
mov eax, headerBuf
xor ebx, ebx
mov ecx, HEADER_BUF_SIZE
call memset

;test for error on file open
mov eax, [resourcefd]
cmp eax, dword 5; this NEEDS to change later but it works for now
jne errorOpeningFile


;For Debugging/Development Purposes
%ifdef VERBOSE
call printReg
%endif
;Read file
mov eax, dword [resourcefd]
push dword BUF_SIZE
push dword resourceBuf
push eax
sub esp, 4
mov eax, 3
int 0x80
add esp, 0x10

mov [nread], eax

;Header time
mov eax, headerBuf
mov ebx, httpOKCharArray
mov ecx, 16
call memcpy
add eax, 16
mov ebx, httpHeaderContentLengthLabel
mov ecx, 16
call memcpy
add eax, 16
push eax
mov eax, dword [nread]
call uintToStr
mov ecx, eax
pop eax
mov ebx, uintToStrRet
call memcpy
add eax, ecx
mov [eax], byte 0x0A
;ending headers
inc eax
mov [eax], byte 0x0A
inc eax
sub eax, dword headerBuf
mov [headerLength], eax

%ifdef VERBOSE
;print headers
mov ecx, dword [headerLength]
push ecx
push dword headerBuf
mov ecx, dword 1
push ecx
mov eax, 4
sub esp, 4
int 0x80
add esp, 0x10
%endif

;send headers
mov ecx, dword [headerLength]
push ecx
push dword headerBuf
mov ecx, dword [cfd]
push ecx
mov eax, 4
sub esp, 4
int 0x80
add esp, 0x10

%ifdef VERBOSE
;print data
mov ecx, dword [nread]
push ecx
push dword resourceBuf
mov ebx, dword 1
push ebx
sub esp, 4
mov eax, 4
int 0x80
add esp, 0x10
%endif
;send data
mov ecx, dword [nread]
push ecx
push dword resourceBuf
mov ebx, dword [cfd]
push ebx
sub esp, 4
mov eax, 4
int 0x80
add esp, 0x10

;close resource
mov ebx, dword [resourcefd]
mov eax, 6
push ebx
sub esp, 4
int 0x80
add esp, 8


;close client
errorOpeningFile:
mov eax, dword [cfd]
push eax
mov eax, 6
sub esp, 0x0C
int 0x80
add esp, 0x10

%ifdef NUM_REQUESTS
mov cl, byte [numReqs]
and cl, 0xFF
cmp ecx, dword NUM_REQUESTS
jl acceptLoop
jmp exitClose
%else
jmp acceptLoop
%endif

exitClientClose:
mov eax, quitMsg
call printString
mov eax, dword [cfd]
push eax
mov eax, 6
sub esp, 0x0C
int 0x80
add esp, 0x10

;close server socket
exitClose:
push dword [sfd]
sub esp, 0x0C
mov eax, 6
int 0x80
add esp, 0x10
exit:
  push dword 0
  sub esp, 4
  mov eax, 1
  int 0x80

section .data
quitURL: db './quit', 0
quitMsg: db 'Quitting...', 0x0A, 0
filePath: db './index.html',0
fdMsg: db 'Parent fd: ', 0
bindSuccessMsg: db 'Bind Success', 0x0A, 0
bindFailMsg: db 'Bind Failure', 0x0A, 0
listenSuccessMsg: db 'Listen Success', 0x0A, 0
listenFailureMsg: db 'Listen Failure', 0x0A, 0
setsockoptFailMsg: db 'setsockopt Failure', 0x0A, 0
setsockoptSuccessMsg: db 'setsockopt Success', 0x0A, 0
httpOKCharArray: db 'HTTP/1.1 200 OK', 0xA ; len = 16
httpHeaderContentLengthLabel: db 'Content-Length: ' ; len = 16
optVal: dd 1
section .bss
sfd: RESD 1
cfd: RESD 1
sockBuf: RESB BUF_SIZE
resourceBuf: RESB BUF_SIZE
nread: RESD 1
headerLength: RESD 1
headerBuf: RESB HEADER_BUF_SIZE
RESB 1
resourcePath: RESB 128
resourcefd: RESD 1
%ifdef NUM_REQUESTS
numReqs: RESB 1
%endif
cliaddr_len: RESD 1
; struct sockaddr_in
servaddr:
  .sin_len: RESB 1
  .sin_family: RESB 1
  .sin_port: RESW 1
  .sin_addr: RESD 1
  .sin_zero: RESB 8
cliaddr:
  .sin_len: RESB 1
  .sin_family: RESB 1
  .sin_port: RESW 1
  .sin_addr: RESD 1
  .sin_zero: RESB 8
