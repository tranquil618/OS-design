from pathlib import Path
from reportlab.lib import colors
from reportlab.lib.enums import TA_CENTER
from reportlab.lib.pagesizes import A4
from reportlab.lib.styles import getSampleStyleSheet, ParagraphStyle
from reportlab.lib.units import mm
from reportlab.pdfbase import pdfmetrics
from reportlab.pdfbase.ttfonts import TTFont
from reportlab.platypus import SimpleDocTemplate, Paragraph, Spacer, PageBreak, Table, TableStyle, HRFlowable

OUT = Path(r"D:\Oranges\output\pdf")
OUT.mkdir(parents=True, exist_ok=True)
PDF = OUT / "OrangeOS-Ring3核心代码定位与答辩讲解.pdf"

pdfmetrics.registerFont(TTFont("CN", r"C:\Windows\Fonts\msyhl.ttc"))
pdfmetrics.registerFont(TTFont("CNB", r"C:\Windows\Fonts\simhei.ttf"))
pdfmetrics.registerFont(TTFont("MONO", r"C:\Windows\Fonts\consola.ttf"))

NAVY=colors.HexColor("#17365D"); BLUE=colors.HexColor("#2E75B6")
LIGHT=colors.HexColor("#EAF1F8"); PALE=colors.HexColor("#F6F8FA"); GRAY=colors.HexColor("#687386")
s=getSampleStyleSheet()
s.add(ParagraphStyle(name="B",fontName="CN",fontSize=9.6,leading=15,spaceAfter=5,textColor=colors.HexColor("#202B3A")))
s.add(ParagraphStyle(name="T",fontName="CNB",fontSize=28,leading=38,alignment=TA_CENTER,textColor=NAVY))
s.add(ParagraphStyle(name="S",fontName="CN",fontSize=13,leading=20,alignment=TA_CENTER,textColor=BLUE))
s.add(ParagraphStyle(name="H1C",fontName="CNB",fontSize=17,leading=23,textColor=NAVY,spaceBefore=8,spaceAfter=8,keepWithNext=True))
s.add(ParagraphStyle(name="H2C",fontName="CNB",fontSize=12.5,leading=18,textColor=BLUE,spaceBefore=7,spaceAfter=5,keepWithNext=True))
s.add(ParagraphStyle(name="CodeC",fontName="MONO",fontSize=7.7,leading=11.2,leftIndent=7,rightIndent=7,borderPadding=7,backColor=colors.HexColor("#F1F4F7"),spaceBefore=4,spaceAfter=7))
s.add(ParagraphStyle(name="ChainC",fontName="CNB",fontSize=9,leading=15,borderPadding=7,backColor=LIGHT,textColor=NAVY,spaceBefore=4,spaceAfter=7))
s.add(ParagraphStyle(name="SmallC",fontName="CN",fontSize=8,leading=12,textColor=colors.HexColor("#334155")))

def p(t,st="B"): return Paragraph(t.replace("\n","<br/>"),s[st])
def code(t): return p(t.replace("&","&amp;").replace("<","&lt;").replace(">","&gt;").replace(" ","&nbsp;"),"CodeC")
def bullets(xs): return [p("• "+x) for x in xs]
def table(h,rows,w):
    data=[[p(x,"SmallC") for x in h]]+[[p(str(x),"SmallC") for x in r] for r in rows]
    t=Table(data,colWidths=w,repeatRows=1)
    t.setStyle(TableStyle([("BACKGROUND",(0,0),(-1,0),NAVY),("TEXTCOLOR",(0,0),(-1,0),colors.white),
        ("GRID",(0,0),(-1,-1),.35,colors.HexColor("#BCC8D4")),("ROWBACKGROUNDS",(0,1),(-1,-1),[colors.white,PALE]),
        ("VALIGN",(0,0),(-1,-1),"MIDDLE"),("LEFTPADDING",(0,0),(-1,-1),5),("RIGHTPADDING",(0,0),(-1,-1),5),
        ("TOPPADDING",(0,0),(-1,-1),4),("BOTTOMPADDING",(0,0),(-1,-1),4)])); return t

def hf(c,d):
    c.saveState()
    if d.page>1:
        c.setFont("CN",7.5); c.setFillColor(GRAY)
        c.drawString(18*mm,12*mm,"OrangeOS Ring 3核心代码定位与答辩讲解")
        c.drawRightString(192*mm,12*mm,str(d.page)); c.setStrokeColor(colors.HexColor("#D8DEE7")); c.line(18*mm,16*mm,192*mm,16*mm)
    c.restoreState()

