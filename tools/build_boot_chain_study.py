from docx import Document
from docx.shared import Inches, Pt, RGBColor
from docx.enum.text import WD_ALIGN_PARAGRAPH
from docx.enum.table import WD_TABLE_ALIGNMENT, WD_CELL_VERTICAL_ALIGNMENT
from docx.oxml import OxmlElement
from docx.oxml.ns import qn

OUT=r"D:\Oranges\docs\OrangeOS答辩学习01-启动链路.docx"
BLUE="2E74B5"; DARK="1F4D78"; INK="0B2545"; LIGHT="E8EEF5"; PALE="F4F6F9"; GRAY="5B6573"
def ft(r,z=11,b=False,c="000000",name="Microsoft YaHei"):
    r.font.name=name; rp=r._element.get_or_add_rPr(); rp.rFonts.set(qn("w:eastAsia"),name); rp.rFonts.set(qn("w:ascii"),"Calibri" if name!="Consolas" else name); rp.rFonts.set(qn("w:hAnsi"),"Calibri" if name!="Consolas" else name); r.font.size=Pt(z); r.bold=b; r.font.color.rgb=RGBColor.from_string(c); return r
def h(d,t,l=1): d.add_heading(t,level=l)
def p(d,t): x=d.add_paragraph(); x.paragraph_format.space_after=Pt(6); ft(x.add_run(t)); return x
def bl(d,t): x=d.add_paragraph(style="List Bullet"); x.paragraph_format.space_after=Pt(4); ft(x.add_run(t),10.5); return x
def code(d,t):
    x=d.add_paragraph(); x.paragraph_format.left_indent=Inches(.25); x.paragraph_format.right_indent=Inches(.25); x.paragraph_format.space_after=Pt(7); pr=x._p.get_or_add_pPr(); s=OxmlElement("w:shd"); s.set(qn("w:fill"),"F2F4F7"); pr.append(s)
    for i,line in enumerate(t.splitlines()):
        if i: x.add_run().add_break()
        ft(x.add_run(line),9.2,False,INK,"Consolas")
def box(d,label,text):
    t=d.add_table(rows=1,cols=1); t.style="Table Grid"; pr=t.cell(0,0)._tc.get_or_add_tcPr(); s=OxmlElement("w:shd"); s.set(qn("w:fill"),PALE); pr.append(s); x=t.cell(0,0).paragraphs[0]; x.paragraph_format.space_after=Pt(0); ft(x.add_run(label+"  "),10.5,True,DARK); ft(x.add_run(text),10.5); d.add_paragraph().paragraph_format.space_after=Pt(0)
def table(d,heads,rows,widths):
    t=d.add_table(rows=1,cols=len(heads)); t.style="Table Grid"; t.autofit=False; t.alignment=WD_TABLE_ALIGNMENT.CENTER
    for i,v in enumerate(heads):
        c=t.rows[0].cells[i]; sh=OxmlElement("w:shd"); sh.set(qn("w:fill"),LIGHT); c._tc.get_or_add_tcPr().append(sh); x=c.paragraphs[0]; x.paragraph_format.space_after=Pt(0); ft(x.add_run(v),10,True,DARK)
    for row in rows:
        cs=t.add_row().cells
        for i,v in enumerate(row): x=cs[i].paragraphs[0]; x.paragraph_format.space_after=Pt(0); ft(x.add_run(v),9.5); cs[i].vertical_alignment=WD_CELL_VERTICAL_ALIGNMENT.CENTER; cs[i].width=Inches(widths[i])
    d.add_paragraph().paragraph_format.space_after=Pt(0)

d=Document(); s=d.sections[0]; s.page_width=Inches(8.5); s.page_height=Inches(11); s.top_margin=s.bottom_margin=s.left_margin=s.right_margin=Inches(1); s.header_distance=s.footer_distance=Inches(.492)
st=d.styles["Normal"]; st.font.name="Microsoft YaHei"; st._element.rPr.rFonts.set(qn("w:eastAsia"),"Microsoft YaHei"); st.font.size=Pt(11); st.paragraph_format.space_after=Pt(6); st.paragraph_format.line_spacing=1.25
for n,z,b,a,c in [("Heading 1",16,18,10,BLUE),("Heading 2",13,14,7,BLUE),("Heading 3",12,10,5,DARK)]:
    st=d.styles[n]; st.font.name="Microsoft YaHei"; st._element.rPr.rFonts.set(qn("w:eastAsia"),"Microsoft YaHei"); st.font.size=Pt(z); st.font.bold=True; st.font.color.rgb=RGBColor.from_string(c); st.paragraph_format.space_before=Pt(b); st.paragraph_format.space_after=Pt(a); st.paragraph_format.keep_with_next=True
