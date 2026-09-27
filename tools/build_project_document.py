from docx import Document
from docx.shared import Inches, Pt, RGBColor
from docx.enum.text import WD_ALIGN_PARAGRAPH
from docx.enum.table import WD_TABLE_ALIGNMENT, WD_CELL_VERTICAL_ALIGNMENT
from docx.enum.section import WD_SECTION_START
from docx.oxml import OxmlElement
from docx.oxml.ns import qn

OUT = r"D:\Oranges\build\OrangeOS项目说明书_base.docx"
BLUE, DARK, INK, LIGHT, PALE, GRAY = "2E74B5", "1F4D78", "0B2545", "E8EEF5", "F4F6F9", "5B6573"

def set_font(run, size=11, bold=False, color="000000", italic=False):
    run.font.name = "Microsoft YaHei"
    rpr = run._element.get_or_add_rPr()
    rpr.rFonts.set(qn("w:eastAsia"), "Microsoft YaHei")
    rpr.rFonts.set(qn("w:ascii"), "Calibri")
    rpr.rFonts.set(qn("w:hAnsi"), "Calibri")
    run.font.size = Pt(size); run.bold = bold; run.italic = italic
    run.font.color.rgb = RGBColor.from_string(color)
    return run

def shade(cell, fill):
    tcPr = cell._tc.get_or_add_tcPr(); shd = tcPr.find(qn("w:shd"))
    if shd is None: shd = OxmlElement("w:shd"); tcPr.append(shd)
    shd.set(qn("w:fill"), fill)

def cell_margins(cell):
    tcPr = cell._tc.get_or_add_tcPr(); tcMar = tcPr.first_child_found_in("w:tcMar")
    if tcMar is None: tcMar = OxmlElement("w:tcMar"); tcPr.append(tcMar)
    for n,v in (("top",100),("bottom",100),("start",120),("end",120)):
        x=OxmlElement("w:"+n); x.set(qn("w:w"),str(v)); x.set(qn("w:type"),"dxa"); tcMar.append(x)

def table_geometry(table, widths):
    table.autofit=False; table.alignment=WD_TABLE_ALIGNMENT.CENTER
    tblPr=table._tbl.tblPr; tblW=tblPr.first_child_found_in("w:tblW")
    tblW.set(qn("w:w"),str(int(sum(widths)*1440))); tblW.set(qn("w:type"),"dxa")
    tblInd=OxmlElement("w:tblInd"); tblInd.set(qn("w:w"),"120"); tblInd.set(qn("w:type"),"dxa"); tblPr.append(tblInd)
    grid=table._tbl.tblGrid
    for child in list(grid): grid.remove(child)
    for w in widths:
        c=OxmlElement("w:gridCol"); c.set(qn("w:w"),str(int(w*1440))); grid.append(c)
    for row in table.rows:
        for i,c in enumerate(row.cells):
            c.width=Inches(widths[i]); c.vertical_alignment=WD_CELL_VERTICAL_ALIGNMENT.CENTER; cell_margins(c)
            tcW=c._tc.get_or_add_tcPr().first_child_found_in("w:tcW")
            tcW.set(qn("w:w"),str(int(widths[i]*1440))); tcW.set(qn("w:type"),"dxa")

def repeat_header(row):
    pr=row._tr.get_or_add_trPr(); x=OxmlElement("w:tblHeader"); x.set(qn("w:val"),"true"); pr.append(x)

def add_table(doc, headers, rows, widths):
    t=doc.add_table(rows=1,cols=len(headers)); t.style="Table Grid"; repeat_header(t.rows[0])
    for i,h in enumerate(headers):
        shade(t.rows[0].cells[i],LIGHT); p=t.rows[0].cells[i].paragraphs[0]; p.paragraph_format.space_after=Pt(0); set_font(p.add_run(h),10,True,DARK)
    for row in rows:
        cells=t.add_row().cells
        for i,val in enumerate(row):
            p=cells[i].paragraphs[0]; p.paragraph_format.space_after=Pt(0); set_font(p.add_run(str(val)),9.5)
    table_geometry(t,widths); doc.add_paragraph().paragraph_format.space_after=Pt(0); return t