st=[]
st += [Spacer(1,38*mm),p("OrangeOS v1.0","S"),Spacer(1,8*mm),p("Ring 3核心代码定位<br/>与答辩讲解","T"),
       HRFlowable(width="58%",thickness=1.2,color=BLUE,spaceBefore=8*mm,spaceAfter=9*mm),
       p("用户页面｜页表权限｜用户现场｜iretd｜TSS｜int 0x80｜页故障｜资源回收","S"),
       Spacer(1,45*mm),p("项目路径：D:\\Oranges<br/>核心执行链代码导读","S"),PageBreak()]

st += [p("阅读导航与完整链路","H1C"),
       p("本手册对应答辩回答“我印象最深的是Ring 3用户态、分页保护与系统调用的完整连接”。现场看代码时，按下列顺序打开文件。"),
       table(["顺序","代码位置","职责"],[
           ["1","kernel/usermode32.asm:42","分配并映射用户三页"],
           ["2","kernel/paging32.asm:87","建立带User权限的PDE/PTE"],
           ["3","kernel/process32.asm:304","构造PID4的52 B用户现场"],
           ["4","kernel/usermode32.asm:274","同步路径通过iretd进入Ring3"],
           ["5","kernel/gdt32.asm:16","建立TSS的SS0/ESP0"],
           ["6","kernel/idt32.asm:41","安装DPL3的int 0x80门"],
           ["7","kernel/syscall32.asm:30","调用号分派和用户指针校验"],
           ["8","kernel/idt32.asm:115","区分用户/内核页故障"],
           ["9","kernel/process32.asm:392","FAULTED/EXITED与资源回收"],
       ],[13*mm,68*mm,83*mm]),
       p("完整执行链","H2C"),
       p("OrangeFS读取OEX2 → 分配物理页 → 建立用户映射 → 构造PID4现场 → 调度器切换ESP → iretd进入Ring3 → int 0x80 → TSS换到Ring0栈 → 校验并执行 → exit或#PF → 释放三页 → 调度下一任务","ChainC"),
       p("一句话总述","H2C"),
       p("usermode_prepare32准备用户地址空间，process_spawn_user32构造可由popad/iretd恢复的现场，IDT和TSS提供受控跨级入口，isr_syscall32验证并执行服务，页故障或退出最后进入公共终止路径回收资源。"),PageBreak()]

st += [p("1　用户代码、数据和栈页面","H1C"),
       p("文件：kernel/usermode32.asm；函数：usermode_prepare32；起始行：42。"),
       p("它连续申请三个4 KiB物理页，并分别映射到固定用户虚拟地址。分配物理页和建立虚拟映射是两个不同动作。"),
       table(["用户区域","虚拟地址","物理页来源"],[["代码页","0x40000000","memory_alloc_page32"],["数据页","0x40001000","memory_alloc_page32"],["栈页","0x40002000；栈顶0x40003000","memory_alloc_page32"]],[38*mm,62*mm,64*mm]),
       code("call memory_alloc_page32\nmov [user_code_phys],eax\nmov ebx,eax\nmov eax,USER_CODE\ncall paging_map_user32\n\ncall memory_alloc_page32\nmov [user_data_phys],eax\nmov eax,USER_DATA\ncall paging_map_user32\n\ncall memory_alloc_page32\nmov [user_stack_phys],eax\nmov eax,USER_STACK_TOP-4096\ncall paging_map_user32"),
       p("失败路径会调用usermode_release32清理已经成功的部分，避免准备过程半途失败后持续占用页面。"),
       p("现场讲解词","H2C"),
       p("这里不是直接把用户代码放进任意内存，而是先从物理页分配器取得三个4 KiB页面，再分别映射到固定的用户代码、数据和栈地址。用户任务运行时使用页数增加3，退出或故障后应回到原值。"),
       p("释放代码：kernel/usermode32.asm:100","H2C"),
       code("mov eax,USER_CODE\ncall paging_unmap_user32\nmov eax,[user_code_phys]\ncall memory_free_page32\n; data与stack重复同样流程"),PageBreak()]

st += [p("2　用户页表权限与TLB","H1C"),
       p("文件：kernel/paging32.asm；函数：paging_map_user32；起始行：87。"),
       p("32位线性地址按10位页目录索引、10位页表索引和12位页内偏移拆分。"),
       p("虚拟地址[31:22] → PDE索引；[21:12] → PTE索引；[11:0] → 4 KiB页内偏移","ChainC"),
       code("mov edx,esi\nshr edx,22              ; page directory index\n...\nmov eax,esi\nshr eax,12\nand eax,0x3FF           ; page table index"),
       p("PDE与PTE都设置0x07：Present、Writable、User。任意一级没有User位，Ring 3访问都会被拒绝。"),
       code("or eax,0x07\nmov [ebx+edx*4],eax     ; PDE\n...\nor edi,0x07\nmov [ecx+eax*4],edi     ; PTE\ninvlpg [esi]"),
       p("invlpg使该虚拟页的旧TLB缓存失效，否则CPU可能继续使用修改前的地址转换。解除映射位于paging_unmap_user32（148行），它清零PTE后同样执行invlpg。"),
       p("现场讲解词","H2C"),
       p("这一段体现分页同时完成地址转换和保护。物理页地址写入PTE，低位0x07赋予用户读写权限。映射变化后必须刷新TLB，保证CPU不再使用旧的缓存映射。"),PageBreak()]