st=d.styles["List Bullet"]; st.font.name="Microsoft YaHei"; st._element.rPr.rFonts.set(qn("w:eastAsia"),"Microsoft YaHei"); st.font.size=Pt(10.5); st.paragraph_format.space_after=Pt(4); st.paragraph_format.line_spacing=1.25
x=s.header.paragraphs[0]; x.alignment=WD_ALIGN_PARAGRAPH.RIGHT; ft(x.add_run("ORANGEOS答辩学习｜01 启动链路"),8.5,False,GRAY)
x=s.footer.paragraphs[0]; x.alignment=WD_ALIGN_PARAGRAPH.CENTER; ft(x.add_run("BIOS → Boot Sector → Loader → Kernel"),8.5,False,GRAY)

for _ in range(4): d.add_paragraph()
x=d.add_paragraph(); x.alignment=WD_ALIGN_PARAGRAPH.CENTER; ft(x.add_run("ORANGEOS DEFENSE STUDY 01"),10,True,BLUE)
x=d.add_paragraph(); x.alignment=WD_ALIGN_PARAGRAPH.CENTER; x.paragraph_format.space_before=Pt(12); ft(x.add_run("BIOS、引导扇区、Loader与内核入口"),24,True,INK)
x=d.add_paragraph(); x.alignment=WD_ALIGN_PARAGRAPH.CENTER; ft(x.add_run("从计算机上电到32位内核接管CPU"),14,False,DARK)
x=d.add_paragraph(); x.alignment=WD_ALIGN_PARAGRAPH.CENTER; x.paragraph_format.space_before=Pt(90); ft(x.add_run("概念｜源码｜执行流程｜模块关系｜答辩追问"),11,True,BLUE)
d.add_page_break()

h(d,"一、本节要回答的问题",1)
box(d,"核心问题","计算机上电后，OrangeOS的第一条代码如何获得CPU控制权，并经过哪些步骤进入32位内核？")
code(d,"BIOS → 0x7C00 → Boot Sector → 0x9000 → Loader\n→ LBA 2 → 0x10000 → CR0.PE → 保护模式 → Kernel _start")

h(d,"二、四个角色及其职责",1)
table(d,["组件","职责","交给下一阶段的内容"],[("BIOS","硬件自检、寻找启动设备、读取首扇区","在0x7C00开始执行Boot Sector"),("Boot Sector","通过BIOS磁盘服务加载Loader","在0x9000开始执行Loader"),("Loader","探测内存、加载内核、开启A20、进入保护模式","跳转到0x10000的32位内核"),("Kernel _start","初始化GDT/TSS、IDT、PIC/PIT、内存、分页、文件系统与调度","开启中断并进入Shell/空闲循环")],[1.25,2.65,2.6])

h(d,"三、BIOS如何启动OrangeOS",1)
p(d,"计算机上电后先执行主板固件中的BIOS。BIOS进行POST自检、初始化基础硬件并寻找启动设备，然后读取磁盘第一个512字节扇区，检查末尾是否为55 AA。有效时把扇区加载到物理地址0x7C00并跳转执行。")
box(d,"关键区别","boot.asm中的 org 0x7C00只告诉NASM按该地址计算标签；真正把代码加载到0x7C00的是BIOS。")

h(d,"四、Boot Sector：第一阶段引导",1)
h(d,"1. 初始化实模式段寄存器",2)
code(d,"org 0x7C00\nmov ax,0\nmov ds,ax\nmov es,ax")
p(d,"CPU此时处于16位实模式，物理地址按“段值×16+偏移”计算，因此0000:9000就是物理0x9000。")
h(d,"2. 读取Loader",2)
code(d,"mov ah,0x02       ; BIOS读取扇区\nmov al,1          ; 读取1个扇区\nmov ch,0\nmov cl,2          ; CHS第2扇区，即LBA 1\nmov dh,0\nmov dl,0x80       ; 第一块硬盘\nmov bx,0x9000\nint 0x13")
p(d,"读取成功后执行 jmp 0x0000:0x9000，把CS:IP设置为0000:9000，CPU开始执行Loader。若CF被置位，则显示字符E并停机。")
h(d,"3. 512字节与启动签名",2)
code(d,"times 510-($-$$) db 0\ndw 0xAA55")
p(d,"前一条将文件填充到510字节，后一条写入16位启动签名。x86小端存储使磁盘最后两个字节呈现55 AA。")