def h(doc,text,level=1): return doc.add_heading(text,level=level)
def para(doc,text,bold_lead=None):
    p=doc.add_paragraph(); p.paragraph_format.space_after=Pt(6)
    if bold_lead and text.startswith(bold_lead):
        set_font(p.add_run(bold_lead),11,True,DARK); set_font(p.add_run(text[len(bold_lead):]),11)
    else: set_font(p.add_run(text),11)
    return p
def bullet(doc,text,level=0):
    p=doc.add_paragraph(style="List Bullet" if level==0 else "List Bullet 2"); p.paragraph_format.space_after=Pt(4); set_font(p.add_run(text),10.5); return p
def num(doc,text):
    p=doc.add_paragraph(style="List Number"); p.paragraph_format.space_after=Pt(5); set_font(p.add_run(text),10.5); return p
def code(doc,text):
    p=doc.add_paragraph(); p.paragraph_format.left_indent=Inches(.25); p.paragraph_format.right_indent=Inches(.25); p.paragraph_format.space_before=Pt(3); p.paragraph_format.space_after=Pt(6)
    pPr=p._p.get_or_add_pPr(); shd=OxmlElement("w:shd"); shd.set(qn("w:fill"),"F2F4F7"); pPr.append(shd)
    for i,line in enumerate(text.splitlines()):
        if i: p.add_run().add_break()
        r=p.add_run(line); r.font.name="Consolas"; r._element.get_or_add_rPr().rFonts.set(qn("w:ascii"),"Consolas"); r._element.rPr.rFonts.set(qn("w:hAnsi"),"Consolas"); r.font.size=Pt(9.2); r.font.color.rgb=RGBColor.from_string(INK)
    return p
def callout(doc,label,text):
    t=doc.add_table(rows=1,cols=1); t.style="Table Grid"; shade(t.cell(0,0),PALE); table_geometry(t,[6.5]); p=t.cell(0,0).paragraphs[0]; p.paragraph_format.space_after=Pt(0)
    set_font(p.add_run(label+"  "),10.5,True,DARK); set_font(p.add_run(text),10.5); doc.add_paragraph().paragraph_format.space_after=Pt(0)

doc=Document(); sec=doc.sections[0]
sec.page_width,sec.page_height=Inches(8.5),Inches(11); sec.top_margin=sec.bottom_margin=sec.left_margin=sec.right_margin=Inches(1); sec.header_distance=sec.footer_distance=Inches(.492)
normal=doc.styles["Normal"]; normal.font.name="Microsoft YaHei"; normal._element.rPr.rFonts.set(qn("w:eastAsia"),"Microsoft YaHei"); normal.font.size=Pt(11); normal.paragraph_format.space_after=Pt(6); normal.paragraph_format.line_spacing=1.25
for n,s,b,a,c in [("Heading 1",16,18,10,BLUE),("Heading 2",13,14,7,BLUE),("Heading 3",12,10,5,DARK)]:
    st=doc.styles[n]; st.font.name="Microsoft YaHei"; st._element.rPr.rFonts.set(qn("w:eastAsia"),"Microsoft YaHei"); st.font.size=Pt(s); st.font.bold=True; st.font.color.rgb=RGBColor.from_string(c); st.paragraph_format.space_before=Pt(b); st.paragraph_format.space_after=Pt(a); st.paragraph_format.keep_with_next=True
for n in ["List Bullet","List Bullet 2","List Number"]:
    st=doc.styles[n]; st.font.name="Microsoft YaHei"; st._element.rPr.rFonts.set(qn("w:eastAsia"),"Microsoft YaHei"); st.font.size=Pt(10.5); st.paragraph_format.space_after=Pt(4); st.paragraph_format.line_spacing=1.25

# Running furniture
hp=sec.header.paragraphs[0]; hp.alignment=WD_ALIGN_PARAGRAPH.RIGHT; set_font(hp.add_run("ORANGEOS v1.0｜项目说明书"),8.5,False,GRAY)
fp=sec.footer.paragraphs[0]; fp.alignment=WD_ALIGN_PARAGRAPH.CENTER; set_font(fp.add_run("OrangeOS — x86 教学型操作系统"),8.5,False,GRAY)