st += [p("3　构造可调度的Ring 3现场","H1C"),
       p("文件：kernel/process32.asm；函数：process_spawn_user32；起始行：304。"),
       p("PID4的现场位于专用内核栈。代码先清空13个dword，即52 B，再填入中断恢复所需字段。"),
       table(["偏移","字段","值/含义"],[["0-31","pushad通用寄存器现场","8个dword"],["+32","EIP","用户入口，通常0x40000000"],["+36","CS","0x1B，RPL=3"],["+40","EFLAGS","0x202，IF=1"],["+44","用户ESP","0x40003000"],["+48","用户SS","0x23，RPL=3"]],[22*mm,51*mm,91*mm]),
       code("mov edi,USER_KERNEL_FRAME_TOP-52\nxor eax,eax\nmov ecx,13\nrep stosd\n...\nmov [edi+32],eax\nmov dword [edi+36],0x1B\nmov dword [edi+40],0x00000202\nmov dword [edi+44],USER_STACK_TOP\nmov dword [edi+48],0x23\nmov [PCB_ESP],USER_KERNEL_FRAME_TOP-52\nmov [PCB_STATE],PROCESS_STATE_READY"),
       p("用户帧比同特权级内核中断帧多8 B，因为跨级iretd还要恢复用户ESP和SS。调度器不必逐项复制寄存器，只需切换到PCB保存的ESP，再popad和iretd。"),
       p("现场讲解词","H2C"),
       p("用户态不是修改一个变量，而是提前伪造一份CPU能够合法恢复的跨特权级现场。选择子低两位为3，EFLAGS打开中断，ESP指向用户栈顶；任务被调度后，iretd读取这份现场并真正把CPL切换为3。"),PageBreak()]

st += [p("4　iretd降权与TSS换栈","H1C"),
       p("同步user命令的直接降权代码位于kernel/usermode32.asm:274。"),
       code("mov [kernel_saved_esp],esp\npush dword USER_DS\npush dword USER_STACK_TOP\npushfd\nor dword [esp],0x200\npush dword USER_CS\npush dword USER_CODE\niretd"),
       p("按CPU要求从后向前压入SS、ESP、EFLAGS、CS、EIP。iretd按相反方向弹出，并根据目标CS的RPL=3完成Ring0到Ring3切换。"),
       p("TSS代码位于kernel/gdt32.asm:16","H2C"),
       code("mov dword [tss32+4],TSS_ESP0 ; ESP0\nmov word [tss32+8],KERNEL_DATA ; SS0\nmov word [tss32+102],104       ; 禁止用户I/O端口\n...\nmov ax,TSS_SELECTOR\nltr ax"),
       p("TSS在本项目中不负责软件调度。它的核心作用是当Ring3发生中断、异常或系统调用时，向CPU提供可信的Ring0栈SS0/ESP0。"),
       p("现场讲解词","H2C"),
       p("进入用户态靠iretd恢复五个跨级字段；从用户态重新进入内核时靠TSS换栈。两者方向相反，共同完成安全的特权级往返。"),PageBreak()]

st += [p("5　int 0x80受控入口","H1C"),
       p("系统调用门安装于kernel/idt32.asm:41。"),
       code("mov ebx,0x80\nmov eax,isr_syscall32\ncall set_idt_gate32\nmov byte [idt_table+0x80*8+5],11101110b"),
       p("门属性0xEE表示Present=1、DPL=3、32位中断门。DPL=3是Ring3主动执行int 0x80的必要条件；其他内核门通常DPL=0。"),
       p("调用号分派位于kernel/syscall32.asm:30","H2C"),
       table(["EAX","系统调用"],[["0","get_ticks"],["1","get_free_pages"],["2","get_pid"],["3","exit"],["4","set_result"],["5","write"]],[35*mm,129*mm]),
       code("cmp eax,SYS_GET_TICKS\nje .ticks\n...\ncmp eax,SYS_WRITE\nje .write\nmov eax,0xFFFFFFFF"),
       p("SYS_WRITE验证来源CS、长度上限127、指针加法溢出，以及整个缓冲区是否落在合法用户页范围；随后复制到128 B内核缓冲区再输出。"),
       code("mov eax,[esp+28]\nand eax,3\ncmp eax,3\njne .write_invalid\ncmp ecx,SYS_WRITE_MAX\nja .write_invalid\nmov edx,esi\nadd edx,ecx\njc .write_invalid\n...\nmov edi,syscall_write_buffer\nrep movsb"),
       p("现场讲解词","H2C"),
       p("系统调用门只解决用户是否允许进入内核，真正的安全边界还包括调用号白名单和参数校验。内核不能直接信任用户指针，所以先验证完整范围，再复制到自己的缓冲区。"),PageBreak()]