h(d,"五、为什么需要第二阶段Loader",1)
p(d,"Boot Sector只有512字节，还要包含读取代码、错误处理和启动签名，无法容纳内存探测、40 KiB内核读取、视频播放、A20控制、GDT和模式切换。因此第一阶段只负责定位Loader，复杂工作由Loader完成。")
box(d,"设计原则","Boot Sector追求最小和可靠；Loader负责准备内核运行环境；Kernel负责长期管理系统。")

h(d,"六、Loader的执行流程",1)
h(d,"1. 建立实模式栈",2)
code(d,"cli\nxor ax,ax\nmov ds,ax\nmov es,ax\nmov ss,ax\nmov sp,0x7C00\nsti")
p(d,"修改SS:SP前先关闭中断，避免中断在栈只设置一半时进入。")
h(d,"2. 获取物理内存地图",2)
p(d,"Loader通过INT 12h获取传统内存容量，通过INT 15h/E820获取最多16条物理内存记录。记录数量保存在0x0504，记录内容从0x0508开始，Kernel的物理页管理器随后读取这些数据。")
h(d,"3. 加载Kernel",2)
code(d,"AH = 0x42          BIOS扩展磁盘读取\n起始LBA = 2\n读取数量 = 80个扇区\n目标 = 1000:0000 = 物理0x10000")
p(d,"80×512=40960字节，也就是40 KiB。Loader加载地址、Makefile链接地址和最终跳转地址都必须是0x10000。")
h(d,"4. 播放启动动画",2)
p(d,"Loader在实模式使用BIOS设置VGA Mode 13h，从LBA 128起读取40帧，每帧64000字节，以约10 FPS播放4秒，最后恢复80×25文本模式。")
h(d,"5. 开启A20",2)
p(d,"Loader通过端口0x92开启A20地址线，取消1 MiB地址回绕，使内核可以可靠访问1 MiB以上内存。")
h(d,"6. 建立临时GDT并进入保护模式",2)
code(d,"lgdt [gdt_descriptor]\nmov eax,cr0\nor eax,1           ; CR0.PE=1\nmov cr0,eax\njmp dword CODE_SELECTOR:protected_mode_entry")
p(d,"临时GDT包含空描述符、Ring 0代码段和Ring 0数据段，采用Base=0的平坦模型。设置PE后必须执行远跳转，以加载新的CS并刷新CPU预取队列。")
h(d,"7. 跳转Kernel",2)
code(d,"[BITS 32]\nprotected_mode_entry:\n    mov ax,DATA_SELECTOR\n    mov ds,ax\n    mov ss,ax\n    mov esp,0x90000\n    jmp dword CODE_SELECTOR:0x10000")
p(d,"此时CPU已经在32位保护模式中。代码段Base为0，所以偏移0x10000对应线性和物理地址0x10000。")

h(d,"七、磁盘镜像与内存地址的对应",1)
table(d,["磁盘位置","内容","运行时内存位置"],[("LBA 0","Boot Sector","BIOS加载到0x7C00"),("LBA 1","Loader","Boot Sector加载到0x9000"),("LBA 2～81","40 KiB Kernel","Loader加载到0x10000"),("LBA 82","OrangeFS主目录","内核按需读取"),("LBA 83～114","OrangeFS数据区","内核按需读取"),("LBA 115","OrangeFS备份目录","内核按需读取"),("LBA 128起","启动视频帧","Loader读取到0x20000后复制到VGA显存")],[1.5,2.25,2.75])
box(d,"地址一致性","Makefile用 -Ttext 0x10000链接Kernel；Loader把Kernel加载到0x10000；保护模式入口最终也跳到0x10000。三者不一致会导致函数、标签和全局数据地址错误。")