# Editorial cover
for _ in range(5): doc.add_paragraph()
p=doc.add_paragraph(); p.alignment=WD_ALIGN_PARAGRAPH.CENTER; set_font(p.add_run("TECHNICAL PROJECT DOCUMENTATION"),10,True,BLUE)
p=doc.add_paragraph(); p.alignment=WD_ALIGN_PARAGRAPH.CENTER; p.paragraph_format.space_before=Pt(14); p.paragraph_format.space_after=Pt(8); set_font(p.add_run("OrangeOS v1.0"),30,True,INK)
p=doc.add_paragraph(); p.alignment=WD_ALIGN_PARAGRAPH.CENTER; set_font(p.add_run("从 BootLoader 到 Ring 3、OrangeFS 与交互式桌面"),15,False,DARK)
p=doc.add_paragraph(); p.alignment=WD_ALIGN_PARAGRAPH.CENTER; p.paragraph_format.space_before=Pt(50); set_font(p.add_run("项目说明书｜架构设计｜模块实现｜构建测试｜阅读导航"),11,True,BLUE)
p=doc.add_paragraph(); p.alignment=WD_ALIGN_PARAGRAPH.CENTER; p.paragraph_format.space_before=Pt(75); set_font(p.add_run("项目路径：D:\\Oranges\n文档版本：1.0｜更新日期：2026-08-21"),10,False,GRAY)
doc.add_page_break()

# Overview and reading guide
h(doc,"文档使用说明",1)
callout(doc,"导航说明","文档交付版将生成可点击目录；每个标题旁包含返回目录链接，并提供页首、页尾快捷导航。建议首次阅读按第 1→4→8→11 章浏览，源码学习则按附录 A 的路径进行。")
h(doc,"推荐阅读路线",2)
add_table(doc,["读者目标","建议章节","阅读结果"],[
    ("快速理解项目","第 1、2、3 章","掌握项目定位、能力边界和总体架构"),
    ("准备答辩","第 3、4、8、11 章","能解释核心机制、创新点与验证方式"),
    ("阅读源码","第 4–9 章、附录 A","按启动、内核、内存、用户态、文件系统逐层定位"),
    ("运行与验收","第 10、11 章","完成构建、QEMU 启动和 16 项发布回归"),
    ("继续开发","第 12 章","了解当前限制与后续演进优先级"),
],[1.45,2.25,2.8])

h(doc,"1 项目概述",1)
h(doc,"1.1 项目背景",2)
para(doc,"OrangeOS 是一个面向 x86 架构的教学型操作系统项目，受《Orange'S：一个操作系统的实现》启发。项目从 BIOS 启动链路开始，自主实现 Boot Sector、Loader 与 32 位内核，并逐步扩展中断、调度、内存、用户态、文件系统和交互应用。")
h(doc,"1.2 项目目标",2)
for x in ["理解 BIOS、引导扇区、Loader 与内核入口之间的启动关系。","掌握 GDT、IDT、PIC、PIT、分页和异常处理等 x86 核心机制。","实现可抢占的任务调度、Ring 3 用户态与受控系统调用。","实现可持久化、可校验、可恢复的教学型文件系统。","通过 Shell、系统监视器、GUI、文件管理器和小游戏形成可展示的完整系统。","建立可重复执行的 QEMU 自动回归，保证各阶段修改不破坏关键路径。"]: bullet(doc,x)
h(doc,"1.3 项目边界",2)
para(doc,"OrangeOS 面向教学与机制验证，不以替代通用操作系统为目标。当前实现聚焦单机 x86、有限任务规模、简化用户程序格式和小容量文件系统；尚未实现完整 POSIX 接口、网络、多核、复杂权限模型、通用 ELF 装载和大型存储管理。")

