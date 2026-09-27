from pathlib import Path
from zipfile import ZipFile, ZIP_DEFLATED
from tempfile import TemporaryDirectory
from lxml import etree
import shutil

SRC = Path(r"D:\Oranges\docs\OrangeOS项目说明书（含阅读导航）.docx")
OUT = Path(r"D:\Oranges\docs\OrangeOS项目说明书（封面后目录）.docx")
W = "http://schemas.openxmlformats.org/wordprocessingml/2006/main"
NS = {"w": W}
qn = lambda n: f"{{{W}}}{n}"


def has_bookmark(el, name):
    return any(x.get(qn("name")) == name for x in el.xpath(".//w:bookmarkStart", namespaces=NS))


def has_page_break(el):
    return bool(el.xpath(".//w:br[@w:type='page']", namespaces=NS))


def page_break_para():
    p = etree.Element(qn("p"))
    r = etree.SubElement(p, qn("r"))
    br = etree.SubElement(r, qn("br"))
    br.set(qn("type"), "page")
    return p


def replace_link_text(root, anchor, old_text, new_text):
    for link in root.xpath(f".//w:hyperlink[@w:anchor='{anchor}']", namespaces=NS):
        text = "".join(link.xpath(".//w:t/text()", namespaces=NS))
        if text == old_text:
            nodes = link.xpath(".//w:t", namespaces=NS)
            if nodes:
                nodes[0].text = new_text
                for node in nodes[1:]:
                    node.text = ""


with TemporaryDirectory(prefix="orange_toc_move_") as td:
    root_dir = Path(td)
    with ZipFile(SRC) as z:
        z.extractall(root_dir)

    doc_path = root_dir / "word" / "document.xml"
    tree = etree.parse(str(doc_path))
    body = tree.getroot().find("w:body", namespaces=NS)
    children = list(body)

    top_index = next(i for i, el in enumerate(children) if has_bookmark(el, "Top"))
    toc_block = children[:top_index]
    if not toc_block or not any(has_bookmark(el, "TOC") for el in toc_block):
        raise RuntimeError("Could not identify the existing TOC block")

    for el in toc_block:
        if has_bookmark(el, "TOC"):
            texts = el.xpath(".//w:t", namespaces=NS)
            if texts:
                texts[0].text = "目录"

    root = tree.getroot()
    replace_link_text(root, "Top", "Top", "页首")
    replace_link_text(root, "Bottom", "Bottom", "页尾")
    replace_link_text(root, "TOC", "TOC", "目录")
    replace_link_text(root, "TOC", "Back to TOC", "返回目录")

    for el in toc_block:
        body.remove(el)

    remaining = list(body)
    cover_break_index = next(i for i, el in enumerate(remaining) if has_page_break(el))
    insert_at = cover_break_index + 1
    for el in toc_block:
        body.insert(insert_at, el)
        insert_at += 1
    body.insert(insert_at, page_break_para())

    tree.write(str(doc_path), encoding="UTF-8", xml_declaration=True, standalone="yes")
    if OUT.exists():
        OUT.unlink()
    with ZipFile(OUT, "w", ZIP_DEFLATED) as z:
        for p in root_dir.rglob("*"):
            if p.is_file():
                z.write(p, p.relative_to(root_dir).as_posix())

print(OUT)