st += [p("6　页故障隔离和资源回收","H1C"),
       p("页故障入口位于kernel/idt32.asm:115。旧CS的低两位用于判断故障来源。"),
       code("pushad\nmov eax,[esp+40]\nand eax,3\ncmp eax,3\njne .kernel_fault\nmov eax,cr2          ; fault address\nmov ebx,[esp+32]     ; error code\nmov ecx,[esp+36]     ; faulting EIP\ncall process_fault_current32\nmov esp,eax\npopad\niretd"),
       p("Ring3故障进入process_fault_current32；Ring0故障则显示CR2并hlt停机，因为继续运行不再安全。"),
       p("公共终止路径位于kernel/process32.asm:392","H2C"),
       code("process_fault_current32:\n  mov [process_fault_address],eax\n  mov [process_fault_error],ebx\n  mov [process_fault_eip],ecx\n  mov eax,PROCESS_STATE_FAULTED\n\nprocess_terminate_current32:\n  mov [PCB_STATE],eax\n  call usermode_release32\n  ; round-robin find READY\n  mov eax,[next_PCB_ESP]\n  ret"),
       p("返回值不是普通状态码，而是下一任务的内核帧ESP。页故障入口直接切换ESP并iretd，因此不会回到故障指令。正常SYS_EXIT也进入同一公共终止思路，只是状态为EXITED。"),
       p("现场讲解词","H2C"),
       p("分页先阻止非法访问，页故障入口再根据旧CS确认它来自用户态，只终止PID4并回收三页，然后恢复其他任务。这就是用户程序错误不会拖垮整个内核的代码依据。"),PageBreak()]

st += [p("7　现场展示顺序与高频追问","H1C"),
       p("三分钟代码展示","H2C"),
       table(["时间","打开位置","要说的话"],[["0:00-0:35","usermode32.asm:42","三页物理分配与固定虚拟映射"],["0:35-1:10","process32.asm:304","52 B跨级现场与PID4 READY"],["1:10-1:35","gdt32.asm:16","TSS提供可信Ring0栈"],["1:35-2:05","idt32.asm:41 + syscall32.asm:30","DPL3入口、分派和指针校验"],["2:05-2:40","idt32.asm:115","CR2、错误码、旧CS来源判断"],["2:40-3:00","process32.asm:392","FAULTED/EXITED、释放三页、切下一任务"]],[24*mm,61*mm,79*mm]),
       p("高频追问","H2C"),
       *bullets(["为什么不是改变量就进入Ring3？CPU特权级由CS/CPL、门描述符和分页权限共同决定。", "为什么用户帧是52 B？pushad 32 B，加EIP/CS/EFLAGS 12 B，再加跨级ESP/SS 8 B。", "为什么PDE和PTE都要User？x86逐级检查权限，任何一级限制都会拒绝Ring3。", "TSS是否调度任务？不负责；软件调度保存PCB/ESP，TSS只提供跨级SS0/ESP0。", "为什么SYS_WRITE要复制？用户地址不可信，先验证再copy-from-user可以隔离内核输出路径。", "为什么Ring0页故障停机？内核关键状态可能损坏，继续运行风险大于恢复价值。", "怎么证明无泄漏？自动测试检查用户任务前N、运行中N+3、结束后N。"]),
       p("30秒总结","H2C"),
       p("我最印象深的是Ring3、分页和系统调用的连接。内核先分配三个用户物理页并建立User映射，再构造包含EIP、CS、EFLAGS、ESP、SS的52字节现场，通过调度和iretd进入Ring3。用户只能通过DPL3的int 0x80门进入内核，CPU依据TSS切到可信栈，内核验证参数后执行。非法访问触发#PF，只把用户任务标记FAULTED、释放三页并切换其他任务，从而形成权限、服务和故障隔离闭环。"),
       p("代码位置速记","H2C"),
       p("准备页 usermode32:42 → 映射 paging32:87 → 构帧 process32:304 → 降权 usermode32:274 → TSS gdt32:16 → 门 idt32:41 → syscall syscall32:30 → #PF idt32:115 → 回收 process32:392","ChainC")]

doc=SimpleDocTemplate(str(PDF),pagesize=A4,leftMargin=18*mm,rightMargin=18*mm,topMargin=18*mm,bottomMargin=21*mm,
    title="OrangeOS Ring3核心代码定位与答辩讲解",author="OrangeOS Project")
doc.build(st,onFirstPage=hf,onLaterPages=hf)
print(PDF)