h(doc,"2 功能总览",1)
add_table(doc,["能力域","已实现能力","主要入口"],[
    ("启动与内核","BIOS 启动、Loader、32 位保护模式、内核初始化","boot/、loader/、kernel/kernel32.asm"),
    ("中断与输入","IDT、PIC、PIT、键盘 IRQ、硬件光标、终端回看","idt32.asm、pic32.asm、timer32.asm、keyboard32.asm"),
    ("进程与调度","三个内核任务、抢占式轮转、PID 4 用户进程生命周期","process32.asm、timer32.asm"),
    ("内存","物理页位图、分页、动态页映射、Heap 分配与复用","memory32.asm、paging32.asm、heap32.asm"),
    ("用户态","Ring 3、TSS 内核栈、int 0x80、SYS_WRITE/SYS_EXIT、异常隔离","usermode32.asm、syscall32.asm"),
    ("存储","ATA PIO、OrangeFS v8、可变 extent、双目录、数据校验","ata32.asm、filesystem32.asm"),
    ("交互应用","Shell、Monitor、GUI、文件管理器、编辑器、Catch、Tetris","shell32.asm、monitor32.asm、ui32.asm、tetris32.asm"),
    ("工程质量","16 项发布回归、故障注入、快照测试、发布检查清单","Makefile、docs/RELEASE_CHECKLIST.md"),
],[1.15,3.05,2.3])

h(doc,"3 总体架构",1)
h(doc,"3.1 启动与运行链路",2)
code(doc,"BIOS\n  ↓\nBoot Sector (boot/boot.asm)\n  ↓\nLoader (loader/loader.asm)\n  ├─ 播放 VGA 启动帧\n  ├─ 装载 40 KiB 内核\n  └─ 进入保护模式\n  ↓\n32-bit Kernel @ 0x10000\n  ├─ GDT / IDT / PIC / PIT\n  ├─ Paging / Memory / Heap\n  ├─ Scheduler / Ring 3 / Syscall\n  ├─ ATA / OrangeFS\n  └─ Shell / Monitor / GUI / Games")
h(doc,"3.2 分层说明",2)
add_table(doc,["层次","职责","关键约束"],[
    ("引导层","读取并装载 Loader 与 Kernel，切换 CPU 运行模式","依赖 BIOS 服务；空间受启动扇区与磁盘布局限制"),
    ("硬件抽象层","端口 I/O、PIC/PIT、键盘、ATA、VGA","直接操作 x86 设备寄存器和中断控制器"),
    ("内核机制层","描述符、中断、调度、分页、内存与异常处理","必须维护可恢复的上下文与特权边界"),
    ("系统服务层","系统调用、进程服务、文件系统、RTC、监控","对上层提供受控接口并校验参数"),
    ("交互应用层","Shell、桌面、文件管理器、编辑器和游戏","复用键盘、显示、定时器和存储服务"),
],[1.25,2.8,2.45])
h(doc,"3.3 镜像布局",2)
add_table(doc,["区域","位置","说明"],[
    ("Boot Sector","镜像起始扇区","BIOS 首次加载并执行"),
    ("Loader 与 Kernel","内核装载区最大 40 KiB","Kernel 链接地址为 0x10000"),
    ("OrangeFS 主目录","LBA 82","带魔数、版本号和目录校验"),
    ("OrangeFS 数据区","LBA 83–114","32 个数据扇区，由位图和 extent 管理"),
    ("OrangeFS 备份目录","LBA 115","用于目录冗余与启动恢复"),
    ("启动视频帧","LBA 128 起","40 帧、320×200、16 色、10 FPS"),
],[1.75,1.65,3.1])

h(doc,"4 启动、保护模式与中断系统",1)
h(doc,"4.1 Boot Sector 与 Loader",2)
para(doc,"Boot Sector 负责建立最初的执行环境并装载后续阶段。Loader 进一步读取内核和启动动画资源，在 BIOS 实模式下完成帧播放，随后恢复文本模式、准备保护模式所需数据结构并跳转到内核入口。")
h(doc,"4.2 GDT、IDT 与 TSS",2)
for x in ["GDT 描述 32 位内核代码段、数据段，以及用户态代码/数据段。","IDT 将 CPU 异常和硬件中断向量映射到统一入口。","TSS 主要提供 Ring 3 进入 Ring 0 时使用的内核栈，保证系统调用和异常在可信栈上处理。"]: bullet(doc,x)
h(doc,"4.3 PIC、PIT 与键盘",2)
para(doc,"PIC 用于中断控制与重映射；PIT 周期性产生时钟中断，为系统 tick、抢占式调度、实时监视器和游戏刷新提供时间基准；键盘 IRQ1 负责扫描码处理、Shell 输入、历史浏览、补全和全屏应用控制。")