h(d,"八、Kernel _start接管系统",1)
p(d,"Kernel入口位于kernel/kernel32.asm的_start。Loader已经完成内核装载、A20、临时GDT、保护模式和32位栈，但完整内核环境尚未建立。")
code(d,"cli\n→ 重载段寄存器与ESP\n→ gdt_init32\n→ clear_screen32\n→ idt_init32\n→ pic_init32\n→ pit_init32\n→ memory_init32\n→ paging_init32\n→ usermode_init32\n→ heap_init32\n→ fs_init32\n→ process_init32\n→ sti\n→ hlt / input_poll32")
p(d,"进入保护模式后，Kernel逐步用自己的描述符、中断和驱动替代BIOS服务。初始化完成后，CPU在HLT中等待时钟或键盘中断，Shell输入在普通内核上下文中解析。")

h(d,"九、四个阶段之间的关系",1)
code(d,"BIOS：我知道怎样找到磁盘上的第一段代码\n  ↓\nBoot Sector：我空间很小，只负责找到Loader\n  ↓\nLoader：我准备内存信息、加载Kernel并进入32位模式\n  ↓\nKernel：我建立完整中断、内存、调度、文件系统和交互环境")
p(d,"整个过程也是逐步摆脱BIOS依赖的过程：Boot Sector和Loader在实模式使用BIOS磁盘、显示和内存服务；进入保护模式后，Kernel建立自己的中断系统和设备驱动，日常运行不再依靠BIOS。")

h(d,"十、答辩标准回答",1)
box(d,"可直接回答","计算机上电后首先执行BIOS。BIOS完成硬件自检，并把磁盘第一个扇区加载到物理地址0x7C00。这个扇区是OrangeOS的Boot Sector，它通过INT 13h把第二阶段Loader加载到0x9000，然后跳转执行。Loader使用E820获取物理内存布局，把40 KiB内核从LBA 2加载到0x10000，同时开启A20并建立临时GDT。之后Loader设置CR0的PE位，通过远跳转进入32位保护模式，初始化32位段寄存器和栈，最后跳转到0x10000的内核入口。Kernel接管CPU后，再初始化正式GDT和TSS、IDT、PIC、PIT、分页、内存管理、文件系统和进程调度，最后开启中断并进入Shell。")

h(d,"十一、高频追问",1)
qs=[("org 0x7C00是否负责加载代码？","不是。org只影响汇编器地址计算，真正加载到0x7C00的是BIOS。"),("为什么Boot Sector必须512字节？","传统BIOS读取一个启动扇区，扇区为512字节，末尾还必须保留55 AA签名。"),("为什么采用两阶段引导？","第一阶段空间太小，Loader需要承担E820、内核加载、A20、GDT和保护模式切换。"),("Loader为什么位于0x9000？","这是项目选择的低内存安全区域，避开0x7C00的Boot Sector，同时便于实模式访问。"),("Kernel为什么位于0x10000？","避开低地址引导区域且实模式可加载；链接、加载和跳转地址统一。"),("为什么Loader能用BIOS而Kernel通常不用？","Loader仍处于实模式；进入保护模式后，Kernel需要自己的中断和驱动。"),("CR0.PE=1后为什么远跳转？","用于装载保护模式CS并刷新CPU预取队列。"),("临时GDT和正式GDT的区别？","临时GDT只含Ring 0代码/数据段；正式GDT还含Ring 3段和TSS。")]
for i,(q,a) in enumerate(qs,1):
    x=d.add_paragraph(); x.paragraph_format.keep_with_next=True; x.paragraph_format.space_before=Pt(6); x.paragraph_format.space_after=Pt(2); ft(x.add_run(f"{i}. {q}"),10.5,True,DARK); x=d.add_paragraph(); x.paragraph_format.space_after=Pt(5); ft(x.add_run("答："),10.5,True,BLUE); ft(x.add_run(a),10.5)

h(d,"十二、学习验收",1)
for q in ["能否不看资料画出BIOS到Kernel的启动链？","能否解释0x7C00、0x9000和0x10000分别是什么？","能否说明CHS第2扇区与LBA 1的关系？","能否解释org与真正加载地址的区别？","能否解释为什么需要A20、GDT、CR0.PE和远跳转？","能否说明Loader传给Kernel的E820数据放在哪里？","能否解释为什么链接地址、加载地址、跳转地址必须一致？"]: bl(d,q)

d.core_properties.title="OrangeOS答辩学习01：启动链路"; d.core_properties.subject="BIOS、Boot Sector、Loader与Kernel入口"; d.core_properties.author="OrangeOS项目组"; d.save(OUT); print(OUT)