h(doc,"5 进程与调度",1)
h(doc,"5.1 任务模型",2)
para(doc,"内核维护任务上下文、PID、状态和累计运行 tick。基础系统运行三个任务，并通过 PIT 时钟中断进行抢占式轮转。独立用户进程使用 PID 4，支持 READY、EXITED、FAULTED 等可观察状态。")
h(doc,"5.2 用户进程生命周期",2)
for x in ["run：动态分配用户代码、数据和栈三页，建立映射并将 PID 4 置为 READY。","ps：显示状态、累计 ticks、退出码或页故障信息。","SYS_EXIT：记录退出结果、标记 EXITED，并解除映射、归还物理页。","kill 4：主动终止用户进程并释放资源。","runfault：制造用户态页故障，验证异常隔离和资源回收。"]: bullet(doc,x)
h(doc,"5.3 调度可观测性",2)
para(doc,"monitor 以约 0.1 秒周期刷新，显示当前 PID、调度切换、内存页统计，以及各任务的累计 ticks 和近似 CPU 占比。status 则提供适合日志记录的单行快照。")

h(doc,"6 内存管理与分页",1)
h(doc,"6.1 物理页管理",2)
para(doc,"系统使用位图跟踪受管物理页。alloc 分配一页，dealloc 释放并允许后续复用；memmap 将已用页与总页数转换为 20 格占用条，便于现场观察状态变化。")
h(doc,"6.2 分页与用户映射",2)
para(doc,"分页负责建立虚拟地址到物理页的映射，并通过页表权限区分内核页和用户页。用户代码、数据和栈仅在进程运行期间映射，正常退出、kill 或页故障后均解除映射。资源回归测试验证占用页数呈 N → N+3 → N。")
h(doc,"6.3 Heap",2)
para(doc,"Heap 提供小块动态分配与释放。演示中可通过 malloc、free、malloc 观察释放块被复用，说明内核不仅支持整页管理，也具备基础堆内存复用能力。")

h(doc,"7 Ring 3 与系统调用",1)
h(doc,"7.1 特权级切换",2)
para(doc,"内核建立用户态段、用户代码/数据/栈页和 TSS 内核栈后进入 CPL3。用户代码无法直接访问仅限内核的页面或设备，只能通过 int 0x80 请求受控服务。")
h(doc,"7.2 系统调用 ABI",2)
add_table(doc,["调用","作用","关键校验"],[
    ("获取 ticks/空闲页/PID","向用户态返回基本系统状态","校验调用来源与调用号"),
    ("SYS_EXIT","结束用户进程并返回退出码","回收用户页并恢复其他任务"),
    ("SYS_WRITE (EAX=5)","以 ESI=用户地址、ECX=长度输出文本","地址必须位于当前用户映射；长度受限；先复制到 127 字节内核缓冲区"),
],[1.7,2.15,2.65])
h(doc,"7.3 异常隔离",2)
para(doc,"用户进程访问未映射地址 0x50000000 时，页故障处理器记录 CR2 和错误码，只把 PID 4 标记为 FAULTED，Shell 与内核继续运行。Ring 0 页故障则触发保护性停机，因为内核自身状态已不再可信。")

h(doc,"8 OrangeFS v8 文件系统",1)
h(doc,"8.1 设计目标",2)
para(doc,"OrangeFS 用于教学环境中的磁盘持久化、文件 CRUD、跨扇区读取、可执行文件加载和故障恢复。它使用 ATA PIO 直接读写镜像，不依赖宿主文件系统。")
h(doc,"8.2 核心结构",2)
for x in ["目录项保存文件名、长度、起始扇区、占用扇区数和数据校验。","32 位数据扇区位图跟踪 LBA 83–114 的使用状态。","可变 extent 按实际内容分配 0、1 或 2 个连续扇区，单文件最大 1023 字节。","主备目录分别位于 LBA 82 和 115，均带版本号与目录校验。","文件内容使用 16 位加法校验，cat 和 exec 在使用数据前验证完整性。"]: bullet(doc,x)
h(doc,"8.3 恢复策略",2)
para(doc,"目录更新时版本号递增，并按‘备份优先、主目录随后’的顺序写入。启动时分别验证两份目录的魔数、校验和与版本，选择有效且更新的副本，再同步修复另一份。该设计提高了目录损坏后的恢复能力，但不等同于通用文件系统的事务日志。")
h(doc,"8.4 OEX2 用户程序",2)
code(doc,"OEX2:EE:LL:CC:<hex machine code>")
para(doc,"OEX2 包含入口偏移、代码长度、8 位校验和及机器码。exec demo.oex 会从 OrangeFS 读取、校验、解码并加载到动态用户代码页；示例程序通过 SYS_WRITE 输出 Hello from Ring3 OEX!，随后以退出码 42 结束。")

h(doc,"9 Shell、终端与交互应用",1)
h(doc,"9.1 Shell 与终端",2)
for x in ["命令解析、参数处理、命令历史与唯一前缀 Tab 补全。","128 字符命令缓冲区、80 列自动换行和 VGA 硬件光标。","PageUp 回看最近 16 条卷走的屏幕行，PageDown 返回实时终端。","help、info、date、task、mem、memmap、monitor、ls、cat、stat、exec 等系统命令。"]: bullet(doc,x)
h(doc,"9.2 GUI 与文件管理器",2)
para(doc,"gui 打开 VGA 彩色桌面，通过上下方向键选择 SYSTEM、FILES、APPS，并用 Enter 打开。FILES 提供文件列表、内置文本编辑器、新建、保存和删除确认；保存结果可由 Shell cat 读取，并在非快照模式下跨重启保留。")
h(doc,"9.3 游戏",2)
add_table(doc,["应用","玩法","系统能力验证"],[
    ("ORANGE CATCH","左右移动角色接住下落物","PIT 驱动刷新、IRQ1 实时输入、全屏状态切换"),
    ("ORANGE TETRIS","七类方块、旋转、软降、硬降、消行计分","定时器、键盘、棋盘状态、碰撞与返回 Shell"),
],[1.45,2.35,2.7])

h(doc,"10 项目结构与源码导航",1)
add_table(doc,["路径","主要内容","建议阅读顺序"],[
    ("boot/boot.asm","启动扇区与第一阶段装载","1"),("loader/loader.asm","内核装载、启动视频、保护模式切换","2"),("kernel/kernel32.asm","32 位内核初始化与主入口","3"),("kernel/gdt32.asm / idt32.asm","描述符表与中断框架","4"),("kernel/pic32.asm / timer32.asm / keyboard32.asm","硬件中断、时钟与输入","5"),("kernel/memory32.asm / paging32.asm / heap32.asm","物理页、虚拟映射和堆","6"),("kernel/process32.asm / usermode32.asm / syscall32.asm","调度、Ring 3 和系统调用","7"),("kernel/ata32.asm / filesystem32.asm","磁盘 I/O 与 OrangeFS","8"),("kernel/shell32.asm / monitor32.asm / ui32.asm / tetris32.asm","交互层与应用","9"),("include/*.inc","跨模块接口和常量声明","配合对应实现"),("Makefile","构建、镜像布局和 16 项回归","最后核对"),
],[2.35,3.25,.9])

h(doc,"11 构建、运行与测试",1)
h(doc,"11.1 环境依赖",2)
for x in ["WSL 或兼容的 Linux 构建环境。","NASM、GNU ld、make、coreutils。","qemu-system-i386。","启动视频资源 assets/boot-video.bin 已存在；如需替换，可使用 tools/video_to_vga.py 转换。"]: bullet(doc,x)
h(doc,"11.2 常用命令",2)
code(doc,"make clean\nmake\nmake test\nmake run")
para(doc,"make test 使用 QEMU 快照和 debugcon 验证内核与 Shell 启动，不写回磁盘镜像。make run 则正常运行镜像，可用于持久化文件测试。")
h(doc,"11.3 发布回归",2)
code(doc,"make test-release")
para(doc,"发布门禁按顺序执行 16 项 QEMU 自动测试，最终必须出现 OrangeOS release regression PASSED (16/16)。")
add_table(doc,["测试类别","覆盖重点"],[
    ("启动与终端","Boot smoke、Tab 补全、硬件光标、长命令换行、回看"),
    ("GUI 与应用","桌面、文件查看/编辑/CRUD、Catch、Tetris"),
    ("用户态","Ring 3 切换、进程生命周期、异常隔离、资源回收、OEX2"),
    ("文件系统","跨扇区文件、位图分配、双目录恢复、文件数据校验"),
],[1.65,4.85])
h(doc,"11.4 人工验收",2)
code(doc,"selftest\nstatus\nmemmap\nuser\nexec demo.oex\nps\nls\nstat big.txt\ngui")
para(doc,"故障演示可选用 runfault → ps → selftest。持久化演示必须使用非快照模式，并避免在演示前执行 make clean。fault 和 shutdown 会终止当前环境，只能放在最后。")

h(doc,"12 设计亮点、限制与演进",1)
h(doc,"12.1 设计亮点",2)
for x in ["从引导到应用的完整闭环，而不是依赖宿主系统的单独程序。","Ring 3、系统调用参数校验和用户态页故障隔离形成最小安全边界。","用户进程代码、数据、栈动态分配，并能在多种退出路径中回收。","OrangeFS 从固定布局演进到位图、可变 extent、双目录与数据校验。","自动回归包含真实 QEMU 交互、状态检查和磁盘故障注入。"]: bullet(doc,x)
h(doc,"12.2 当前限制",2)
for x in ["调度策略和任务规模较小，尚未形成完整 POSIX 进程模型。","地址空间与权限模型仍较简化，缺少每进程独立页表的完整实现。","OEX2 是教学型格式，不支持 ELF 段、重定位和动态链接。","OrangeFS 容量、目录槽和单文件大小有限，且不具备事务日志。","主要使用汇编实现，便于学习硬件细节，但维护和扩展成本较高。","尚未实现网络、多核、鼠标和通用驱动框架。"]: bullet(doc,x)
h(doc,"12.3 演进路线",2)
for x in ["引入每进程独立页表，完善用户地址空间隔离。","实现 ELF32 装载与更稳定的用户态 ABI。","扩展系统调用、文件描述符和用户态 Shell。","将策略层逐步迁移到 C，保留启动、中断入口和上下文切换汇编。","扩大 OrangeFS 容量，引入目录层级、日志或写时恢复机制。","在稳定单核基础上探索网络和多核支持。"]: num(doc,x)

h(doc,"附录 A 关键命令速查",1)
add_table(doc,["类别","命令","用途"],[
    ("系统","help / info / date / status / selftest","帮助、版本与状态、自检"),
    ("任务","task / monitor / run / ps / kill 4 / runfault","调度、用户进程与异常隔离"),
    ("内存","mem / memmap / alloc / dealloc / malloc / free","页面与堆分配观察"),
    ("用户态","user / syscall / exec demo.oex","Ring 3 与系统调用、磁盘程序执行"),
    ("文件","ls / stat / cat / touch / write / rm / disk","OrangeFS 查询与 CRUD"),
    ("界面","gui / game / tetris","桌面、Catch 与 Tetris"),
    ("终止","fault / reboot / shutdown","页故障停机、重启与关机；应最后执行"),
],[1.05,2.75,2.7])

h(doc,"附录 B 相关项目文档",1)
for x in ["README.md：项目总体说明、功能演进与命令入口。","docs/DEMO.md：完整演示流程与观察点。","docs/RELEASE_CHECKLIST.md：发布门禁与人工验收。","docs/CODE_READING.md：分模块源码阅读路线。","docs/Day2.md–Day38.md：按开发阶段记录的实现过程。","docs/OrangeOS答辩演示与问答手册.docx：现场演示话术与答辩问答。"]: bullet(doc,x)

doc.core_properties.title="OrangeOS v1.0 项目说明书"
doc.core_properties.subject="架构、模块、构建、测试与阅读导航"
doc.core_properties.author="OrangeOS 项目组"
doc.settings.element.append(OxmlElement("w:updateFields")); doc.settings.element[-1].set(qn("w:val"),"true")
doc.save(OUT); print(OUT)
